# Releasing Easy Draw (Android)

Releases are APKs on the repo's GitHub Releases page. The app makes no
network requests and never checks for updates itself. People update by
installing the newer APK over the old one, and their drawings are kept.

Android installs an update over an existing copy only when:
1. it is signed with the **same key** as the installed version, and
2. its `versionCode` is **higher**.

## One-time setup: the release key

```powershell
powershell -ExecutionPolicy Bypass -File tools\create_release_key.ps1
```

The script:
- creates the key in `%USERPROFILE%\.easydraw\easy-draw-release.jks`;
- writes `android\key.properties` (git-ignored) for local release builds;
- can store the key in the GitHub secrets `EASYDRAW_KEYSTORE_BASE64` and
  `EASYDRAW_KEY_PASSWORD` for the release workflow.

**Back up the `.jks` file and its password** in a password manager and on
another drive. If either is lost, nobody who installed the app can update
again. They would have to uninstall, and lose their drawings.

Never commit the key or `key.properties`. `android/.gitignore` already
excludes `key.properties`, `*.jks` and `*.keystore`.

## Each release

1. Bump `version:` in `pubspec.yaml`. The part after `+` is the Android
   `versionCode` and must go up every time. For example, `1.0.0+1` becomes
   `1.0.1+2`.
2. Run `flutter test` and `python tools/extract_strings.py --missing`.
3. Commit, then tag and push. The tag must be `v` followed by the version
   before the `+`:

   ```powershell
   git commit -am "Release 1.0.1"
   git tag v1.0.1
   git push origin main v1.0.1
   ```

4. The **Release** workflow (`.github/workflows/release.yml`) checks that the
   tag matches `pubspec.yaml`. It then builds the APK signed with the release
   key and publishes `easy-draw-v1.0.1.apk` as a GitHub Release, with notes
   generated from the commits.

To build a signed APK locally instead, use `flutter build apk --release`. It
uses `android\key.properties`.

## Checking a build

The commands below use the Android SDK's `build-tools` folder:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs easy-draw-v1.0.1.apk
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\aapt.exe" dump badging easy-draw-v1.0.1.apk | Select-String versionCode
```

The certificate SHA-256 must be the same for every release.

## Notes

- Copies of the app signed with the debug key (`flutter run`, or local builds
  without `key.properties`) can't be updated by a release. Uninstall those
  once before installing a release, and export any drawings first, because
  uninstalling deletes them.
- CI doesn't run `flutter test`. The pixel goldens were recorded on Windows,
  and Linux rendering may differ, so run the tests locally before tagging.
- iOS isn't covered. It needs a Mac, an Apple developer account, and
  TestFlight or the App Store.
