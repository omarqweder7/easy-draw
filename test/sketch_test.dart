import 'dart:io';
import 'dart:typed_data';

import 'package:easy_draw/services/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Sanity checks for the on-device sketch filters.
///
/// Uses a synthetic test image (gradient + shapes) so it runs anywhere. Set
/// EASYDRAW_SKETCH_OUT to a folder to also write the PNGs for inspection.
void main() {
  Uint8List testImage() {
    final im = img.Image(width: 400, height: 300);
    for (final p in im) {
      final v = 120 + (p.x * 100 ~/ 400); // soft background gradient
      p
        ..r = v
        ..g = v - 10
        ..b = v - 20;
    }
    img.fillRect(im, x1: 60, y1: 60, x2: 200, y2: 200, color: img.ColorRgb8(60, 50, 40));
    img.fillCircle(im, x: 290, y: 150, radius: 60, color: img.ColorRgb8(220, 210, 200));
    return Uint8List.fromList(img.encodePng(im));
  }

  final out = Platform.environment['EASYDRAW_SKETCH_OUT'];
  final src = Platform.environment['EASYDRAW_SKETCH_SRC'];

  for (final effect in SketchEffect.values) {
    test('sketch ${effect.name} produces mostly-white paper with some dark lines', () async {
      final input = src != null ? await File(src).readAsBytes() : testImage();
      final png = await sketchToPng(input, SketchParams(effect: effect), maxSide: 800);
      final res = img.decodePng(png)!;
      var dark = 0, total = 0;
      for (final p in res) {
        total++;
        if (p.r < 128) dark++;
      }
      final ratio = dark / total;
      if (out != null) await File('$out/sketch_${effect.name}.png').writeAsBytes(png);
      // A line drawing: some ink, but mostly paper.
      expect(ratio, greaterThan(0.002), reason: 'no lines found');
      expect(ratio, lessThan(0.45), reason: 'too dark: ${(ratio * 100).toStringAsFixed(1)}% ink');
    });
  }

  test('flood fill stays inside a closed outline', () async {
    const w = 50, h = 50;
    final boundary = Uint8List(w * h * 4);
    // Draw a closed square outline from (10,10) to (40,40).
    for (var i = 10; i <= 40; i++) {
      for (final (x, y) in [(i, 10), (i, 40), (10, i), (40, i)]) {
        final o = (y * w + x) * 4;
        boundary[o + 3] = 255;
      }
    }
    final r = await floodFillRegion(boundary, w, h, 25, 25, 0xFFFF0000);
    // The region is cropped to the fill: inside the outline, grown by 1 px.
    expect([r.left, r.top, r.width, r.height], [10, 10, 31, 31]);
    int alphaAt(int x, int y) {
      final lx = x - r.left, ly = y - r.top;
      if (lx < 0 || ly < 0 || lx >= r.width || ly >= r.height) return 0;
      return r.rgba[(ly * r.width + lx) * 4 + 3];
    }
    expect(alphaAt(25, 25), 255);
    expect(alphaAt(12, 12), 255);
    expect(alphaAt(5, 5), 0, reason: 'fill leaked outside the outline');
    expect(alphaAt(45, 45), 0);
  });
}
