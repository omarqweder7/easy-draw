import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../services/image_ops.dart';
import '../widgets/common.dart';
import 'nav.dart';

enum _View { sketch, original, compare }

/// Converts a photo into outline, pencil or black-and-white line art,
/// entirely on the device.
class SketchScreen extends StatefulWidget {
  const SketchScreen({super.key, required this.sourcePath, required this.title});
  final String sourcePath;
  final String title;

  @override
  State<SketchScreen> createState() => _SketchScreenState();
}

class _SketchScreenState extends State<SketchScreen> {
  SketchParams _p = const SketchParams();
  GrayImage? _gray;
  ui.Image? _preview;
  bool _rendering = false;
  bool _pending = false;
  bool _error = false;
  _View _view = _View.sketch;
  double _split = 0.5;
  double? _progress;
  final _debounce = Debouncer(const Duration(milliseconds: 90));

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_error) setState(() => _error = false);
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final g = await loadGray(bytes, maxSide: 720);
      if (!mounted) return;
      _gray = g;
      await _render();
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _render() async {
    final g = _gray;
    if (g == null) return;
    if (_rendering) {
      _pending = true;
      return;
    }
    setState(() => _rendering = true);
    try {
      final rgba = await sketchRgba(g, _p);
      final img = await imageFromRgba(rgba, g.width, g.height);
      if (!mounted) return;
      setState(() {
        _preview?.dispose();
        _preview = img;
      });
    } finally {
      if (mounted) setState(() => _rendering = false);
      if (_pending) {
        _pending = false;
        _render();
      }
    }
  }

  void _update(SketchParams p) {
    setState(() => _p = p);
    _debounce(_render);
  }

  Future<void> _save() async {
    setState(() => _progress = 0);
    final art = context.art;
    final title = context.trf('sketch.name', '{name} · sketch', {'name': widget.title});
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final png = await sketchToPng(bytes, _p, maxSide: 2048, onProgress: (v) {
        if (mounted) setState(() => _progress = v);
      });
      final item = await art.addImage(png, type: ArtType.sketch, title: title, meta: {'effect': _p.effect.name});
      if (!mounted) return;
      setState(() => _progress = null);
      final src = art.sourceFor('art:${item.id}');
      if (src != null) await showUseSheet(context, src);
    } catch (e) {
      if (mounted) {
        setState(() => _progress = null);
        showSnack(storageMessage(context, e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('tool.sketch', 'Photo to Sketch'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.xs),
            child: EDButton(compact: true, icon: Icons.check_rounded, label: context.tr('common.save', 'Save'), onPressed: _preview == null || _progress != null ? null : _save),
          ),
        ],
      ),
      body: Stack(children: [
        SafeArea(
          top: false,
          child: _error
              ? EDStateView(
                  icon: Icons.broken_image_outlined,
                  tone: EDStateTone.error,
                  title: context.tr('sketch.loadFail', 'This photo couldn’t be opened.'),
                  message: context.tr('sketch.loadFailBody', 'It may be damaged or in an unsupported format.'),
                  actionLabel: context.tr('common.tryAgain', 'Try again'),
                  onAction: _init,
                )
              : landscape
                  ? Row(children: [Expanded(child: _previewArea()), SizedBox(width: 380, child: SingleChildScrollView(child: _controls()))])
                  : LayoutBuilder(
                      builder: (context, c) => Column(children: [
                        SizedBox(height: c.maxHeight * 0.48, child: _previewArea()),
                        Expanded(child: SingleChildScrollView(child: _controls())),
                      ]),
                    ),
        ),
        if (_progress != null) BusyOverlay(message: context.tr('sketch.processing', 'Creating full-quality sketch…'), progress: _progress),
      ]),
    );
  }

  Widget _previewArea() {
    final p = context.ds;
    // The original is never shown wider than the screen; decode it at that size.
    final screenPx = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    final original = Image.file(File(widget.sourcePath), fit: BoxFit.contain, cacheWidth: screenPx, semanticLabel: context.tr('sketch.original', 'Original'));
    final sketch = _preview == null ? const EDLoading() : RawImage(image: _preview, fit: BoxFit.contain);
    Widget content;
    switch (_view) {
      case _View.original:
        content = original;
      case _View.sketch:
        content = Semantics(label: context.tr('sketch.preview', 'Sketch preview'), child: sketch);
      case _View.compare:
        content = LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => _split = (_split + d.delta.dx / c.maxWidth).clamp(0.0, 1.0)),
            child: Stack(fit: StackFit.expand, children: [
              sketch,
              ClipRect(clipper: _LeftClipper(_split), child: original),
              Positioned(
                left: c.maxWidth * _split - 22,
                top: 0,
                bottom: 0,
                child: Semantics(
                  slider: true,
                  value: '${(_split * 100).round()}%',
                  label: context.tr('sketch.compareHandle', 'Before and after divider'),
                  onIncrease: () => setState(() => _split = (_split + 0.1).clamp(0, 1)),
                  onDecrease: () => setState(() => _split = (_split - 0.1).clamp(0, 1)),
                  child: SizedBox(
                    width: 44,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(width: 3, color: EDPalette.dark.accent),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: EDPalette.dark.accent, borderRadius: Radii.controlR),
                        child: Icon(Icons.compare_arrows_rounded, color: EDPalette.dark.onAccent),
                      ),
                    ]),
                  ),
                ),
              ),
              // Physical sides: the original is always revealed from the left.
              Positioned(top: Space.xs, left: Space.xs, child: _tag(context.tr('sketch.before', 'Before'))),
              Positioned(top: Space.xs, right: Space.xs, child: _tag(context.tr('sketch.after', 'After'))),
            ]),
          );
        });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.xs),
      child: Column(children: [
        Expanded(
          child: EDCard(
            child: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _Checker(p.paper)),
              content,
              if (_rendering)
                PositionedDirectional(
                  top: Space.xs,
                  end: Space.xs,
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accentText)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: Space.xs),
        EDSegmented<_View>(
          segments: [
            EDSegment(_View.sketch, context.tr('sketch.sketch', 'Sketch'), icon: Icons.draw_outlined),
            EDSegment(_View.original, context.tr('sketch.original', 'Original'), icon: Icons.image_outlined),
            EDSegment(_View.compare, context.tr('sketch.compare', 'Compare'), icon: Icons.compare_outlined),
          ],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
      ]),
    );
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 3),
        decoration: BoxDecoration(color: EDPalette.dark.bg.withValues(alpha: 0.85), borderRadius: Radii.tagR),
        child: Text(s, style: context.text.caption.copyWith(color: EDPalette.dark.text, fontWeight: FontWeight.w700)),
      );

  Widget _controls() {
    final t = context.text;
    final p = context.ds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('sketch.effect', 'Effect').toUpperCase(), style: t.overline),
        const SizedBox(height: Space.xs),
        EDSegmented<SketchEffect>(
          segments: [
            EDSegment(SketchEffect.outline, context.tr('sketch.outline', 'Outline')),
            EDSegment(SketchEffect.pencil, context.tr('sketch.pencil', 'Pencil')),
            EDSegment(SketchEffect.blackWhite, context.tr('sketch.bw', 'Black & white')),
          ],
          value: _p.effect,
          onChanged: (v) => _update(_p.copyWith(effect: v)),
        ),
        const SizedBox(height: Space.s),
        EDSlider(label: context.tr('sketch.edge', 'Edges'), value: _p.edge, min: 0, max: 1, valueText: '${(_p.edge * 100).round()}', onChanged: (v) => _update(_p.copyWith(edge: v))),
        EDSlider(label: context.tr('sketch.detail', 'Detail'), value: _p.detail, min: 0, max: 1, valueText: '${(_p.detail * 100).round()}', onChanged: (v) => _update(_p.copyWith(detail: v))),
        EDSlider(label: context.tr('sketch.contrast', 'Contrast'), value: _p.contrast, min: -1, max: 1, valueText: '${(_p.contrast * 100).round()}', onChanged: (v) => _update(_p.copyWith(contrast: v))),
        EDSlider(label: context.tr('sketch.brightness', 'Brightness'), value: _p.brightness, min: -1, max: 1, valueText: '${(_p.brightness * 100).round()}', onChanged: (v) => _update(_p.copyWith(brightness: v))),
        const SizedBox(height: Space.s),
        EDGroup(children: [
          EDSwitchRow(
            icon: Icons.layers_clear_outlined,
            value: _p.transparentBackground,
            onChanged: (v) => _update(_p.copyWith(transparentBackground: v)),
            title: context.tr('sketch.removeWhite', 'Remove white background'),
            subtitle: context.tr('sketch.removeWhiteHint', 'Keeps only the lines — ideal over the camera view. (Removes light areas, not a smart cut-out.)'),
          ),
        ]),
        const SizedBox(height: Space.s),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: p.textMuted),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(context.tr('sketch.local', 'Processed on your device. Your photo is never uploaded.'), style: t.caption)),
        ]),
      ]),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.f);
  final double f;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);
  @override
  bool shouldReclip(_LeftClipper old) => old.f != f;
}

/// Checkerboard showing transparency.
class _Checker extends CustomPainter {
  _Checker(this.paper);
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final p = Paint()..color = const Color(0xFFE2E7E4);
    const s = 14.0;
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = ((y / s).floor().isEven ? 0.0 : s); x < size.width; x += s * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => old.paper != paper;
}
