import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_draw/screens/canvas/canvas_model.dart';
import 'package:easy_draw/services/image_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Pixel-exact regression tests for committed drawing output.
///
/// Each case renders fixed strokes through the real commit path
/// ([appendToLayer]) and the undo/replay path ([rebuildLayer]) and compares the
/// premultiplied RGBA bytes with a stored golden. Performance work on the
/// canvas must keep these byte-identical.
///
/// Regenerate the goldens (only when output is *meant* to change):
///   $env:UPDATE_STROKE_GOLDENS="1"; flutter test test/stroke_pixels_test.dart
const doc = Size(400, 300);
final goldenDir = Directory('test/goldens');
final update = Platform.environment['UPDATE_STROKE_GOLDENS'] == '1';

List<Offset> path(int n, {double seed = 0}) => [
      for (var i = 0; i < n; i++)
        Offset(200 + 150 * sin(i * 0.09 + seed) * cos(i * 0.013), 150 + 110 * sin(i * 0.07 + 1.1 + seed)),
    ];

StrokeOp stroke(Tool tool, List<Offset> pts, {double size = 8, double opacity = 1, Color color = const Color(0xFF1A2B3C), bool varyWidth = false}) {
  final s = StrokeOp(tool: tool, color: color, size: size, opacity: opacity);
  for (var i = 0; i < pts.length; i++) {
    s.add(pts[i], varyWidth ? 0.45 + 0.8 * (0.5 + 0.5 * sin(i * 0.21)) : 1.0);
  }
  return s;
}

Future<Uint8List> pixels(ui.Image img) async => (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// Renders [ops] through append and through replay; both must match.
Future<Uint8List> renderLayer(List<DrawOp> ops, {ui.Image? base}) async {
  final appended = CanvasLayer(id: 'a', name: 'a', base: base);
  for (final op in ops) {
    appended.ops.add(op);
    await appendToLayer(appended, op, doc);
  }
  final replayed = CanvasLayer(id: 'r', name: 'r', base: base)..ops.addAll(ops);
  await rebuildLayer(replayed, doc);
  final a = await pixels(appended.cache!);
  final r = await pixels(replayed.cache!);
  expect(_firstDiff(a, r), isNull, reason: 'append and replay differ');
  return a;
}

String? _firstDiff(Uint8List a, Uint8List b) {
  if (a.length != b.length) return 'length ${a.length} vs ${b.length}';
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return 'byte $i (pixel ${i ~/ 4}): ${a[i]} vs ${b[i]}';
  }
  return null;
}

Future<void> matchGolden(String name, Uint8List px) async {
  final f = File('${goldenDir.path}/pixels_$name.rgba.gz');
  if (update || !f.existsSync()) {
    goldenDir.createSync(recursive: true);
    f.writeAsBytesSync(gzip.encode(px));
    if (!update) fail('Golden $name was missing and has been created; re-run.');
    return;
  }
  final golden = Uint8List.fromList(gzip.decode(f.readAsBytesSync()));
  expect(_firstDiff(px, golden), isNull, reason: 'pixels differ from golden $name');
  // Guard against an empty render passing trivially.
  expect(px.any((b) => b != 0), isTrue);
}

/// A full-document image with a closed outline, used for fill boundaries.
Future<ui.Image> outlineImage() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = const Color(0xFF111111);
  c.drawRect(const Rect.fromLTWH(60, 40, 180, 150), p);
  c.drawCircle(const Offset(300, 200), 60, p);
  return rec.endRecording().toImage(doc.width.round(), doc.height.round());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pencil stroke', () async {
    await matchGolden('pencil', await renderLayer([stroke(Tool.pencil, path(160), size: 6)]));
  });

  test('pen stroke + dot', () async {
    await matchGolden(
        'pen',
        await renderLayer([
          stroke(Tool.pen, path(160, seed: 1), size: 9, opacity: 0.7, color: const Color(0xFFD32F2F)),
          stroke(Tool.pen, [const Offset(50, 260)], size: 12),
        ]));
  });

  test('brush strokes (long, variable width, dot)', () async {
    await matchGolden(
        'brush',
        await renderLayer([
          stroke(Tool.brush, path(260, seed: 2), size: 14, opacity: 0.6, color: const Color(0xFF1E88E5), varyWidth: true),
          stroke(Tool.brush, path(40, seed: 4), size: 22, opacity: 0.9, color: const Color(0xFF43A047), varyWidth: true),
          stroke(Tool.brush, [const Offset(30, 30)], size: 16, color: const Color(0xFFFFB300)),
        ]));
  });

  test('eraser over strokes', () async {
    await matchGolden(
        'eraser',
        await renderLayer([
          stroke(Tool.pen, path(120, seed: 3), size: 30, color: const Color(0xFF6A1B9A)),
          stroke(Tool.eraser, path(120, seed: 3.6), size: 18),
        ]));
  });

  test('fill inside an outline, then a second fill', () async {
    final boundary = await outlineImage();
    // The fill tool reads straight (non-premultiplied) RGBA, like _fillAt.
    final data = (await boundary.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
    final w = doc.width.round(), h = doc.height.round();
    final m1 = await floodFillMask(data, w, h, 120, 100, 0xFFFF7043);
    final m2 = await floodFillMask(data, w, h, 300, 200, 0x8042A5F5);
    final fills = [FillOp(await imageFromRgba(m1, w, h)), FillOp(await imageFromRgba(m2, w, h))];
    await matchGolden('fill', await renderLayer(fills));
  });

  test('clear op then stroke', () async {
    await matchGolden(
        'clear',
        await renderLayer([
          stroke(Tool.pen, path(80), size: 10),
          ClearOp(),
          stroke(Tool.pencil, path(80, seed: 5), size: 4),
        ]));
  });
}
