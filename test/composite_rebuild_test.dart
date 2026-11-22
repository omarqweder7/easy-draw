import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_draw/data/art_store.dart';
import 'package:easy_draw/data/models.dart';
import 'package:easy_draw/screens/canvas/canvas_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Autosave skips composite.png, so ArtStore must rebuild a stale one from
/// the layer PNGs exactly the way the canvas composites for export.
void main() {
  const doc = Size(64, 48);
  late Directory root;
  late ArtStore art;
  late ArtItem item;
  late Directory dir;
  final layers = <CanvasLayer>[];

  Future<ui.Image> paint(void Function(Canvas c) f) {
    final rec = ui.PictureRecorder();
    f(Canvas(rec));
    return rec.endRecording().toImage(doc.width.round(), doc.height.round());
  }

  Future<Uint8List> png(ui.Image i) async => (await i.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  Future<Uint8List> rgba(ui.Image i) async => (await i.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  Future<ui.Image> decode(Uint8List bytes) async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('easy_draw_composite_');
    layers
      ..clear()
      ..addAll([
        CanvasLayer(
            id: 'ref',
            name: 'ref',
            kind: LayerKind.reference,
            opacity: 0.35,
            exportable: false,
            base: await paint((c) => c.drawRect(const Rect.fromLTWH(0, 0, 64, 48), Paint()..color = const Color(0xFF1565C0)))),
        CanvasLayer(
            id: 'a',
            name: 'a',
            opacity: 0.6,
            base: await paint((c) => c.drawCircle(const Offset(30, 20), 14, Paint()..color = const Color(0xC8E53935)))),
        CanvasLayer(
            id: 'hidden',
            name: 'hidden',
            visible: false,
            base: await paint((c) => c.drawRect(const Rect.fromLTWH(0, 0, 64, 48), Paint()..color = const Color(0xFF43A047)))),
        CanvasLayer(
            id: 'b',
            name: 'b',
            base: await paint((c) => c.drawLine(const Offset(2, 40), const Offset(60, 4), Paint()
              ..color = const Color(0xFF222222)
              ..strokeWidth = 5))),
      ]);
    // Write a project the way _doSave does, minus composite.png.
    final now = DateTime(2026, 11, 22);
    item = ArtItem(id: 'p1', type: ArtType.project, title: 'p', created: now, modified: now, file: 'projects/p1');
    await File('${root.path}/items.json').writeAsString(jsonEncode([item.toJson()]));
    dir = Directory('${root.path}/projects/p1');
    await dir.create(recursive: true);
    for (final l in layers) {
      await File('${dir.path}/layer_${l.id}.png').writeAsBytes(await png(l.cache!));
    }
    await File('${dir.path}/project.json').writeAsString(jsonEncode({
      'version': 1,
      'w': doc.width,
      'h': doc.height,
      'active': 1,
      'layers': [
        for (final l in layers)
          {'id': l.id, 'name': l.name, 'kind': l.kind.name, 'opacity': l.opacity, 'visible': l.visible, 'exportable': l.exportable, 'file': 'layer_${l.id}.png'},
      ],
    }));
    art = ArtStore();
    await art.init(root: root);
    item = art.byId('p1')!;
  });

  tearDown(() async {
    for (final l in layers) {
      l.disposeAll();
    }
    art.dispose();
    await root.delete(recursive: true);
  });

  test('a missing composite is rebuilt to match the canvas export composite', () async {
    // Layers as the canvas sees them after reopening (decoded from the PNGs).
    final reopened = [
      for (final l in layers)
        CanvasLayer(id: l.id, name: l.name, kind: l.kind, opacity: l.opacity, visible: l.visible, exportable: l.exportable, base: await decode(await File('${dir.path}/layer_${l.id}.png').readAsBytes())),
    ];
    final want = await composite(reopened, doc);
    final comp = File('${dir.path}/composite.png');
    // init() may already have started the rebuild; ensureComposite joins it.
    await art.ensureComposite(item);
    expect(await comp.exists(), isTrue);
    final got = await decode(await comp.readAsBytes());
    expect(await rgba(got), await rgba(want));
    for (final l in reopened) {
      l.disposeAll();
    }
    got.dispose();
    want.dispose();
  });

  test('a fresh composite is left alone; an older one is rebuilt', () async {
    final comp = File('${dir.path}/composite.png');
    final json = File('${dir.path}/project.json');
    await art.ensureComposite(item);
    expect(await art.ensureComposite(item), isFalse, reason: 'fresh composite rebuilt again');
    // Simulate an autosave after the last composite write (e.g. then a crash).
    await comp.setLastModified((await json.lastModified()).subtract(const Duration(seconds: 5)));
    expect(await art.ensureComposite(item), isTrue, reason: 'stale composite not rebuilt');
    expect(await art.ensureComposite(item), isFalse);
  });
}
