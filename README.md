# Easy Draw

A free drawing assistant for Android and iOS. It shows a reference image over the
phone's live camera view so you can copy it onto real paper, and adds a trace
mode, illustrated lessons, photo-to-sketch, text art and a digital canvas.

Everything is free: no ads, accounts, subscriptions, purchases, credits or
locked content. The app makes no network requests, and the Android release
build doesn't even request the INTERNET permission.

Built with **Flutter 3.50 / Dart 3.14** (Material comes from the `material_ui`
package in this Flutter version).

## Features

| Area | What works |
|---|---|
| Camera Drawing | Live rear camera with the reference on top. Opacity, drag, pinch/slider resize, twist/slider rotate (snaps to 0/90/180°), flip ↔/↕, "lines only" (hides white areas), lock (hold-to-unlock), reset, flashlight, hide reference, alignment grid, collapsible panel, capture (photo only / with overlay / both), and recording (camera view only, silent by default). Keeps the screen awake and locks to the current orientation for the session. |
| Trace Mode | Bright plain backdrop (adjustable), max screen brightness (restored on exit), the same reference controls, and a lock that hides controls, ignores touches, goes full-screen and needs a 1.5 s press-and-hold to unlock. Includes a safety note about thin paper and gentle pressure. |
| Library | 41 original line-art references in 10 categories, with search, category/difficulty/style filters, favourites, recents and featured items. |
| Lessons | 9 illustrated step-by-step lessons (54 steps) with materials, time, progress bar, previous/next, saved progress, and "trace this step" / "camera with this step". |
| Import / Photo to Sketch | System photo picker or camera, then crop/rotate/flip. Outline, pencil and black-and-white effects with edge, detail, contrast and brightness controls, white-background removal, sketch/original/compare views, and full-resolution processing with a progress bar. All of it runs on the device in background isolates. |
| Text Art | 8 bundled OFL fonts (Latin, Arabic, Hebrew), size, alignment, letter/line spacing, outline or filled, colours, rotation, mirror and multiline. Arabic stays joined (letter spacing is disabled for Arabic text) and RTL is detected automatically. |
| Digital Canvas | Pencil, pen, brush (pressure- or speed-sensitive), eraser and fill. Size and opacity, HSV colour picker with saved swatches, undo/redo, pinch-zoom and two-finger pan, up to 8 layers (visibility, opacity, order, rename), and an optional reference layer. Coloring pages put the outline on a protected top layer. Autosaves, and exports PNG/JPEG. |
| My Art | Projects, captures, recordings, imports, sketches, text art and drawings. Reopen, rename, favourite, duplicate, delete (with confirmation), save to Photos (PNG/JPEG/video), share, mark a project as finished, and play videos. |
| Settings | Light/dark/system theme, English/العربية/עברית (full RTL), reduce motion, drawing hand (moves workspace toolbars), drawing defaults, storage usage and cleanup, setup guide, permissions and privacy, and licences. |

## Setup

1. Install Flutter 3.50+ (`flutter doctor` should pass for Android and/or iOS).
2. `flutter pub get`
3. Android: `flutter run`, or `flutter build apk --release`.
   - `compileSdk` is 37 (required by `permission_handler_android`). Install
     Android SDK Platform 37.
   - Release builds are signed with the permanent release key from
     `android/key.properties` (create it once with
     `tools/create_release_key.ps1`; see [RELEASING.md](RELEASING.md)).
     Without it they fall back to the debug key, and those builds can't
     update or be updated by real releases.
4. iOS (needs macOS with Xcode): `cd ios && pod install && cd .. && flutter run`.
   - The Podfile enables only the camera, microphone and photos permissions
     for `permission_handler`, and `Info.plist` has the usage strings.
   - Set your team and bundle ID in Xcode.

### Tests

`flutter test` checks the sketch filters, flood fill containment and the
blur. To also write the sketch outputs for a real photo:

```powershell
$env:EASYDRAW_SKETCH_SRC="C:\path\photo.jpg"; $env:EASYDRAW_SKETCH_OUT="C:\temp"; flutter test test/sketch_test.dart
```

## Adding content

- **References** are generated from `tools/generate_content.py`, which holds
  hand-authored vector drawings. Add a drawing and an entry to `REFS`, then run
  `python tools/generate_content.py`. You can also drop any SVG or PNG into
  `assets/library/<category>/` and add it to
  `assets/library/references.json`, with titles in en/ar/he.
- **Lessons** live in `assets/lessons/lessons.json` (also generated). Each
  step is a list of SVG path strings plus a short instruction in three
  languages. Steps render cumulatively, with the current step in pink.
- **UI strings**: English sits inline in `context.tr('key', 'English')`, and
  Arabic and Hebrew are in `lib/app/l10n_ar.dart` and `lib/app/l10n_he.dart`.
  Run `python tools/extract_strings.py --missing` to list untranslated keys.
- **App icon**: `assets/icon/icon_full.png` (1024 px) is the source. The
  Android adaptive background, `icon_background.png`, is a gradient built from
  the icon's corner colours, and `assets/brand/logo.png` is the in-app logo.
  After changing the icon, run `dart run flutter_launcher_icons`.
