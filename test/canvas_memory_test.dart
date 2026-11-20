import 'dart:ui' as ui;

import 'package:easy_draw/screens/canvas/canvas_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const doc = Size(64, 48);

Future<ui.Image> solid(Color c) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawColor(c, BlendMode.src);
  return rec.endRecording().toImage(doc.width.round(), doc.height.round());
}

StrokeOp line() => StrokeOp(tool: Tool.pen, color: const Color(0xFF000000), size: 4, opacity: 1)
  ..add(const Offset(5, 5), 1)
  ..add(const Offset(50, 40), 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a reopened layer (base loaded from disk) survives draw + undo', () async {
    // _loadProject creates layers from the base image loaded from disk.
    final base = await solid(const Color(0xFF00FF00));
    final layer = CanvasLayer(id: 'l', name: 'l', base: base);
    expect(layer.cache, isNotNull);
    final op = line();
    layer.ops.add(op);
    await appendToLayer(layer, op, doc); // draw a stroke
    layer.ops.remove(op);
    await rebuildLayer(layer, doc); // undo it: must still draw the base
    expect(base.debugDisposed, isFalse, reason: 'the layer base was disposed while still in use');
  });

  test('disposeAll releases base, cache and fill images; strokes hold no images', () async {
    final base = await solid(const Color(0xFF00FF00));
    final fill = FillOp(await solid(const Color(0x80FF0000)));
    final layer = CanvasLayer(id: 'l', name: 'l', base: base)..ops.addAll([line(), fill]);
    expect(opImageBytes(layer.ops), 64 * 48 * 4);
    final cache = layer.cache!;
    layer.disposeAll();
    expect(base.debugDisposed, isTrue);
    expect(cache.debugDisposed, isTrue);
    expect(fill.image.debugDisposed, isTrue);
    expect(layer.ops, isEmpty);
  });
}
