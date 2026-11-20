import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// All heavy pixel work runs in background isolates so the UI stays smooth.
/// Nothing here touches the network.

class ImportEdits {
  const ImportEdits({this.quarterTurns = 0, this.flipH = false, this.flipV = false, this.crop});

  final int quarterTurns; // clockwise
  final bool flipH;
  final bool flipV;

  /// Normalised crop rect (0..1) in the rotated/flipped image space.
  final List<double>? crop; // [left, top, right, bottom]
}

class ImportResult {
  ImportResult(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Decodes an image file, applies EXIF orientation, rotation, flips and crop,
/// downsizes to [maxSide], and re-encodes as JPEG (or PNG if it had alpha).
Future<ImportResult> processImport(String path, ImportEdits e, {int maxSide = 2048}) {
  final turns = e.quarterTurns, fh = e.flipH, fv = e.flipV, crop = e.crop;
  return Isolate.run(() async {
    final bytes = await _readFile(path);
    var im = img.decodeImage(bytes);
    if (im == null) throw const FormatException('unsupported image');
    im = img.bakeOrientation(im);
    final hasAlpha = im.numChannels == 4;
    // Downscale early (keeps memory low on huge photos), allowing for crop.
    final longest = max(im.width, im.height);
    final pre = maxSide * 2;
    if (longest > pre) {
      im = img.copyResize(im, width: im.width >= im.height ? pre : null, height: im.height > im.width ? pre : null, interpolation: img.Interpolation.average);
    }
    final t = ((turns % 4) + 4) % 4;
    if (t != 0) im = img.copyRotate(im, angle: 90 * t);
    if (fh) im = img.flipHorizontal(im);
    if (fv) im = img.flipVertical(im);
    if (crop != null) {
      final x = (crop[0] * im.width).round().clamp(0, im.width - 1);
      final y = (crop[1] * im.height).round().clamp(0, im.height - 1);
      final w = ((crop[2] - crop[0]) * im.width).round().clamp(1, im.width - x);
      final h = ((crop[3] - crop[1]) * im.height).round().clamp(1, im.height - y);
      im = img.copyCrop(im, x: x, y: y, width: w, height: h);
    }
    if (max(im.width, im.height) > maxSide) {
      im = img.copyResize(im, width: im.width >= im.height ? maxSide : null, height: im.height > im.width ? maxSide : null, interpolation: img.Interpolation.average);
    }
    final out = hasAlpha ? img.encodePng(im, level: 4) : img.encodeJpg(im, quality: 92);
    return ImportResult(Uint8List.fromList(out), im.width, im.height);
  });
}

Future<Uint8List> _readFile(String path) => File(path).readAsBytes();

/// JPEG encoding for exports (dart:ui only encodes PNG).
Future<Uint8List> encodeJpegFromRgba(Uint8List rgba, int width, int height, {int quality = 92}) {
  return Isolate.run(() {
    final im = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
    final flat = img.Image(width: width, height: height, numChannels: 3);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, im);
    return Uint8List.fromList(img.encodeJpg(flat, quality: quality));
  });
}

Future<Uint8List> imageToJpeg(ui.Image image, {int quality = 92}) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return encodeJpegFromRgba(data!.buffer.asUint8List(), image.width, image.height, quality: quality);
}

// ---------------------------------------------------------------------------
// Sketch conversion
// ---------------------------------------------------------------------------

enum SketchEffect { outline, pencil, blackWhite }

class SketchParams {
  const SketchParams({
    this.effect = SketchEffect.outline,
    this.edge = 0.5,
    this.detail = 0.5,
    this.contrast = 0,
    this.brightness = 0,
    this.transparentBackground = false,
  });

  final SketchEffect effect;
  final double edge; // 0..1
  final double detail; // 0..1
  final double contrast; // -1..1
  final double brightness; // -1..1
  final bool transparentBackground;

  SketchParams copyWith({SketchEffect? effect, double? edge, double? detail, double? contrast, double? brightness, bool? transparentBackground}) =>
      SketchParams(
        effect: effect ?? this.effect,
        edge: edge ?? this.edge,
        detail: detail ?? this.detail,
        contrast: contrast ?? this.contrast,
        brightness: brightness ?? this.brightness,
        transparentBackground: transparentBackground ?? this.transparentBackground,
      );

