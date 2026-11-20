import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

enum Tool { pencil, pen, brush, eraser, fill }

enum LayerKind { paint, outline, reference }

/// One committed drawing operation on a layer.
sealed class DrawOp {}

class StrokeOp extends DrawOp {
  StrokeOp({required this.tool, required this.color, required this.size, required this.opacity});
  final Tool tool;
  final Color color;
  final double size;
  final double opacity;
  final List<Offset> points = [];
  final List<double> widths = []; // per-point width factor (brush)
  Rect bounds = Rect.zero;

  void add(Offset p, double w) {
    points.add(p);
    widths.add(w);
    final r = Rect.fromCircle(center: p, radius: size * 1.5 + 2);
    bounds = points.length == 1 ? r : bounds.expandToInclude(r);
  }
}

class FillOp extends DrawOp {
  FillOp(this.image);
  final ui.Image image;
}

class ClearOp extends DrawOp {}

class CanvasLayer {
  CanvasLayer({required this.id, required this.name, this.kind = LayerKind.paint, this.opacity = 1, this.visible = true, this.base, this.exportable = true});

  final String id;
  String name;
  final LayerKind kind;
  double opacity;
  bool visible;
  bool exportable;

  /// Flattened content that can no longer be undone.
  ui.Image? base;
  final List<DrawOp> ops = [];

  /// Rendered [base] + [ops]; rebuilt after every change.
  ui.Image? cache;
  bool dirty = false; // needs saving

  bool get editable => kind == LayerKind.paint;
}

class HistoryEntry {
  HistoryEntry(this.layer, this.op);
  final CanvasLayer layer;
  final DrawOp op;
}

/// Paints a stroke. Used for both live and committed rendering.
void paintStroke(Canvas canvas, StrokeOp s) {
  if (s.points.isEmpty) return;
  final eraser = s.tool == Tool.eraser;
  final color = eraser ? const Color(0xFF000000) : s.color;
  switch (s.tool) {
    case Tool.pen:
    case Tool.eraser:
    case Tool.pencil:
      final pencil = s.tool == Tool.pencil;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = pencil ? max(1, s.size * 0.55) : s.size
        ..color = color.withValues(alpha: eraser ? 1 : s.opacity * (pencil ? 0.85 : 1))
        ..isAntiAlias = true;
      if (eraser) paint.blendMode = BlendMode.clear;
      if (pencil) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      if (s.points.length == 1) {
        final p = s.points.first;
        canvas.drawCircle(p, paint.strokeWidth / 2, Paint()
          ..color = paint.color
          ..blendMode = paint.blendMode);
        return;
      }
      canvas.drawPath(smoothPath(s.points), paint);
    case Tool.brush:
      // Variable-width soft brush, composited as one layer so overlaps don't darken.
      canvas.saveLayer(_brushLayerBounds(s), _brushLayerPaint(s));
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.size * s.widths.first / 2, Paint()..color = color);
      }
      _brushSegments(canvas, s, 1, s.points.length);
      canvas.restore();
    case Tool.fill:
      break;
  }
}

Rect _brushLayerBounds(StrokeOp s) => s.bounds.inflate(s.size);

Paint _brushLayerPaint(StrokeOp s) => Paint()..color = Color.fromRGBO(0, 0, 0, s.opacity);

/// Draws brush segments [from, to): segment i joins points[i-1] and points[i].
void _brushSegments(Canvas canvas, StrokeOp s, int from, int to) {
  final paint = Paint()
    ..color = s.color
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(0.5, s.size * 0.12));
  for (var i = max(1, from); i < to; i++) {
    paint.strokeWidth = s.size * (s.widths[i] + s.widths[i - 1]) / 2;
    canvas.drawLine(s.points[i - 1], s.points[i], paint);
  }
}

/// Rasterised prefix of the live brush stroke.
///
/// Redrawing every blurred segment each frame made a brush stroke cost
/// O(n) per frame (O(n²) overall). Instead, finished segments are baked into
/// [image] in batches and each frame draws that image plus the newest
/// segments. Inside the stroke's own layer this is the same source-over
/// sequence as drawing every segment, so at document resolution the preview
/// matches [paintStroke] exactly; committing still uses [paintStroke].
class LiveBrushCache {
  ui.Image? image;
  Offset origin = Offset.zero; // document position of image's top-left pixel
  int baked = 0; // segments 1..baked are in [image]

