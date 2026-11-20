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
      final b = s.bounds.inflate(s.size);
      canvas.saveLayer(b, Paint()..color = Color.fromRGBO(0, 0, 0, s.opacity));
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(0.5, s.size * 0.12));
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.size * s.widths.first / 2, Paint()..color = color);
      }
      for (var i = 1; i < s.points.length; i++) {
        paint.strokeWidth = s.size * (s.widths[i] + s.widths[i - 1]) / 2;
        canvas.drawLine(s.points[i - 1], s.points[i], paint);
      }
      canvas.restore();
    case Tool.fill:
      break;
  }
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
