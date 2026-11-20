import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../widgets/lesson_painter.dart';

/// Thrown when a reference can't be read (e.g. a deleted file).
class RefLoadFailure implements Exception {
  RefLoadFailure(this.cause);
  final Object cause;
}

/// Loads any [RefSource] as a GPU image, downscaled so its longest side is at
/// most [maxSide] pixels.
Future<ui.Image> loadRefImage(RefSource src, {int maxSide = 2048}) async {
  try {
    switch (src.kind) {
      case RefKind.lessonStep:
        return await renderLessonImage(src.lesson!, src.step, maxSide: maxSide);
      case RefKind.asset:
        if (src.isSvg) return await _renderSvg(SvgAssetLoader(src.path), maxSide);
        final data = await rootBundle.load(src.path);
        return await decodeBytes(data.buffer.asUint8List(), maxSide: maxSide);
      case RefKind.file:
        final f = File(src.path);
        if (!await f.exists()) throw RefLoadFailure('missing');
        final bytes = await f.readAsBytes();
        if (src.isSvg) return await _renderSvg(SvgBytesLoader(bytes), maxSide);
        return await decodeBytes(bytes, maxSide: maxSide);
    }
  } on RefLoadFailure {
    rethrow;
  } catch (e) {
    throw RefLoadFailure(e);
  }
}

Future<ui.Image> decodeBytes(Uint8List bytes, {int maxSide = 2048}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  final scale = min(1.0, maxSide / max(desc.width, desc.height));
  final codec = await desc.instantiateCodec(
    targetWidth: max(1, (desc.width * scale).round()),
    targetHeight: max(1, (desc.height * scale).round()),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
  return frame.image;
}

Future<ui.Image> _renderSvg(BytesLoader loader, int maxSide) async {
  final info = await vg.loadPicture(loader, null);
  final s = maxSide / max(info.size.width, info.size.height);
  final w = max(1, (info.size.width * s).round());
  final h = max(1, (info.size.height * s).round());
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(s);
  canvas.drawPicture(info.picture);
  final img = await rec.endRecording().toImage(w, h);
  info.picture.dispose();
  return img;
}

Future<Uint8List> encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('PNG encoding failed');
  return data.buffer.asUint8List();
}

/// Renders an image on an opaque white background (for JPEG export or a
/// preview of transparent line art).
Future<ui.Image> flattenOnWhite(ui.Image image) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawColor(Colors.white, BlendMode.src);
  c.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  return rec.endRecording().toImage(image.width, image.height);
}

/// Colour matrix that turns light pixels transparent while keeping dark lines,
/// so a white-background reference doesn't wash out the camera view.
const linesOnlyMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  -0.2126, -0.7152, -0.0722, 1, 0, // alpha *= darkness (applied after ×alpha)
];

/// A gentler version used on top of the alpha already in the image: alpha_out
/// = alpha_in − luminance, i.e. white → transparent, black → unchanged.
ColorFilter linesOnlyFilter() => const ColorFilter.matrix(linesOnlyMatrix);