  /// How many new segments trigger a re-bake.
  static const batch = 4;

  void reset() {
    image?.dispose();
    image = null;
    origin = Offset.zero;
    baked = 0;
  }
}

/// Bakes pending segments of a live brush stroke once a batch is ready.
void bakeLiveBrush(StrokeOp s, LiveBrushCache c, Size doc) {
  final segments = s.points.length - 1;
  if (s.tool != Tool.brush || segments - c.baked < LiveBrushCache.batch) return;
  final r = _brushLayerBounds(s).intersect(Offset.zero & doc);
  if (r.isEmpty) return;
  // Whole pixels so the cached image lands 1:1 on the layer's pixel grid.
  final rect = Rect.fromLTRB(r.left.floorToDouble(), r.top.floorToDouble(), r.right.ceilToDouble(), r.bottom.ceilToDouble());
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.translate(-rect.left, -rect.top);
  if (c.image != null) canvas.drawImage(c.image!, c.origin, Paint());
  _brushSegments(canvas, s, c.baked + 1, segments + 1);
  final img = rec.endRecording().toImageSync(rect.width.round(), rect.height.round());
  c.image?.dispose();
  c.image = img;
  c.origin = rect.topLeft;
  c.baked = segments;
}

/// Paints the live (in-progress) stroke, using [cache] for brush strokes.
void paintLiveStroke(Canvas canvas, StrokeOp s, LiveBrushCache? cache) {
  if (s.tool != Tool.brush || cache?.image == null) {
    paintStroke(canvas, s);
    return;
  }
  canvas.saveLayer(_brushLayerBounds(s), _brushLayerPaint(s));
  canvas.drawImage(cache!.image!, cache.origin, Paint());
  _brushSegments(canvas, s, cache.baked + 1, s.points.length);
  canvas.restore();
}

/// Quadratic smoothing through the midpoints of consecutive samples.
Path smoothPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) {
    path.lineTo(pts[1].dx, pts[1].dy);
    return path;
  }
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

void paintOp(Canvas canvas, DrawOp op, Size doc) {
  switch (op) {
    case StrokeOp s:
      paintStroke(canvas, s);
    case FillOp f:
      canvas.drawImage(f.image, Offset.zero, Paint());
    case ClearOp _:
      canvas.drawRect(Offset.zero & doc, Paint()..blendMode = BlendMode.clear);
  }
}

/// Re-renders a layer's cache from its base and ops.
Future<void> rebuildLayer(CanvasLayer l, Size doc) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & doc);
  if (l.base != null) c.drawImage(l.base!, Offset.zero, Paint());
  for (final op in l.ops) {
    paintOp(c, op, doc);
  }
  final img = await rec.endRecording().toImage(doc.width.round(), doc.height.round());
  l.cache?.dispose();
  l.cache = img;
}

/// Adds one op to the existing cache (fast path, no replay).
Future<void> appendToLayer(CanvasLayer l, DrawOp op, Size doc) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & doc);
  if (l.cache != null) {
    c.drawImage(l.cache!, Offset.zero, Paint());
  } else if (l.base != null) {
    c.drawImage(l.base!, Offset.zero, Paint());
  }
  paintOp(c, op, doc);
  final img = await rec.endRecording().toImage(doc.width.round(), doc.height.round());
  l.cache?.dispose();
  l.cache = img;
}

/// Composites layers for export or thumbnails.
Future<ui.Image> composite(List<CanvasLayer> layers, Size doc, {bool whitePaper = true, bool forExport = true, double scale = 1}) async {
  final w = max(1, (doc.width * scale).round()), h = max(1, (doc.height * scale).round());
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(scale);
  if (whitePaper) c.drawRect(Offset.zero & doc, Paint()..color = Colors.white);
  for (final l in layers) {
    if (!l.visible) continue;
    if (forExport && !l.exportable) continue;
    final img = l.cache ?? l.base;
    if (img == null) continue;
    c.drawImage(img, Offset.zero, Paint()
      ..color = Color.fromRGBO(0, 0, 0, l.opacity)
      ..filterQuality = FilterQuality.medium);
  }
  return rec.endRecording().toImage(w, h);
}
