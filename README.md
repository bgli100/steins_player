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

Packages land in `dist\` (git-ignored), named after the version in
`pubspec.yaml`. Tool paths and signing material go in the git-ignored
`build.local.json` - copy `build.local.example.json`; every key is also a script
parameter, and the passwords fall back to `$env:HOKIT_KEYSTORE_PWD` /
`$env:HOKIT_KEY_PWD` (HarmonyOS) and `$env:LULLABY_KEYSTORE_PWD` /
`$env:LULLABY_KEY_PWD` (Android). Without signing material the HAP is unsigned
and the APK is debug-signed - some devices refuse a debug-signed APK, so the
release key lives in `android\keystore\lullaby-release.jks` and its password in
`build.local.json`; **back that file up**, an app installed from it can only be
updated with it. The build writes `android\key.properties` (git-ignored) for
Gradle, which picks the signing scheme (v2 for this minSdk), and verifies the
result with apksigner afterwards. The HarmonyOS bundle name is
`com.lullaby.steins_player.ohos`, and provisioning profiles are issued per bundle
name, so a rename needs a new profile.

## iOS

Xcode only runs on macOS, so iOS is built by CI:
`.github/workflows/ios.yml` (analyze, unit tests, unsigned build, boot smoke test
on an iPhone simulator). Signing for a device or TestFlight needs an Apple
Developer account.

`packages/file_picker_ohos` is a trimmed copy of the OHOS fork of `file_picker`,
with its podspecs and Objective-C module named after the package - CocoaPods
fails otherwise. Keep it in sync with the fork.
