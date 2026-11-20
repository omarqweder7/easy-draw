import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/l10n.dart';
import '../../app/scope.dart';
import '../../design/design.dart';

String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// HSV colour picker with saved swatches. Returns the chosen colour.
Future<Color?> showColorPicker(BuildContext context, Color initial) {
  return showEDSheet<Color>(context, title: context.tr('color.title', 'Choose a color'), builder: (c) => _ColorPickerBody(initial: initial));
}

class _ColorPickerBody extends StatefulWidget {
  const _ColorPickerBody({required this.initial});
  final Color initial;

  @override
  State<_ColorPickerBody> createState() => _ColorPickerBodyState();
}

class _ColorPickerBodyState extends State<_ColorPickerBody> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hex = TextEditingController(text: hexOf(widget.initial));

  Color get _color => _hsv.toColor();

  void _set(HSVColor h) => setState(() {
        _hsv = h;
        _hex.text = hexOf(_color);
      });

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final p = context.ds;
    final t = context.text;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 180,
        child: LayoutBuilder(builder: (context, c) {
          void pick(Offset o) => _set(_hsv.withSaturation((o.dx / c.maxWidth).clamp(0, 1)).withValue(1 - (o.dy / c.maxHeight).clamp(0, 1)));
          return Semantics(
            label: context.tr('color.sv', 'Saturation and brightness'),
            value: '${(_hsv.saturation * 100).round()}%, ${(_hsv.value * 100).round()}%',
            child: GestureDetector(
              onPanDown: (d) => pick(d.localPosition),
              onPanUpdate: (d) => pick(d.localPosition),
              child: ClipRRect(
                borderRadius: Radii.cardR,
                child: Stack(children: [
                  Positioned.fill(child: ColoredBox(color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor())),
                  const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, Color(0x00FFFFFF)])))),
                  const Positioned.fill(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Colors.black]))),
                  ),
                  Positioned(
                    left: _hsv.saturation * c.maxWidth - 12,
                    top: (1 - _hsv.value) * c.maxHeight - 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(blurRadius: 4)]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: Space.m),
      Text(context.tr('color.hue', 'Hue').toUpperCase(), style: t.overline),
      const SizedBox(height: Space.xs),
      _HueTrack(hue: _hsv.hue, onChanged: (h) => _set(_hsv.withHue(h))),
      const SizedBox(height: Space.m),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: _color, borderRadius: Radii.cardR, border: Border.all(color: p.borderStrong)),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: EDTextField(
            controller: _hex,
            label: context.tr('color.hex', 'Hex code'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')), LengthLimitingTextInputFormatter(7)],
            onSubmitted: (v) {
              final s = v.replaceAll('#', '');
              if (s.length == 6) {
                final n = int.tryParse(s, radix: 16);
                if (n != null) _set(HSVColor.fromColor(Color(0xFF000000 | n)));
              }
            },
          ),
        ),
      ]),
      const SizedBox(height: Space.l),
      Row(children: [
        Expanded(child: Text(context.tr('color.saved', 'Saved colors').toUpperCase(), style: t.overline)),
        EDButton.ghost(
          compact: true,
          icon: Icons.add_rounded,
          label: context.tr('color.save', 'Save color'),
          onPressed: () {
            final v = _color.toARGB32();
            if (!settings.swatches.contains(v)) {
              settings.update((s) => s.swatches = [v, ...s.swatches].take(24).toList());
              setState(() {});
            }
          },
        ),
      ]),
      Text(context.tr('color.removeHint', 'Long-press a saved color to remove it.'), style: t.caption),
      const SizedBox(height: Space.xs),
      Wrap(spacing: Space.xxs, runSpacing: Space.xxs, children: [
        for (final v in settings.swatches)
          Pressable(
            onTap: () => _set(HSVColor.fromColor(Color(v))),
            onLongPress: () {
              settings.update((s) => s.swatches = [...s.swatches]..remove(v));
              setState(() {});
            },
            semanticLabel: hexOf(Color(v)),
            semanticHint: context.tr('color.removeHint', 'Long-press a saved color to remove it.'),
            excludeChildSemantics: true,
            borderRadius: Radii.controlR,
            builder: (context, s) => SizedBox(
              width: Sizes.touch,
              height: Sizes.touch,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Color(v), borderRadius: Radii.controlR, border: Border.all(color: p.border)),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: Space.l),
      EDButton(expand: true, icon: Icons.check_rounded, label: context.tr('color.use', 'Use this color'), onPressed: () => Navigator.pop(context, _color)),
    ]);
  }
}

/// Rainbow hue track with an angular thumb.
class _HueTrack extends StatelessWidget {
  const _HueTrack({required this.hue, required this.onChanged});
  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: context.tr('color.hue', 'Hue'),
      value: '${hue.round()}°',
      onIncrease: () => onChanged((hue + 10).clamp(0, 360)),
      onDecrease: () => onChanged((hue - 10).clamp(0, 360)),
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, c) {
        const thumb = 20.0;
        final usable = c.maxWidth - thumb;
        void set(double dx) => onChanged(((dx - thumb / 2) / usable * 360).clamp(0, 360));
        return GestureDetector(
          onTapDown: (d) => set(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
          child: SizedBox(
            height: Sizes.touch,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Positioned(
                left: thumb / 2,
                right: thumb / 2,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()]),
                  ),
                ),
              ),
              Positioned(
                left: hue / 360 * usable,
                child: Container(
                  width: thumb,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
