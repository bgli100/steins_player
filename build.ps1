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

    # Directory the finished artifacts are packaged into, named
    # `Lullaby Core <version>.<ext>`. Defaults to `dist` next to this script,
    # which is git-ignored.
    [string]$Dist = (Join-Path $PSScriptRoot 'dist'),

    # Keep build\, .dart_tool\ and the OHOS build directories. They are removed
    # once the artifacts have been packaged, because one three-platform build
    # leaves ~65 GB of intermediate copies behind.
    [switch]$KeepBuild,

    # Package the artifacts that are already in the build directories and clean
    # up, without running any build.
    [switch]$PackageOnly,

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

function Invoke-Flutter([string[]]$arguments) {
    Write-Host "> flutter $($arguments -join ' ')" -ForegroundColor DarkYellow
    & $Flutter @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-OhosBundleName {
    $appConfig = Join-Path $root 'ohos\AppScope\app.json5'
    if (-not (Test-Path $appConfig)) { return $null }
    $match = [regex]::Match((Get-Content -Raw $appConfig), '"bundleName"\s*:\s*"([^"]+)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-AppVersion {
    $pubspec = Join-Path $root 'pubspec.yaml'
    if (Test-Path $pubspec) {
        $match = [regex]::Match((Get-Content -Raw $pubspec), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
        if ($match.Success) { return $match.Groups[1].Value }
    }
    return '0.0.0'
}

# The release naming scheme used in the distribution folder.
function Get-PackageName([string]$version, [string]$extension, [string]$suffix) {
    return "Lullaby Core $version$suffix.$extension"
}

# Copies an artifact into $Dist under the release naming scheme and records it
# in the build summary.
function Publish-Artifact {
    param([string]$Platform, [string]$Source, [string]$Name)
    if (-not (Test-Path $Source)) {
        Write-Warning "nothing to package for ${Platform}: $Source is missing"
        return $null
    }
    New-Item -ItemType Directory -Force -Path $Dist | Out-Null
    $target = Join-Path $Dist $Name
    Copy-Item -Force $Source $target
    $size = '{0:N1} MB' -f ((Get-Item $target).Length / 1MB)
    $results[$Platform] = "OK    $target  ($size)"
    return $target
}

# The newest HarmonyOS HAP a build left behind, preferring a signed one.
function Find-OhosHap {
    $candidates = @(
        "build\ohos\hap\lullaby_core-$OhosMode-signed.hap",
        'ohos\entry\build\default\outputs\default\entry-default-signed.hap',
        'build\ohos\hap\entry-default-signed.hap',
        'build\ohos\hap\entry-default-hokit-signed.hap',
        'ohos\entry\build\default\outputs\default\entry-default-unsigned.hap'
    ) | Where-Object { Test-Path $_ } | ForEach-Object { Get-Item $_ }
    if (-not $candidates) { return $null }
    return ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

# Removes everything a build leaves behind; the packaged artifacts in $Dist and
# the sources survive.
function Remove-BuildOutputs {
    $targets = @(
        'build',
        # Only the build cache: .dart_tool\package_config.json is what the Dart
        # analyzer resolves `package:` imports with and must survive, otherwise
        # the IDE floods with unresolved-import errors after every build.
        '.dart_tool\flutter_build',
        'ohos\entry\build',
        'ohos\entry\src\main\resources\rawfile\flutter_assets',
        'ohos\.hvigor',
        'windows\flutter\ephemeral',
        'android\.gradle'
    )
    $removed = @()
    foreach ($target in $targets) {
        $path = Join-Path $root $target
        if (-not (Test-Path $path)) { continue }
        # Windows keeps handles on freshly written directories (file watchers,
        # antivirus), so retry a few times before giving up.
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            Remove-Item -Recurse -Force -Path $path -ErrorAction SilentlyContinue
            if (-not (Test-Path $path)) { break }
            Start-Sleep -Seconds 2
        }
        if (Test-Path $path) {
            Write-Warning "could not remove $target (locked by another process; close the IDE and delete it by hand)"
        }
        else {
            $removed += $target
        }
    }
    return $removed
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
        $bundleName = Get-OhosBundleName
        if ((Test-Path $profileDir) -and $bundleName) {
            # HoKit names the profile after the bundle: <bundle>_<account>_<hash>.p7b.
            $script:ProfileFile = (Get-ChildItem $profileDir -Filter "$bundleName*.p7b" |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
            if (-not $ProfileFile) {
                Write-Warning "No provisioning profile for $bundleName in $profileDir; generate one (DevEco/HoKit) or pass -ProfileFile."
            }
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
    $version = Get-AppVersion
    if ($PackageOnly) {
        Write-Host 'Packaging the existing artifacts only (no build).'
    }
    else {
        Write-Host "Platforms: $($Platforms -join ', ')"
    }
    Write-Host "Version $version -> $Dist"

    if (-not $PackageOnly -and -not $SkipIcons) {
        Write-Header 'Launcher icons'
        & dart run flutter_launcher_icons
        if ($LASTEXITCODE -ne 0) { throw "flutter_launcher_icons failed with exit code $LASTEXITCODE" }
    }

    $hapSuffix = if ($OhosMode -eq 'release') { '-ohos' } else { "-ohos-$OhosMode" }
    $hapName = Get-PackageName $version 'hap' $hapSuffix
    $ohosHap = $null

    if (-not $PackageOnly -and ($Platforms -contains 'windows')) {
        Write-Header 'Windows release'
        Invoke-Flutter @('build', 'windows', '--release')
        $exe = 'build\windows\x64\runner\Release\lullaby_core.exe'
        if (-not (Test-Path $exe)) {
            # Older CMake setups still produce the previous binary name.
            $legacy = 'build\windows\x64\runner\Release\steins_player.exe'
            if (Test-Path $legacy) { Move-Item -Force $legacy $exe }
        }
        if (-not (Test-Path $exe)) { throw "Windows build did not produce $exe" }
    }

    if (-not $PackageOnly -and ($Platforms -contains 'android')) {
        Write-Header 'Android release'
        Invoke-Flutter @('build', 'apk', '--release')
    }

    if (-not $PackageOnly -and ($Platforms -contains 'ohos')) {
        Write-Header "HarmonyOS $OhosMode"
        Invoke-Flutter @('build', 'hap', "--$OhosMode")

        $unsignedHap = 'ohos\entry\build\default\outputs\default\entry-default-unsigned.hap'
        if (-not (Test-Path $unsignedHap)) { throw "Unsigned HAP not found: $unsignedHap" }

        if (Resolve-OhosSignMaterial) {
            Write-Header 'Signing HarmonyOS HAP'
            New-Item -ItemType Directory -Force -Path $Dist | Out-Null
            $ohosHap = Join-Path $Dist $hapName
            & java -jar $HapSignTool sign-app `
                -keyAlias $KeyAlias -keyPwd $KeyPwd -keystorePwd $KeystorePwd `
                -signCode 1 -signAlg SHA256withECDSA -mode localSign `
                -appCertFile $AppCertFile -profileFile $ProfileFile -keystoreFile $Keystore `
                -inFile $unsignedHap -outFile $ohosHap
            if ($LASTEXITCODE -ne 0) { throw "hap-sign-tool failed with exit code $LASTEXITCODE" }

            if ($Install) {
                $hdc = Resolve-Hdc
                if (-not $hdc) {
                    Write-Warning 'hdc not found, skipping installation.'
                }
                else {
                    Write-Header 'Installing HarmonyOS HAP'
                    $target = @()
                    if ($Device) { $target = @('-t', $Device) }
                    & $hdc @target install -r $ohosHap
                    if ($LASTEXITCODE -ne 0) { throw "hdc install failed with exit code $LASTEXITCODE" }
                    $where = if ($Device) { "device $Device" } else { 'the connected device' }
                    $results['ohos-install'] = "OK    installed on $where"
                }
            }
        }
        else {
            Write-Warning "HAP not signed with the local material; hvigor's signed copy is packaged instead."
        }
    }

    Write-Header 'Packaging'
    $packaged = if ($PackageOnly) { @('windows', 'android', 'ohos') } else { $Platforms }
    foreach ($platform in $packaged) {
        switch ($platform) {
            'windows' {
                $release = 'build\windows\x64\runner\Release'
                if (-not (Test-Path (Join-Path $release 'lullaby_core.exe'))) {
                    Write-Warning 'nothing to package for windows: build\windows\x64\runner\Release is missing'
                    break
                }
                New-Item -ItemType Directory -Force -Path $Dist | Out-Null
                $zip = Join-Path $Dist (Get-PackageName $version 'zip' '-windows')
                if (Test-Path $zip) { Remove-Item -Force $zip }
                # The exe needs the shipped libraries and the data directory.
                Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip -CompressionLevel Optimal
                $size = '{0:N1} MB' -f ((Get-Item $zip).Length / 1MB)
                $results['windows'] = "OK    $zip  ($size)"
            }
            'android' {
                Publish-Artifact -Platform 'android' `
                    -Source 'build\app\outputs\flutter-apk\app-release.apk' `
                    -Name (Get-PackageName $version 'apk' '-android') | Out-Null
            }
            'ohos' {
                if ($ohosHap) {
                    $size = '{0:N1} MB' -f ((Get-Item $ohosHap).Length / 1MB)
                    $results['ohos'] = "OK    $ohosHap  ($size)"
                    break
                }
                $source = Find-OhosHap
                if (-not $source) {
                    Write-Warning 'nothing to package for ohos: no HAP found'
                    break
                }
                Write-Warning "packaging $source"
                Publish-Artifact -Platform 'ohos' -Source $source -Name $hapName | Out-Null
            }
        }
    }

    Write-Header 'Build summary'
    foreach ($entry in $results.GetEnumerator()) {
        $color = if ($entry.Value -like 'OK*') { 'Green' } else { 'Yellow' }
        Write-Host ("{0,-13} {1}" -f $entry.Key, $entry.Value) -ForegroundColor $color
    }

    foreach ($platform in $packaged) {
        if ($results.Keys -contains $platform) { continue }
        if ($PackageOnly) {
            Write-Warning "no artifact packaged for $platform"
        }
        else {
            $failures += $platform
        }
    }

    if ($failures.Count -gt 0) {
        throw "Build finished with missing artifacts: $($failures -join ', ')"
    }

    if (-not $KeepBuild) {
        Write-Header 'Cleaning build directories'
        $removed = Remove-BuildOutputs
        if ($removed.Count -gt 0) {
            Write-Host ("removed: " + ($removed -join ', ')) -ForegroundColor DarkGray
        }
        else {
            Write-Host 'nothing to remove.' -ForegroundColor DarkGray
        }
        Write-Host 'the packaged artifacts in the distribution directory are kept (-KeepBuild keeps the rest).' -ForegroundColor DarkGray
    }
}
finally {
    Pop-Location
}
