# Steins Player
Bilibili interactive video player for Windows, HarmonyOS, Android and iOS, in Flutter.
Made for the Lullaby Core project, adaptable to other interactive videos; the videos
themselves are not included.

## Building

`build.ps1` builds every platform it can drive from Windows:

```powershell
.\build.ps1                     # Windows + Android + HarmonyOS
.\build.ps1 -Platforms windows,ohos
.\build.ps1 -Install            # also install the HAP on a connected device
.\build.ps1 -PackageOnly        # package what is already built
.\build.ps1 -ShowConfig         # print the effective settings
```

iOS needs Xcode and is built by CI instead - see [iOS](#ios).

Artifacts land in `dist\` (git-ignored, `-Dist <dir>` to change) named after the
version in `pubspec.yaml`:

| Platform  | Package | Build output |
| --------- | ------- | ------------ |
| Windows   | `Lullaby Core <version>-windows.zip` | `build\windows\x64\runner\Release\` |
| Android   | `Lullaby Core <version>-android.apk` | `build\app\outputs\flutter-apk\app-release.apk` |
| HarmonyOS | `Lullaby Core <version>-ohos.hap` | `ohos\entry\build\default\outputs\default\` |
| iOS       | `Runner.app` (CI, unsigned) | `build/ios/iphoneos/Runner.app` |

The Windows package is the whole `Release` directory; a non-release HAP carries
its mode (`-ohos-debug.hap`). One three-platform run stages ~65 GB of
intermediate copies of the 2.7 GB asset set, so the script deletes `build\`,
`.dart_tool\` and the OHOS staging after packaging - `-KeepBuild` keeps them.

Machine specific values (tool paths, signing) live in the git-ignored
`build.local.json`: copy `build.local.example.json` and fill it in. Every key is
also a parameter of the same name, and the passwords fall back to
`$env:HOKIT_KEYSTORE_PWD` / `$env:HOKIT_KEY_PWD`. Without signing material the
HAP is packaged with hvigor's own signature, unsigned as a last resort. The
HarmonyOS bundle name is `com.lullaby.steins_player.ohos`, and provisioning
profiles are issued per bundle name, so a rename needs a new profile.

## iOS

`.github/workflows/ios.yml` builds iOS on a `macos-15` runner (`analyze`, unit
tests, `flutter build ios --release --no-codesign`, plus a boot smoke test on an
iPhone simulator). Signing for a device or TestFlight needs an Apple Developer
account and is not covered. On macOS, locally: `flutter build ios --release
--no-codesign`, or `flutter test integration_test/app_boot_test.dart -d
<simulator-udid>` for the smoke test.

`integration_test/app_boot_test.dart` waits for the splash screen to hand over
to the home page, which only happens once the introduction clip has played
through libmpv - that covers `MediaKit.ensureInitialized()`, the texture video
output and playback. `res\` and `dist\` are not in the repository, so the
workflow fills the declared asset paths from `test/fixtures/loading.mp4`
(`tool/stub_assets.sh`) and builds with the HarmonyOS SDK fork the project uses.

Xcode project: `ios/Runner.xcworkspace`, bundle id `com.lullaby.steinsplayer`,
landscape only, icon from `res/icon_ios.png` (opaque 1024x1024; the transparent
`res/icon.png` is invalid for iOS). `packages/file_picker_ohos` is a trimmed copy
of the OHOS fork of `file_picker`, with its podspecs and Objective-C module named
after the package - otherwise CocoaPods fails with
`No podspec found for file_picker_ohos`. Keep it in sync with the fork.

## Update feed

On start the app fetches `version.json` (`Update.feedUrl`) and, for a newer
release, shows the notes with one button per link:

```json
{ "version": "1.1.0", "announcement": "release notes",
  "download_url": "https://example.net/primary", "download_name": "百度网盘",
  "download_url2": "https://example.net/mirror", "download_name2": "夸克网盘" }
```

`download_url2` / `download_name2` are optional; unnamed links get `去下载` and
`备用下载`, empty ones are skipped.