- **Colours** come from the icon: charcoal-green surfaces, a lime accent
  (`#B8F23D`, always with dark text on it) and slate grays. Light mode uses
  olive `#3F6B00` for readable accents. See `lib/app/theme.dart`.

## Project layout

```
lib/
  app/        theme, settings, l10n (+ ar/he tables), app scope
  data/       models, content repo (library/lessons/favourites/progress), My Art store
  services/   image ops (isolates: import, sketch, flood fill, JPEG), reference loader, share/gallery/permissions
  widgets/    overlay model + gestures, shared controls, lesson painter
  screens/    home, explore, lessons, create, my art, camera, trace, import, sketch, text art, canvas/, settings, onboarding
assets/       brand art, fonts (+ OFL licences), library SVGs, lessons JSON, icons
tools/        content generator, string extractor
```

## Platform limitations

- **The overlay is not projected.** The reference appears on the phone screen
  only. Locking freezes it relative to the screen; it doesn't track the paper,
  so the phone and paper must stay still. The app says this in onboarding, in
  the workspace help and in the lock message.
- **Recordings don't include the overlay.** The camera plugin records the
  camera stream only. Compositing the overlay into video would need native
  screen recording (MediaProjection on Android, ReplayKit on iOS), which isn't
  implemented. The record sheet says exactly what will be recorded. Photo
  captures *can* include the overlay.
- **Capture alignment** assumes the photo has the same field of view as the
  preview (true for the camera plugin's matching presets). The with-overlay
  image is cropped to exactly the area visible on screen.
- **Background removal** is white/light-background suppression, not subject
  segmentation. That would need an ML model, which isn't bundled, and the UI
  doesn't claim otherwise.
- **AI text-to-sketch generation is omitted.** There's no free, credit-free
  on-device text-to-image model that runs reliably across ordinary phones
  inside a Flutter app without a multi-GB download. Per the brief it isn't in
  the interface, and nothing pretends to be AI-generated. The rest of the app
  doesn't depend on AI.
- **Flashlight** availability depends on the device. When it isn't
  supported, the app shows a message and disables the button.
- **Canvas undo history** is kept in memory for the current session; layer
  images are saved. Very old strokes (after 50 per layer) are flattened to
  keep memory bounded.
- **iOS** hasn't been built or run here, because this project was developed on
  Windows. The code uses only cross-platform plugins (camera, image_picker,
  share_plus, gal, screen_brightness, wakelock_plus, permission_handler,
  video_player), and the iOS permission strings and Podfile are configured.
  Verify on a Mac before release.

## Design system

The UI uses the graphite and electric-lime design system in `lib/design/`.
Import `design.dart` and read `context.ds` for palette colors and
`context.text` for typography. Space Grotesk is used for headings and Inter
for body text; Arabic uses Cairo and Hebrew uses Rubik.

- Use `Space` for the 8-point spacing grid, `Radii` for angular corners, and
  `Sizes.touch` for targets of at least 48 logical pixels.
- Reserve lime for the primary action and active states. Put dark text on lime.
  On light surfaces, use `accentText` (dark green) for accent text and icons.
- Use `EDButton`, `EDIconButton`, `EDChip`, `EDSegmented`, `EDSlider`, and
  `EDTextField` instead of independently styled framework controls.
- Use `EDTopBar`, `EDCard`, `EDGroup`, `EDListRow`, and `EDSwitchRow` for
  consistent screen structure. Use `showEDSheet` for scrollable options.
- Use `Pressable` for custom interactions, including keyboard focus,
  semantics and haptics. All feedback honors the Haptic feedback preference.
- Use `Motion.of(context)` for animations so reduced motion is respected.
  Page transitions use the shared 200 ms fade and slide.
- Workspaces keep the graphite palette in both app themes. Physical tool
  placement follows drawing handedness; language direction follows the locale.
- Allow content to scroll on short screens and grow with text scale. Gallery
  cards use fixed card extents with extra space for scaled metadata.

`test/layout_test.dart` covers English/Arabic, dark/light, 320×568, 412×915
and 915×412, and text scales 1.0/1.3. It exercises the main screens, Explore's
two tabs, language sheets, onboarding pages and content below the fold.
`ArtStore.init(root: temporaryDirectory)` isolates test files from real art.
Run `flutter test` and `python tools/extract_strings.py --missing` before
shipping. Camera, trace, recording and export still require device checks.

See `HANDOFF.md` for the validation status of the current working copy.

## Installing and updating (Android)

Download the latest `easy-draw-vX.Y.Z.apk` from the repo's
[Releases](https://github.com/omarqweder7/easy-draw/releases) page and open
it on the phone. You may need to allow installing from your browser or file
manager.

To update, install the newer APK the same way. It installs over the old
version and keeps your drawings. The app itself never goes online, so it
won't tell you about new versions. Check the Releases page, or press
**Watch → Custom → Releases** on GitHub to get notified.

Maintainers: see [RELEASING.md](RELEASING.md).

## License

Easy Draw is released under the [MIT License](LICENSE).

Fonts are under the SIL Open Font License 1.1 (see `assets/fonts/OFL-*.txt`).
All library and lesson artwork is original to this project.