  List<Object> pack() => [effect.index, edge, detail, contrast, brightness, transparentBackground];
  static SketchParams unpack(List<Object> l) => SketchParams(
        effect: SketchEffect.values[l[0] as int],
        edge: l[1] as double,
        detail: l[2] as double,
        contrast: l[3] as double,
        brightness: l[4] as double,
        transparentBackground: l[5] as bool,
      );
}

/// Grayscale working image.
class GrayImage {
  GrayImage(this.width, this.height, this.data);
  final int width;
  final int height;
  final Uint8List data;
}

/// Loads an encoded image as grayscale at most [maxSide] px (in an isolate).
Future<GrayImage> loadGray(Uint8List encoded, {int maxSide = 640}) {
  return Isolate.run(() {
    var im = img.decodeImage(encoded);
    if (im == null) throw const FormatException('unsupported image');
    im = img.bakeOrientation(im);
    if (max(im.width, im.height) > maxSide) {
      im = img.copyResize(im, width: im.width >= im.height ? maxSide : null, height: im.height > im.width ? maxSide : null, interpolation: img.Interpolation.average);
    }
    return _toGray(im);
  });
}

GrayImage _toGray(img.Image im) {
  final out = Uint8List(im.width * im.height);
  var i = 0;
  for (final px in im) {
    // Transparent pixels become white paper.
    final a = px.aNormalized;
    final l = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
    final maxV = px.maxChannelValue;
    final v = (l / maxV * 255) * a + 255 * (1 - a);
    out[i++] = v.round().clamp(0, 255);
  }
  return GrayImage(im.width, im.height, out);
}

/// Runs the sketch pipeline on a grayscale image and returns straight RGBA.
Future<Uint8List> sketchRgba(GrayImage g, SketchParams p) {
  final w = g.width, h = g.height, data = g.data, packed = p.pack();
  return Isolate.run(() => _sketch(w, h, data, SketchParams.unpack(packed), null));
}

