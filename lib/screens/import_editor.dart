import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../services/image_ops.dart';
import '../widgets/common.dart';

/// Crop, rotate and flip an imported photo, then save it to My Art.
/// Pops with the saved [ArtItem].
class ImportEditorScreen extends StatefulWidget {
  const ImportEditorScreen({super.key, required this.path, this.nextLabel});
  final String path;
  final String? nextLabel;

  @override
  State<ImportEditorScreen> createState() => _ImportEditorScreenState();
}

class _ImportEditorScreenState extends State<ImportEditorScreen> {
  int _turns = 0;
  bool _flipH = false;
  bool _flipV = false;
  Rect _crop = const Rect.fromLTRB(0, 0, 1, 1); // normalised, in displayed space
  Size? _imageSize; // as decoded (EXIF applied)
  bool _saving = false;
  bool _failed = false;
  late final FileImage _provider = FileImage(File(widget.path));

  @override
  void initState() {
    super.initState();
    final stream = _provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }, onError: (_, _) {
      if (mounted) setState(() => _failed = true);
    }));
  }

  void _rotate(int d) => setState(() {
        _turns = (_turns + d) % 4;
        _crop = const Rect.fromLTRB(0, 0, 1, 1);
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    final art = context.art;
    final title = context.trf('import.name', 'Photo {date}', {'date': _date()});
    try {
      final r = await processImport(
        widget.path,
        ImportEdits(
          quarterTurns: _turns,
          flipH: _flipH,
          flipV: _flipV,
          crop: _crop == const Rect.fromLTRB(0, 0, 1, 1) ? null : [_crop.left, _crop.top, _crop.right, _crop.bottom],
        ),
      );
      final isPng = r.bytes.length > 8 && r.bytes[0] == 0x89 && r.bytes[1] == 0x50;
      final item = await art.addImage(r.bytes, type: ArtType.imported, title: title, ext: isPng ? 'png' : 'jpg');
      if (mounted) Navigator.pop(context, item);
    } on FormatException {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context.tr('import.unsupported', 'This image format isn’t supported. Try a JPEG or PNG photo.'), error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(storageMessage(context, e), error: true);
      }
    }
  }

  String _date() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const g = EDPalette.dark;
    return Theme(
      data: Theme.of(context).copyWith(extensions: [g, EDText.build(g, context.lang)]),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: g.bg,
          appBar: EDTopBar(
            title: context.tr('import.edit', 'Adjust photo'),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.xs),
                child: EDButton(
                  compact: true,
                  dark: true,
                  icon: Icons.check_rounded,
                  label: widget.nextLabel ?? context.tr('common.save', 'Save'),
                  loading: _saving,
                  onPressed: _imageSize == null ? null : _save,
                ),
              ),
            ],
          ),
          body: Stack(children: [
            Column(children: [
              Expanded(
                child: _failed
                    ? EDStateView(
                        dark: true,
                        tone: EDStateTone.error,
                        icon: Icons.broken_image_outlined,
                        title: context.tr('import.unsupportedTitle', 'Can’t open this image'),
                        message: context.tr('import.unsupported', 'This image format isn’t supported. Try a JPEG or PNG photo.'),
                        actionLabel: context.tr('common.back', 'Go back'),
                        onAction: () => Navigator.pop(context),
                      )
                    : _imageSize == null
                        ? EDLoading(dark: true, message: context.tr('import.loading', 'Opening photo…'))
                        // Inset keeps crop handles clear of system edge-swipe gestures.
                        : Padding(padding: const EdgeInsets.symmetric(horizontal: 44, vertical: Space.l), child: _editor()),
              ),
              Container(
                decoration: BoxDecoration(color: g.surface, border: Border(top: BorderSide(color: g.border))),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xs),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        EDToolButton(icon: Icons.rotate_left_rounded, label: context.tr('import.rotL', 'Rotate left'), onPressed: () => _rotate(3)),
                        EDToolButton(icon: Icons.rotate_right_rounded, label: context.tr('import.rotR', 'Rotate right'), onPressed: () => _rotate(1)),
                        EDToolButton(icon: Icons.flip_rounded, label: context.tr('ov.flipH', 'Flip ↔'), toggle: true, active: _flipH, onPressed: () => setState(() => _flipH = !_flipH)),
                        EDToolButton(icon: Icons.swap_vert_rounded, label: context.tr('ov.flipV', 'Flip ↕'), toggle: true, active: _flipV, onPressed: () => setState(() => _flipV = !_flipV)),
                        EDToolButton(icon: Icons.crop_free_rounded, label: context.tr('import.resetCrop', 'Reset crop'), onPressed: () => setState(() => _crop = const Rect.fromLTRB(0, 0, 1, 1))),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
            if (_saving) BusyOverlay(message: context.tr('import.saving', 'Preparing photo…')),
          ]),
        );
      }),
    );
  }

  Widget _editor() {
    final odd = _turns.isOdd;
    final iw = odd ? _imageSize!.height : _imageSize!.width;
    final ih = odd ? _imageSize!.width : _imageSize!.height;
    return LayoutBuilder(builder: (context, c) {
      final s = min(c.maxWidth / iw, c.maxHeight / ih);
      final w = iw * s, h = ih * s;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(_flipH ? -1 : 1, _flipV ? -1 : 1, 1),
                child: RotatedBox(quarterTurns: _turns, child: Image(image: _provider, fit: BoxFit.fill, semanticLabel: context.tr('import.photo', 'Your photo'))),
              ),
            ),
            Positioned.fill(child: _CropOverlay(rect: _crop, onChanged: (r) => setState(() => _crop = r))),
          ]),
        ),
      );
    });
  }
}

