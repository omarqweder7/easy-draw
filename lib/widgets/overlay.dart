import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../services/ref_loader.dart';

/// Position, size, rotation, mirroring and opacity of a reference overlay.
///
/// Values are relative to the screen-space viewport. Locking freezes them
/// relative to the screen — it does NOT track the paper.
class OverlayModel extends ChangeNotifier {
  OverlayModel({double opacity = 0.5, bool linesOnly = true})
      : _opacity = opacity,
        _defaultOpacity = opacity,
        // ignore: prefer_initializing_formals
        _linesOnly = linesOnly;

  Offset _offset = Offset.zero;
  double _scale = 1;
  double _rotation = 0; // radians
  bool _flipX = false;
  bool _flipY = false;
  double _opacity;
  final double _defaultOpacity;
  bool _locked = false;
  bool _visible = true;
  bool _linesOnly;

  Offset get offset => _offset;
  double get scale => _scale;
  double get rotation => _rotation;
  bool get flipX => _flipX;
  bool get flipY => _flipY;
  double get opacity => _opacity;
  bool get locked => _locked;
  bool get visible => _visible;
  bool get linesOnly => _linesOnly;

  static const minScale = 0.1;
  static const maxScale = 5.0;

  set offset(Offset v) => _set(() => _offset = v);
  set scale(double v) => _set(() => _scale = v.clamp(minScale, maxScale));
  set rotation(double v) => _set(() => _rotation = _normalize(v));
  set opacity(double v) => _set(() => _opacity = v.clamp(0, 1), force: true); // allowed while locked
  set locked(bool v) => _set(() => _locked = v, force: true);
  set visible(bool v) => _set(() => _visible = v, force: true);
  set linesOnly(bool v) => _set(() => _linesOnly = v, force: true);
  void toggleFlipX() => _set(() => _flipX = !_flipX);
  void toggleFlipY() => _set(() => _flipY = !_flipY);

  void _set(VoidCallback f, {bool force = false}) {
    if (_locked && !force) return; // locked: geometry is frozen
    f();
    notifyListeners();
  }

  static double _normalize(double r) {
    var x = r % (2 * pi);
    if (x > pi) x -= 2 * pi;
    if (x < -pi) x += 2 * pi;
    return x;
  }

  /// Restores the original alignment (keeps opacity and lock state).
  void reset() => _set(() {
        _offset = Offset.zero;
        _scale = 1;
        _rotation = 0;
        _flipX = false;
        _flipY = false;
      });

  void resetAll() {
    _locked = false;
    reset();
    _opacity = _defaultOpacity;
    notifyListeners();
  }

  /// Size of the reference at scale 1: fitted inside 85% of the viewport.
  static Size baseSize(Size viewport, Size image) {
    final s = min(viewport.width * 0.85 / image.width, viewport.height * 0.85 / image.height);
    return Size(image.width * s, image.height * s);
  }

  Map<String, dynamic> toJson() => {
        'dx': _offset.dx, 'dy': _offset.dy, 'scale': _scale, 'rotation': _rotation,
        'flipX': _flipX, 'flipY': _flipY, 'opacity': _opacity,
      };
}

/// Paints [image] with [m]'s transform into a viewport of [viewport] size.
/// Used both on screen and when composing captured photos, so they match.
void paintOverlay(Canvas canvas, Size viewport, ui.Image image, OverlayModel m, {double? opacityOverride}) {
  final imgSize = Size(image.width.toDouble(), image.height.toDouble());
  final base = OverlayModel.baseSize(viewport, imgSize);
  canvas.save();
  canvas.translate(viewport.width / 2 + m.offset.dx, viewport.height / 2 + m.offset.dy);
  canvas.rotate(m.rotation);
  canvas.scale(m.scale * (m.flipX ? -1 : 1), m.scale * (m.flipY ? -1 : 1));
  final dst = Rect.fromCenter(center: Offset.zero, width: base.width, height: base.height);
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..color = Color.fromRGBO(0, 0, 0, opacityOverride ?? m.opacity);
  if (m.linesOnly) paint.colorFilter = linesOnlyFilter();
  canvas.drawImageRect(image, Rect.fromLTWH(0, 0, imgSize.width, imgSize.height), dst, paint);
  canvas.restore();
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.image, this.model) : super(repaint: model);
  final ui.Image image;
  final OverlayModel model;

  @override
  void paint(Canvas canvas, Size size) {
    if (!model.visible) return;
    paintOverlay(canvas, size, image, model);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.image != image || old.model != model;
}

/// Interactive reference layer: drag to move, pinch to resize, twist to
/// rotate. Gestures are ignored while the model is locked.
class ReferenceOverlay extends StatefulWidget {
  const ReferenceOverlay({super.key, required this.image, required this.model, this.semanticLabel});
  final ui.Image image;
  final OverlayModel model;
  final String? semanticLabel;

  @override
  State<ReferenceOverlay> createState() => _ReferenceOverlayState();
}

class _ReferenceOverlayState extends State<ReferenceOverlay> {
  double _startScale = 1;
  double _startRotation = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _startScale = m.scale;
          _startRotation = m.rotation;
        },
        onScaleUpdate: (d) {
          if (m.locked || !m.visible) return;
          m.offset = m.offset + d.focalPointDelta;
          if (d.pointerCount > 1) {
            m.scale = _startScale * d.scale;
            m.rotation = _startRotation + d.rotation;
          }
        },
        child: CustomPaint(painter: _OverlayPainter(widget.image, m), size: Size.infinite),
      ),
    );
  }
}

/// Optional alignment grid (rule-of-thirds plus finer divisions).
class GridPainter extends CustomPainter {
  GridPainter({this.color = Colors.white, this.divisions = 6});
  final Color color;
  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final cell = size.shortestSide / divisions;
    final cx = size.width / 2, cy = size.height / 2;
    for (var x = cx % cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thin);
    }
    for (var y = cy % cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thin);
    }
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), thick);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), thick);
  }

  @override
  bool shouldRepaint(GridPainter old) => old.color != color || old.divisions != divisions;
}

/// Overlay sliders shared by camera and trace workspaces.
String pct(double v) => '${(v * 100).round()}%';
String deg(double r) => '${(r * 180 / pi).round()}°';
