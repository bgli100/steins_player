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
`$env:HOKIT_KEY_PWD`. Without signing material the HAP is unsigned. The HarmonyOS
bundle name is `com.lullaby.steins_player.ohos`, and provisioning profiles are
issued per bundle name, so a rename needs a new profile.

## iOS

Xcode only runs on macOS, so iOS is built by CI:
`.github/workflows/ios.yml` (analyze, unit tests, unsigned build, boot smoke test
on an iPhone simulator). Signing for a device or TestFlight needs an Apple
Developer account.

`packages/file_picker_ohos` is a trimmed copy of the OHOS fork of `file_picker`,
with its podspecs and Objective-C module named after the package - CocoaPods
fails otherwise. Keep it in sync with the fork.

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
