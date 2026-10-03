# Steins Player
Bilibili interactive video player on Windows, HarmonyOS and Android by flutter

Currently made for Lullaby Core project, can be adopted to other interactive videos.

You need to find your own way to download these videos, they are not offered here.

## Building

`build.ps1` builds every platform in a single run:

```powershell
.\build.ps1                                          # Windows + Android + HarmonyOS
.\build.ps1 -Platforms windows,ohos                  # subset
.\build.ps1 -Install                                 # also install the HAP on a connected device
.\build.ps1 -ShowConfig                              # print the effective settings only
```

Artifacts:

| Platform  | Output |
| --------- | ------ |
| Windows   | `build\windows\x64\runner\Release\lullaby_core.exe` |
| Android   | `build\app\outputs\flutter-apk\app-release.apk` |
| HarmonyOS | `build\ohos\hap\lullaby_core-debug-signed.hap` |

Machine specific settings live in `build.local.json` next to the script, which
is git-ignored: copy `build.local.example.json` to create it.

| Key | Meaning |
| --- | ------- |
| `flutter` | `flutter` executable to use (default `flutter` from `PATH`) |
| `hdc` | `hdc` executable used by `-Install` |
| `device` | HarmonyOS device key for `-Install` (default: the connected device) |
| `ohos.hapSignTool` | `hap-sign-tool.jar` |
| `ohos.keystore` | signing keystore (`.p12`) |
| `ohos.keyAlias` | key alias inside the keystore |
| `ohos.appCertFile` | app certificate (`.cer`); auto-detected from HoKit when empty |
| `ohos.profileFile` | provisioning profile (`.p7b`); auto-detected when empty |
| `ohos.keystorePwd` / `ohos.keyPwd` | signing passwords |

Every value can also be passed as a parameter (`-Flutter`, `-Hdc`, `-Device`,
`-HapSignTool`, `-Keystore`, `-KeyAlias`, `-AppCertFile`, `-ProfileFile`,
`-KeystorePwd`, `-KeyPwd`); the passwords additionally fall back to
`$env:HOKIT_KEYSTORE_PWD` / `$env:HOKIT_KEY_PWD` for CI. Without signing
material the unsigned HAP is left in
`ohos\entry\build\default\outputs\default\`.