/// Full-resolution conversion from an encoded image with progress (0..1).
Future<Uint8List> sketchToPng(Uint8List encoded, SketchParams p, {int maxSide = 2048, void Function(double)? onProgress}) async {
  final port = ReceivePort();
  final done = Completer<Uint8List>();
  final packed = p.pack();
  final iso = await Isolate.spawn<List<Object>>((args) {
    final send = args[0] as SendPort;
    try {
      final bytes = args[1] as Uint8List;
      final params = SketchParams.unpack((args[2] as List).cast<Object>());
      final maxS = args[3] as int;
      send.send(0.05);
      var im = img.decodeImage(bytes);
      if (im == null) throw const FormatException('unsupported image');
      im = img.bakeOrientation(im);
      send.send(0.2);
      if (max(im.width, im.height) > maxS) {
        im = img.copyResize(im, width: im.width >= im.height ? maxS : null, height: im.height > im.width ? maxS : null, interpolation: img.Interpolation.average);
      }
      final g = _toGray(im);
      send.send(0.3);
      final rgba = _sketch(g.width, g.height, g.data, params, (v) => send.send(0.3 + v * 0.5));
      final outImg = img.Image.fromBytes(width: g.width, height: g.height, bytes: rgba.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
      send.send(0.85);
      final png = img.encodePng(outImg, level: 3);
      send.send(['ok', Uint8List.fromList(png)]);
    } catch (e) {
      send.send(['err', '$e']);
    }
  }, [port.sendPort, encoded, packed, maxSide]);
  port.listen((msg) {
    if (msg is double) {
      onProgress?.call(msg);
    } else if (msg is List) {
      port.close();
      iso.kill();
      if (msg[0] == 'ok') {
        onProgress?.call(1);
        done.complete(msg[1] as Uint8List);
      } else {
        done.completeError(FormatException(msg[1] as String));
      }
    }
  });
  return done.future;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Uint8List _sketch(int w, int h, Uint8List src, SketchParams p, void Function(double)? progress) {
  final n = w * h;
  final sizeFactor = max(w, h) / 800.0;
  // Brightness / contrast.
  final contrast = pow(2.0, p.contrast * 1.6).toDouble();
  final bright = p.brightness * 90;
  final l = Float32List(n);
  for (var i = 0; i < n; i++) {
    l[i] = ((src[i] - 128) * contrast + 128 + bright).clamp(0, 255).toDouble();
  }
  progress?.call(0.15);
  final out = Uint8List(n);
  switch (p.effect) {
    case SketchEffect.outline:
      final r = max(0.5, _lerp(3.2, 0.6, p.detail) * sizeFactor);
      final b = _gaussian(l, w, h, r);
      progress?.call(0.5);
      // Sobel magnitude, then normalise by the image's own strong-edge level
      // (95th percentile) so soft and high-contrast photos both work.
      final mags = Float32List(n);
      final hist = List<int>.filled(1024, 0);
      for (var y = 0; y < h; y++) {
        final y0 = max(0, y - 1) * w, y1 = y * w, y2 = min(h - 1, y + 1) * w;
        for (var x = 0; x < w; x++) {
          final x0 = max(0, x - 1), x2 = min(w - 1, x + 1);
          final gx = (b[y0 + x2] + 2 * b[y1 + x2] + b[y2 + x2]) - (b[y0 + x0] + 2 * b[y1 + x0] + b[y2 + x0]);
          final gy = (b[y2 + x0] + 2 * b[y2 + x] + b[y2 + x2]) - (b[y0 + x0] + 2 * b[y0 + x] + b[y0 + x2]);
          final m = sqrt(gx * gx + gy * gy);
          mags[y1 + x] = m;
          hist[min(1023, m.round())]++;
        }
      }
      var acc = 0, p95 = 1023;
      for (var i = 0; i < 1024; i++) {
        acc += hist[i];
        if (acc >= n * 0.95) {
          p95 = max(8, i);
          break;
        }
      }
      final t0 = _lerp(0.55, 0.12, p.detail); // ignore weaker edges
      final k = _lerp(1.4, 6.0, p.edge); // line darkness
      for (var i = 0; i < n; i++) {
        final v = mags[i] / p95 - t0;
        out[i] = v <= 0 ? 255 : (255 * (1 - min(1.0, v * k))).round();
      }
    case SketchEffect.pencil:
      final inv = Float32List(n);
      for (var i = 0; i < n; i++) {
        inv[i] = 255 - l[i];
      }
      final r = max(1.0, _lerp(16, 2.5, p.detail) * sizeFactor);
      final b = _gaussian(inv, w, h, r);
      progress?.call(0.6);
      final dark = _lerp(0.8, 3.2, p.edge);
      for (var i = 0; i < n; i++) {
        final dodge = min(255.0, l[i] * 255 / (256 - b[i]));
        out[i] = (255 - (255 - dodge) * dark).clamp(0, 255).round();
      }
    case SketchEffect.blackWhite:
      final r = max(2.0, _lerp(26, 5, p.detail) * sizeFactor);
      final mean = _gaussian(l, w, h, r);
      progress?.call(0.6);
      final k = _lerp(24, 1, p.edge);
      for (var i = 0; i < n; i++) {
        out[i] = (l[i] < mean[i] - k || l[i] < 18) ? 0 : 255;
      }
  }
  progress?.call(0.9);
  final rgba = Uint8List(n * 4);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    final v = out[i];
    if (p.transparentBackground) {
      // Keep only the lines: dark = opaque black, white = transparent.
      final a = 255 - v;
      rgba[j] = 20;
      rgba[j + 1] = 20;
      rgba[j + 2] = 20;
      rgba[j + 3] = a < 18 ? 0 : a;
    } else {
      rgba[j] = v;
      rgba[j + 1] = v;
      rgba[j + 2] = v;
      rgba[j + 3] = 255;
    }
  }
  progress?.call(1);
  return rgba;
}

/// Approximate Gaussian blur with three box-blur passes.
Float32List _gaussian(Float32List src, int w, int h, double sigma) {
  final boxes = _boxesForGauss(sigma, 3);
  var a = Float32List.fromList(src);
  var b = Float32List(src.length);
  for (final r in boxes) {
    _boxH(a, b, w, h, r);
    _boxV(b, a, w, h, r);
  }
  return a;
}

List<int> _boxesForGauss(double sigma, int n) {
  final wIdeal = sqrt((12 * sigma * sigma / n) + 1);
  var wl = wIdeal.floor();
  if (wl % 2 == 0) wl--;
  final wu = wl + 2;
  final mIdeal = (12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4);
  final m = mIdeal.round();
  return [for (var i = 0; i < n; i++) ((i < m ? wl : wu) - 1) ~/ 2];
}

void _boxH(Float32List s, Float32List t, int w, int h, int r) {
  if (r <= 0) {
    t.setAll(0, s);
    return;
  }
  final iarr = 1 / (r + r + 1);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var acc = s[row] * r; // window starts at [-r, r-1], edge-clamped
    for (var x = 0; x < r; x++) {
      acc += s[row + min(x, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      acc += s[row + min(x + r, w - 1)];
      t[row + x] = acc * iarr;
      acc -= s[row + max(x - r, 0)];
    }
  }
}

void _boxV(Float32List s, Float32List t, int w, int h, int r) {
  if (r <= 0) {
    t.setAll(0, s);
    return;
  }
  final iarr = 1 / (r + r + 1);
  for (var x = 0; x < w; x++) {
    var acc = s[x] * r;
    for (var y = 0; y < r; y++) {
      acc += s[min(y, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      acc += s[min(y + r, h - 1) * w + x];
      t[y * w + x] = acc * iarr;
      acc -= s[max(y - r, 0) * w + x];
    }
  }
}

// ---------------------------------------------------------------------------
// Flood fill (for the canvas fill tool)
// ---------------------------------------------------------------------------

/// Scan-line flood fill on [boundary] RGBA pixels starting at (sx, sy).
/// Returns an RGBA mask filled with [color] where the region matched.
Future<Uint8List> floodFillMask(Uint8List boundary, int w, int h, int sx, int sy, int color, {int tolerance = 48}) {
  return Isolate.run(() {
    final n = w * h;
    final mask = Uint8List(n);
    int px(int i) => (boundary[i * 4] << 24) | (boundary[i * 4 + 1] << 16) | (boundary[i * 4 + 2] << 8) | boundary[i * 4 + 3];
    final seed = sy * w + sx;
    final target = px(seed);
    final tr = (target >> 24) & 255, tg = (target >> 16) & 255, tb = (target >> 8) & 255, ta = target & 255;
    bool same(int i) {
      final o = i * 4;
      final a = boundary[o + 3];
      // Treat transparent and white as equivalent "paper".
      final dr = (boundary[o] - tr).abs(), dg = (boundary[o + 1] - tg).abs(), db = (boundary[o + 2] - tb).abs(), da = (a - ta).abs();
      if (ta < 16 && a < 16) return true;
      return dr <= tolerance && dg <= tolerance && db <= tolerance && da <= tolerance;
    }

    final stack = <int>[seed];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      if (mask[i] != 0 || !same(i)) continue;
      final y = i ~/ w;
      var x = i % w;
      var lx = x;
      while (lx > 0 && mask[y * w + lx - 1] == 0 && same(y * w + lx - 1)) {
        lx--;
      }
      var rx = x;
      while (rx < w - 1 && mask[y * w + rx + 1] == 0 && same(y * w + rx + 1)) {
        rx++;
      }
      for (x = lx; x <= rx; x++) {
        mask[y * w + x] = 1;
        if (y > 0) {
          final up = (y - 1) * w + x;
          if (mask[up] == 0) stack.add(up);
        }
        if (y < h - 1) {
          final dn = (y + 1) * w + x;
          if (mask[dn] == 0) stack.add(dn);
        }
      }
    }
    // Grow by one pixel so fills tuck under anti-aliased outlines.
    final grown = Uint8List.fromList(mask);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0 && (mask[i - 1] | mask[i + 1] | mask[i - w] | mask[i + w]) != 0) grown[i] = 1;
      }
    }
    final r = (color >> 16) & 255, g = (color >> 8) & 255, b = color & 255, a = (color >> 24) & 255;
    final out = Uint8List(n * 4);
    for (var i = 0; i < n; i++) {
      if (grown[i] != 0) {
        out[i * 4] = r;
        out[i * 4 + 1] = g;
        out[i * 4 + 2] = b;
        out[i * 4 + 3] = a;
      }
    }
    return out;
  });
}

Future<ui.Image> imageFromRgba(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// Exposed for unit tests only.
Float32List gaussianForTest(Float32List src, int w, int h, double sigma) => _gaussian(src, w, h, sigma);
List<int> boxesForTest(double sigma) => _boxesForGauss(sigma, 3);
