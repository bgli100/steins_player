# Steins Player
Bilibili interactive video player on Windows, HarmonyOS, Android and iOS by flutter

Currently made for Lullaby Core project, can be adopted to other interactive videos.

You need to find your own way to download these videos, they are not offered here.

## Building

`build.ps1` builds every platform it can from Windows in a single run:

```powershell
.\build.ps1                                          # Windows + Android + HarmonyOS
.\build.ps1 -Platforms windows,ohos                  # subset
.\build.ps1 -Install                                 # also install the HAP on a connected device
.\build.ps1 -PackageOnly                             # package what is already built, no build
.\build.ps1 -ShowConfig                              # print the effective settings only
```

iOS is not part of it: building for iOS needs Xcode, which only runs on macOS.
`.github/workflows/ios.yml` builds the iOS app without code signing on a macOS
runner and runs the boot smoke test on a simulator (see [iOS](#ios)).

Finished artifacts are packaged into `dist\` next to the script (git-ignored,
`-Dist <dir>` to change it) and named after the release:

| Platform  | Package | Build directory (intermediate) |
| --------- | ------- | ------------------------------ |
| Windows   | `dist\Lullaby Core <version>-windows.zip` | `build\windows\x64\runner\Release\` |
| Android   | `dist\Lullaby Core <version>-android.apk` | `build\app\outputs\flutter-apk\app-release.apk` |
| HarmonyOS | `dist\Lullaby Core <version>-ohos.hap` | `ohos\entry\build\default\outputs\default\` |
| iOS       | `Runner.app` (CI artifact, unsigned) | `build\ios\iphoneos\Runner.app\` |

`<version>` comes from `pubspec.yaml`. The Windows package holds the whole
`Release` directory (exe, libraries, `data\`); a non-release HarmonyOS build
carries its mode too (`Lullaby Core <version>-ohos-debug.hap`).

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

## iOS

The iOS Xcode project is `ios/Runner.xcworkspace` (bundle identifier
`com.lullaby.steinsplayer`, landscape only, launch screen and icons from
`res/icon_ios.png` - an opaque 1024x1024 icon, because the transparent
`res/icon.png` cannot be used for iOS).

`packages/file_picker_ohos` is a trimmed copy of the OHOS fork of `file_picker`
(no `example/`, `test/` or generated `oh_modules/`) with the iOS and macOS
podspecs renamed from `file_picker.podspec` to `file_picker_ohos.podspec`,
because CocoaPods looks for `<package name>.podspec` and the fork renamed the
package but not its podspecs - without this every CocoaPods build (iOS and
macOS) stops with `No podspec found for file_picker_ohos`. Keep the copy in
sync when updating the fork.

```bash
flutter build ios --release --no-codesign   # on macOS only
flutter test integration_test/app_boot_test.dart -d <simulator-udid>
```

`app_boot_test.dart` is the runtime check for iOS-specific breakage: it waits
for the splash screen to hand over to the home page, which only happens once
the bundled introduction clip has played through libmpv and reported its
completion - i.e. `MediaKit.ensureInitialized()`, the texture video output and
playback all work.

`.github/workflows/ios.yml` runs both on every push (and manually via
*workflow_dispatch*): a `macos-15` job builds with `--no-codesign`, a second
one boots an iPhone simulator and runs the smoke test. Installing on a real
device or shipping through TestFlight additionally needs an Apple Developer
account and its certificates, which the workflow deliberately does not touch.

Video decoding is hardware accelerated on iOS (`Device.isEmulator` is Android
only), and the media_kit fork keeps the iOS implementation, so `media_kit`'s
libmpv `xcframework` is fetched by CocoaPods during the first build.

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
