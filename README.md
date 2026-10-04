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
.\build.ps1 -PackageOnly                             # package what is already built, no build
.\build.ps1 -ShowConfig                              # print the effective settings only
```

Finished artifacts are packaged into `dist\` next to the script (git-ignored,
`-Dist <dir>` to change it) and named after the release:

| Platform  | Package | Build directory (intermediate) |
| --------- | ------- | ------------------------------ |
| Windows   | `dist\Lullaby Core <version>-windows.zip` | `build\windows\x64\runner\Release\` |
| Android   | `dist\Lullaby Core <version>.apk` | `build\app\outputs\flutter-apk\app-release.apk` |
| HarmonyOS | `dist\Lullaby Core <version>.hap` | `ohos\entry\build\default\outputs\default\` |

`<version>` comes from `pubspec.yaml`. The Windows package holds the whole
`Release` directory (exe, libraries, `data\`).

One three-platform run leaves ~65 GB of intermediate copies behind, because the
2.7 GB asset set is copied into every build stage (`build\flutter_assets`,
Android's asset merges, the OHOS `rawfile` staging, every packaged APK/HAP).
The script therefore deletes `build\`, `.dart_tool\`, `ohos\entry\build` and the
staged OHOS assets right after packaging; the packages in `dist\` are kept. Pass
`-KeepBuild` to keep them for incremental builds (and mind the disk usage).

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
| `ohos.profileFile` | provisioning profile (`.p7b`); auto-detected for the bundle name in `ohos/AppScope/app.json5` when empty |
| `ohos.keystorePwd` / `ohos.keyPwd` | signing passwords |

Every value can also be passed as a parameter (`-Flutter`, `-Hdc`, `-Device`,
`-HapSignTool`, `-Keystore`, `-KeyAlias`, `-AppCertFile`, `-ProfileFile`,
`-KeystorePwd`, `-KeyPwd`); the passwords additionally fall back to
`$env:HOKIT_KEYSTORE_PWD` / `$env:HOKIT_KEY_PWD` for CI. Without signing
material the HAP keeps the signature hvigor applied (its unsigned output is
packaged as a last resort).

The HarmonyOS bundle name is `com.lullaby.steins_player.ohos`. Provisioning
profiles are issued per bundle name, so generate a new one (DevEco Studio or
HoKit) after renaming the bundle, otherwise `-Install` is skipped.

## Update feed

On start the app fetches `version.json` (see `Update.feedUrl`) and, when it
describes a newer release, shows the notes with one button per download link:

```json
{
  "version": "1.1.0",
  "announcement": "release notes",
  "download_url": "https://example.net/primary",
  "download_name": "百度网盘",
  "download_url2": "https://example.net/mirror",
  "download_name2": "夸克网盘"
}
```

`download_url2` / `download_name2` are optional: every link the feed provides
gets its own button (`去下载` and `备用下载` are the labels used when the feed
does not name them), and links left empty are skipped.