class _CropOverlay extends StatefulWidget {
  const _CropOverlay({required this.rect, required this.onChanged});
  final Rect rect;
  final ValueChanged<Rect> onChanged;

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

enum _Handle { tl, tr, bl, br, move }

class _CropOverlayState extends State<_CropOverlay> {
  _Handle? _active;
  static const minSize = 0.08;

  _Handle _hit(Offset p, Size s) {
    final r = widget.rect;
    final corners = {
      _Handle.tl: Offset(r.left * s.width, r.top * s.height),
      _Handle.tr: Offset(r.right * s.width, r.top * s.height),
      _Handle.bl: Offset(r.left * s.width, r.bottom * s.height),
      _Handle.br: Offset(r.right * s.width, r.bottom * s.height),
    };
    for (final e in corners.entries) {
      if ((e.value - p).distance < 36) return e.key;
    }
    return _Handle.move;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return Semantics(
        label: context.tr('import.cropHint', 'Crop area. Drag the corners to crop, or drag inside to move.'),
        child: GestureDetector(
          onPanStart: (d) => _active = _hit(d.localPosition, size),
          onPanEnd: (_) => _active = null,
          onPanUpdate: (d) {
            final dx = d.delta.dx / size.width, dy = d.delta.dy / size.height;
            var r = widget.rect;
            switch (_active ?? _Handle.move) {
              case _Handle.move:
                final nx = (r.left + dx).clamp(0.0, 1 - r.width);
                final ny = (r.top + dy).clamp(0.0, 1 - r.height);
                r = Rect.fromLTWH(nx, ny, r.width, r.height);
              case _Handle.tl:
                r = Rect.fromLTRB((r.left + dx).clamp(0.0, r.right - minSize), (r.top + dy).clamp(0.0, r.bottom - minSize), r.right, r.bottom);
              case _Handle.tr:
                r = Rect.fromLTRB(r.left, (r.top + dy).clamp(0.0, r.bottom - minSize), (r.right + dx).clamp(r.left + minSize, 1.0), r.bottom);
              case _Handle.bl:
                r = Rect.fromLTRB((r.left + dx).clamp(0.0, r.right - minSize), r.top, r.right, (r.bottom + dy).clamp(r.top + minSize, 1.0));
              case _Handle.br:
                r = Rect.fromLTRB(r.left, r.top, (r.right + dx).clamp(r.left + minSize, 1.0), (r.bottom + dy).clamp(r.top + minSize, 1.0));
            }
            widget.onChanged(r);
          },
          child: CustomPaint(painter: _CropPainter(widget.rect), size: size),
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.r);
  final Rect r;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Rect.fromLTRB(r.left * s.width, r.top * s.height, r.right * s.width, r.bottom * s.height);
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & s), Path()..addRect(rect)), shade);
    canvas.drawRect(rect, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final third = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3, y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), third);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), third);
    }
    // Viewfinder-style L handles in lime.
    final h = Paint()
      ..color = const Color(0xFFBAFF32)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const l = 22.0;
    for (final (c, sx, sy) in [(rect.topLeft, 1.0, 1.0), (rect.topRight, -1.0, 1.0), (rect.bottomLeft, 1.0, -1.0), (rect.bottomRight, -1.0, -1.0)]) {
      canvas.drawPath(Path()
        ..moveTo(c.dx, c.dy + l * sy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + l * sx, c.dy), h);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.r != r;
}
