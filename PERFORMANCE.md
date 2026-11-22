# Easy Draw: performance pass (November 2026)

A measured pass over drawing, fills, saving, image decoding and rebuilds.
Every change keeps the features, UI and pixels the same. Committed strokes
and fills are checked byte-for-byte by `test/stroke_pixels_test.dart`, and
those goldens were never regenerated during this pass.

## How the numbers were measured

- Android emulator (`Medium_Phone_API_37.0`, x86_64), **profile** builds. No
  physical device was available. Emulator speed drifts from day to day (pen
  raster time measured 1.95 ms one day and 8 ms another on the same code),
  so each number is a **same-session A/B**: the before and after APKs are
  installed and run in turn, 2–3 rounds each. Compare the before and after
  in a row with each other, never with a row from another fix.
- The harness (timing probes, scripted strokes, build counters) lives
  outside the repo in `EasyDraw-perf-harness/` and is applied only to a
  scratch copy of `lib/`. The app ships no measurement code.
- The emulator hides GPU memory from `dumpsys meminfo`, so image memory is
  counted inside the app: live `ui.Image` pixel buffers, with clones
  counted once. Decoded-photo memory is `imageCache.currentSizeBytes`.

## Results

| # | Commit | What changed | Metric | Before | After |
|---|--------|--------------|--------|-------:|------:|
| 1 | `3e7a174` | Live brush bakes finished segments every 4 segments | 10 s brush stroke: frames rendered | 147 | 655 |
|   |   |   | raster time avg per frame | 126–133 ms, grows to 318 ms | 15 ms, flat |
|   |   |   | ten 1 s brush strokes, raster avg | 39–40 ms | 15–16 ms |
| 2 | `3b30bce` | Discarded images released; 64 MB fill-image budget | 8 layers + 20 full-page fills: live pixel buffers / memory | 27 / 324 MB | 17 / 204 MB |
| — | `ec05f08` | Bug fix found while measuring: base and cache shared one image | undo after reopening a project | threw "non-genuine Image" | works |
| 3 | `c936dfe` | Fill returns only its bounding box, drawn at an integer origin; scan-line seeds per run | fill, blank page | 147 ms | 123 ms |
|   |   |   | fill, region of a coloring page | 129 ms | 65 ms |
|   |   |   | 20 full-page fills (memory scenario), per fill | 151 ms | 134 ms |
|   |   |   | region fill image upload | ~36 ms | ~4 ms |
| 4 | `63d4ac7` | Autosave skips `composite.png`; written on exit, pause, export or every 30 s | autosave, 1 dirty layer | 177 ms | 100 ms |
|   |   |   | autosave, 8 dirty layers | 769 ms | 698 ms |
| 7 | `a6a4cd5` | Photos decoded at screen size (`cacheWidth`) | Art detail, 4096×3072 capture: decoded / first decode | 48.0 MB / 125 ms | 13.3 MB / 72 ms |
|   |   |   | Sketch original, 2048×1536: decoded / first decode | 12.0 MB / 48 ms | 3.3 MB / 38 ms |
| 8 | `2a0c9c2` | REC timer updates only its label | whole-workspace rebuilds per 10 s of recording | 10 | 0 |
|   |   |   | frame build time p99 | 1.24–1.27 ms | 0.51–0.69 ms |
| 8 | `ce90868` | Save status and undo/redo listen with `ValueNotifier`s | whole-screen rebuilds, 10 strokes + autosave | 12 | 0 |
|   |   |   | frame build time p99 | 0.92–0.96 ms | 0.41–0.50 ms |
| 8 | `e1f0674` | ArtStore caches the sorted list and file existence | `items` getter, per access (64 items) | 14.9 µs | ~0 µs |
|   |   |   | picker/Home work per build | 184 µs | 100 µs |

Medians of the same-session runs. The commit messages have the ranges and
phase breakdowns.

Notes:
- **Fill memory (3).** A full-page fill still crops to the whole page, so
  the 8-layer memory scenario stays at 204 MB. Region fills, the common case
  on coloring pages, now hold only their bounding box.
- **Photo decode (7).** For a 4096 px **PNG** (imports and sketches can be
  PNG), resizing makes the first decode about 40 ms slower (124 → 166 ms).
  Memory still falls from 48 to 13.3 MB. Captures are JPEG and got faster.
- **Composite (4).** A crash between an autosave and exit can leave
  `composite.png` older than `project.json`. ArtStore rebuilds it from the
  layer PNGs at startup and when the detail screen opens.
  `test/composite_rebuild_test.dart` checks the rebuild is pixel-identical
  to the canvas export. Checked on the emulator: autosave leaves the
  composite older, Back writes it, and a force-stop after an autosave is
  repaired on relaunch.

## Deliberately left alone

- **Undo checkpoints (Fix 5).** Undo already takes 13–15 ms. A checkpoint
  costs 12.6 MB per full-page image, which is a poor trade for a latency
  nobody notices.
- **Cached layer composites (Fix 6).** With 8 layers the per-frame gain on
  the emulator was +0.5 ms, for about 25 MB of extra images.
- **Pencil blur.** Left as decided in Phase 1. Not re-measured in this
  phase.
- **Startup.** Loading content and art is 50–80 ms of a ~1.16 s cold start.
  The rest is engine and plugin start-up, which these changes can't move.
- **`ResolutionPreset.veryHigh`.** The emulator's virtual camera can't
  show whether a lower preset helps or hurts real captures. Decide this on
  a real phone.

## Found but not changed (needs a decision)

**Pre-existing autosave race.** This was already there before the pass,
and it is in the saving code.
1. If a stroke lands while an autosave is running, that save still ends
   by setting the status to "Saved", which overwrites "Pending". The
   1.5 s timer saves the stroke later. Leaving within that window used to
   skip the save. After Fix 4, exit saves whenever anything changed since
   the last composite, so this case is now covered on exit.
2. If the stroke lands on the very layer whose PNG is being encoded
   (~80 ms), the save clears that layer's `dirty` flag after writing the
   older image. The new stroke is then not written until that layer
   changes again. If the app is killed before that, the stroke is lost on
   disk. The window is small but real.

A possible fix: give each layer a change counter, clear `dirty` only if the
counter didn't move during the encode, and only report "Saved" when no
change arrived during the save.

## Bigger ideas for later

- **Dirty-rect layer updates.** `appendToLayer` re-renders the whole page
  (`toImage` of the full page) for every stroke. Rendering only the stroke's
  bounds into a tile cache would cut per-stroke GPU work and memory.
- **Undo as patches.** Store the pixels under each op's bounds instead of
  full-page images. That would make Fix 5's checkpoints affordable and
  shrink fill memory further.
- **Fill readback.** Each fill reads back the whole page (`toByteData`,
  25–35 ms). Keeping a CPU copy of the boundary between fills, refreshed
  only where strokes changed, would remove most of it.
- **Faster layer saves.** PNG encoding is ~80 ms per dirty layer. Raw RGBA
  plus fast compression in an isolate, or saving only changed tiles, would
  make 8-layer saves much cheaper.
- **Measure on real phones,** especially a low-end Android and an iPhone.
  Every number here comes from an emulator.
