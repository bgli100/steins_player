<#
.SYNOPSIS
    Builds Lullaby Core for Windows, Android and HarmonyOS in a single run.

.DESCRIPTION
    One command produces every platform build:

      * Windows   -> build\windows\x64\runner\Release\lullaby_core.exe
      * Android   -> build\app\outputs\flutter-apk\app-release.apk
      * HarmonyOS -> build\ohos\hap\lullaby_core-<mode>-signed.hap

    The HarmonyOS HAP is signed with the local HoKit debug material as part of
    the build, so it is ready to install on a development device.

    Machine specific values (tool paths, the device key and the signing
    passwords) live in `build.local.json` next to this script, which is
    git-ignored: copy `build.local.example.json` to create it. Every value can
    also be passed as a parameter, and the passwords additionally fall back to
    $env:HOKIT_KEYSTORE_PWD / $env:HOKIT_KEY_PWD.

.EXAMPLE
    .\build.ps1
    Builds all three platforms.

.EXAMPLE
    .\build.ps1 -Platforms windows,ohos -SkipIcons
    Builds only Windows and the HarmonyOS HAP.

.EXAMPLE
    .\build.ps1 -ShowConfig
    Prints where every setting comes from, without building anything.
#>
[CmdletBinding()]
param(
    # Platforms to build.
    [ValidateSet('windows', 'android', 'ohos')]
    [string[]]$Platforms = @('windows', 'android', 'ohos'),

    # Build mode for the HarmonyOS HAP. Use 'debug' when you want the Dart VM
    # service (log output, widget/render tree dumps) on the device.
    [ValidateSet('debug', 'profile', 'release')]
    [string]$OhosMode = 'release',

    # Skip the launcher icon generation step.
    [switch]$SkipIcons,

    # Install the signed HAP on the connected HarmonyOS device via hdc.
    [switch]$Install,

    # File with machine specific settings (git-ignored).
    [string]$ConfigFile = (Join-Path $PSScriptRoot 'build.local.json'),

    # Print the resolved settings and exit without building.
    [switch]$ShowConfig,

    # flutter executable to use. Defaults to 'flutter' from PATH.
    [string]$Flutter,

    # hdc executable used by -Install. Defaults to 'hdc' from PATH.
    [string]$Hdc,

    # HarmonyOS device key for -Install. Defaults to the connected device.
    [string]$Device,

    # --- HoKit signing material (defaults come from the settings file) ---
    [string]$HapSignTool,
    [string]$Keystore,
    [string]$KeyAlias,
    [string]$AppCertFile,
    [string]$ProfileFile,
    [string]$KeystorePwd,
    [string]$KeyPwd
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

# --- machine specific settings -------------------------------------------
$local = @{}
if (Test-Path $ConfigFile) {
    $json = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
    foreach ($name in 'flutter', 'hdc', 'device') {
        if ($json.PSObject.Properties.Name -contains $name) { $local[$name] = $json.$name }
    }
    if ($json.PSObject.Properties.Name -contains 'ohos') {
        foreach ($name in 'hapSignTool', 'keystore', 'keyAlias', 'appCertFile', 'profileFile',
            'keystorePwd', 'keyPwd') {
            if ($json.ohos.PSObject.Properties.Name -contains $name) { $local[$name] = $json.ohos.$name }
        }
    }
}

# Parameter wins over the settings file, which wins over the environment.
function Use-Setting([string]$name, [string]$value, [string]$fallback) {
    if ($value) { return $value }
    if ($local[$name]) { return $local[$name] }
    return $fallback
}

$Flutter = Use-Setting 'flutter' $Flutter 'flutter'
$Hdc = Use-Setting 'hdc' $Hdc $null
$Device = Use-Setting 'device' $Device $null
$HapSignTool = Use-Setting 'hapSignTool' $HapSignTool $null
$Keystore = Use-Setting 'keystore' $Keystore $null
$KeyAlias = Use-Setting 'keyAlias' $KeyAlias 'hokit'
$AppCertFile = Use-Setting 'appCertFile' $AppCertFile $null
$ProfileFile = Use-Setting 'profileFile' $ProfileFile $null
$KeystorePwd = Use-Setting 'keystorePwd' $KeystorePwd $env:HOKIT_KEYSTORE_PWD
$KeyPwd = Use-Setting 'keyPwd' $KeyPwd $env:HOKIT_KEY_PWD
if ([string]::IsNullOrEmpty($KeyPwd)) { $KeyPwd = $KeystorePwd }

if ($ShowConfig) {
    $display = [ordered]@{
        'settings'      = if (Test-Path $ConfigFile) { $ConfigFile } else { "$ConfigFile (missing)" }
        'flutter'       = $Flutter
        'hdc'           = if ($Hdc) { $Hdc } else { 'hdc from PATH' }
        'device'        = if ($Device) { $Device } else { 'connected device' }
        'hap-sign-tool' = if ($HapSignTool) { $HapSignTool } else { '(unset)' }
        'keystore'      = if ($Keystore) { $Keystore } else { '(unset)' }
        'key alias'     = $KeyAlias
        'app cert'      = if ($AppCertFile) { $AppCertFile } else { '(auto-detected)' }
        'profile'       = if ($ProfileFile) { $ProfileFile } else { '(auto-detected)' }
        'keystore pwd'  = if ($KeystorePwd) { '(set)' } else { '(empty)' }
        'key pwd'       = if ($KeyPwd) { '(set)' } else { '(empty)' }
    }
    foreach ($setting in $display.GetEnumerator()) {
        Write-Host ("{0,-14} {1}" -f $setting.Key, $setting.Value)
    }
    return
}

$results = [ordered]@{}
$failures = @()

function Write-Header([string]$text) {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}

function Write-Result([string]$platform, [string]$path) {
    if (Test-Path $path) {
        $file = Get-Item $path
        $size = '{0:N1} MB' -f ($file.Length / 1MB)
        $results[$platform] = "OK    $($file.FullName)  ($size)"
    }
    else {
        $results[$platform] = "FAIL  missing artifact: $path"
        $script:failures += $platform
    }
}

function Invoke-Flutter([string[]]$arguments) {
    Write-Host "> flutter $($arguments -join ' ')" -ForegroundColor DarkYellow
    & $Flutter @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Resolve-OhosSignMaterial {
    if (-not $AppCertFile) {
        $certDir = Join-Path $env:LOCALAPPDATA 'ho-kit\sign\certs'
        if (Test-Path $certDir) {
            $script:AppCertFile = (Get-ChildItem $certDir -Filter '*.cer' |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        }
    }
    if (-not $ProfileFile) {
        $profileDir = Join-Path $env:LOCALAPPDATA 'ho-kit\sign\provisions'
        if (Test-Path $profileDir) {
            $script:ProfileFile = (Get-ChildItem $profileDir -Filter 'com.lullaby.steins_player*.p7b' |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        }
    }

    $missing = @()
    if (-not (Test-Path $HapSignTool)) { $missing += "hap-sign-tool: $HapSignTool" }
    if (-not (Test-Path $Keystore)) { $missing += "keystore: $Keystore" }
    if (-not $AppCertFile) { $missing += 'app certificate (.cer)' }
    if (-not $ProfileFile) { $missing += 'provisioning profile (.p7b)' }
    if ([string]::IsNullOrEmpty($KeystorePwd)) { $missing += 'password (-KeystorePwd or $env:HOKIT_KEYSTORE_PWD)' }

    if ($missing.Count -gt 0) {
        foreach ($item in $missing) { Write-Warning "Signing skipped, missing $item" }
        return $false
    }
    return $true
}

function Resolve-Hdc {
    if ($Hdc) {
        if (Test-Path $Hdc) { return $Hdc }
        Write-Warning "hdc not found at the configured path: $Hdc"
    }
    $command = Get-Command hdc -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

Push-Location $root
try {
    Write-Host "Building Lullaby Core ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "Platforms: $($Platforms -join ', ')"

    if (-not $SkipIcons) {
        Write-Header 'Launcher icons'
        & dart run flutter_launcher_icons
        if ($LASTEXITCODE -ne 0) { throw "flutter_launcher_icons failed with exit code $LASTEXITCODE" }
    }

    if ($Platforms -contains 'windows') {
        Write-Header 'Windows release'
        Invoke-Flutter @('build', 'windows', '--release')
        $exe = 'build\windows\x64\runner\Release\lullaby_core.exe'
        if (-not (Test-Path $exe)) {
            # Older CMake setups still produce the previous binary name.
            $legacy = 'build\windows\x64\runner\Release\steins_player.exe'
            if (Test-Path $legacy) { Move-Item -Force $legacy $exe }
        }
        Write-Result 'windows' $exe
    }

    if ($Platforms -contains 'android') {
        Write-Header 'Android release'
        Invoke-Flutter @('build', 'apk', '--release')
        Write-Result 'android' 'build\app\outputs\flutter-apk\app-release.apk'
    }

    if ($Platforms -contains 'ohos') {
        Write-Header "HarmonyOS $OhosMode"
        Invoke-Flutter @('build', 'hap', "--$OhosMode")

        $unsignedHap = 'ohos\entry\build\default\outputs\default\entry-default-unsigned.hap'
        $signedHap = "build\ohos\hap\lullaby_core-$OhosMode-signed.hap"
        if (-not (Test-Path $unsignedHap)) { throw "Unsigned HAP not found: $unsignedHap" }

        if (Resolve-OhosSignMaterial) {
            Write-Header 'Signing HarmonyOS HAP'
            New-Item -ItemType Directory -Force -Path (Split-Path $signedHap) | Out-Null
            & java -jar $HapSignTool sign-app `
                -keyAlias $KeyAlias -keyPwd $KeyPwd -keystorePwd $KeystorePwd `
                -signCode 1 -signAlg SHA256withECDSA -mode localSign `
                -appCertFile $AppCertFile -profileFile $ProfileFile -keystoreFile $Keystore `
                -inFile $unsignedHap -outFile $signedHap
            if ($LASTEXITCODE -ne 0) { throw "hap-sign-tool failed with exit code $LASTEXITCODE" }
            Write-Result 'ohos' $signedHap

            if ($Install) {
                $hdc = Resolve-Hdc
                if (-not $hdc) {
                    Write-Warning 'hdc not found, skipping installation.'
                }
                else {
                    Write-Header 'Installing HarmonyOS HAP'
                    $target = @()
                    if ($Device) { $target = @('-t', $Device) }
                    & $hdc @target install -r $signedHap
                    if ($LASTEXITCODE -ne 0) { throw "hdc install failed with exit code $LASTEXITCODE" }
                    $where = if ($Device) { "device $Device" } else { 'the connected device' }
                    $results['ohos-install'] = "OK    installed on $where"
                }
            }
        }
        else {
            $results['ohos'] = "UNSIGNED  $((Resolve-Path $unsignedHap).Path)"
        }
    }

    Write-Header 'Build summary'
    foreach ($entry in $results.GetEnumerator()) {
        $color = if ($entry.Value -like 'OK*') { 'Green' } else { 'Yellow' }
        Write-Host ("{0,-13} {1}" -f $entry.Key, $entry.Value) -ForegroundColor $color
    }

    if ($failures.Count -gt 0) {
        throw "Build finished with missing artifacts: $($failures -join ', ')"
    }
}
finally {
    Pop-Location
}
