import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../design/design.dart';
import 'overlay.dart';

/// Opacity, size and rotation sliders for a reference overlay (workspace
/// panels are always graphite).
class OverlaySliders extends StatelessWidget {
  const OverlaySliders({super.key, required this.model});
  final OverlayModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final geo = !model.locked;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          EDSlider(
            dark: true,
            dense: true,
            icon: Icons.opacity_rounded,
            label: context.tr('ov.opacity', 'Opacity'),
            value: model.opacity,
            min: 0,
            max: 1,
            valueText: pct(model.opacity),
            onChanged: (v) => model.opacity = v,
          ),
          EDSlider(
            dark: true,
            dense: true,
            enabled: geo,
            icon: Icons.open_in_full_rounded,
            label: context.tr('ov.size', 'Size'),
            value: model.scale,
            min: OverlayModel.minScale,
            max: OverlayModel.maxScale,
            step: 0.05,
            valueText: pct(model.scale),
            onChanged: (v) => model.scale = v,
          ),
          EDSlider(
            dark: true,
            dense: true,
            enabled: geo,
            icon: Icons.rotate_right_rounded,
            label: context.tr('ov.rotate', 'Rotate'),
            value: model.rotation,
            min: -pi,
            max: pi,
            step: pi / 36,
            valueText: deg(model.rotation),
            onChanged: (v) {
              // Snap to 0/±90/180 when close, to make straight alignment easy.
              const snap = 0.035;
              for (final t in [0.0, pi / 2, -pi / 2, pi, -pi]) {
                if ((v - t).abs() < snap) v = t;
              }
              model.rotation = v;
            },
          ),
          if (model.locked)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs, bottom: Space.xxs),
              child: Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFA7B2AC)),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(context.tr('ov.lockedNote', 'Locked: position, size and rotation are frozen. Opacity still works.'),
                      style: context.text.caption.copyWith(color: EDPalette.dark.textMuted)),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

/// Flip / lines-only / reset tool buttons.
class OverlayToolRow extends StatelessWidget {
  const OverlayToolRow({super.key, required this.model, this.extra = const []});
  final OverlayModel model;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          EDToolButton(icon: Icons.flip_rounded, label: context.tr('ov.flipH', 'Flip ↔'), toggle: true, active: model.flipX, onPressed: model.locked ? null : model.toggleFlipX),
          EDToolButton(icon: Icons.swap_vert_rounded, label: context.tr('ov.flipV', 'Flip ↕'), toggle: true, active: model.flipY, onPressed: model.locked ? null : model.toggleFlipY),
          EDToolButton(
            icon: Icons.format_color_reset_outlined,
            label: context.tr('ov.linesOnly', 'Lines only'),
            toggle: true,
            active: model.linesOnly,
            onPressed: () => model.linesOnly = !model.linesOnly,
          ),
          EDToolButton(icon: Icons.restart_alt_rounded, label: context.tr('ov.reset', 'Reset'), onPressed: model.locked ? null : model.reset),
          ...extra,
        ]),
      ),
    );
  }
}
