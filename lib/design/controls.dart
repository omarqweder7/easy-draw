import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'pressable.dart';
import 'tokens.dart';

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

enum EDButtonVariant { primary, secondary, ghost, danger }

/// The Easy Draw button. Primary = lime with dark text (use for the one main
/// action on a screen). Supports icon, loading, disabled and full width.
class EDButton extends StatelessWidget {
  const EDButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = EDButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.compact = false,
    this.dark = false,
  });

  const EDButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
    this.dark = false,
  }) : variant = EDButtonVariant.secondary;

  const EDButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
    this.dark = false,
  }) : variant = EDButtonVariant.ghost;

  const EDButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
    this.dark = false,
  }) : variant = EDButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EDButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;

  /// Force the graphite palette (for buttons on camera/workspace panels).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    final t = context.text;
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (variant) {
      EDButtonVariant.primary => (p.accent, p.onAccent, Colors.transparent),
      EDButtonVariant.secondary => (p.elevated, p.text, p.border),
      EDButtonVariant.ghost => (
        Colors.transparent,
        p.accentText,
        Colors.transparent,
      ),
      EDButtonVariant.danger => (
        Colors.transparent,
        p.danger,
        p.danger.withValues(alpha: 0.6),
      ),
    };
    final height = compact ? Sizes.touch : Sizes.buttonHeight;
    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: variant == EDButtonVariant.primary
          ? PressHaptic.press
          : PressHaptic.select,
      semanticLabel: label,
      excludeChildSemantics: true,
      borderRadius: Radii.buttonR,
      builder: (context, s) => AnimatedOpacity(
        duration: Motion.of(context, Motion.fast),
        opacity: onPressed == null ? 0.4 : 1,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          constraints: BoxConstraints(minHeight: height, minWidth: Sizes.touch),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Space.m : Space.l,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: Color.alphaBlend(stateOverlay(p, s), bg),
            borderRadius: Radii.buttonR,
            border: Border.all(color: border),
            boxShadow: variant == EDButtonVariant.primary && enabled
                ? [
                    BoxShadow(
                      color: p.accent.withValues(
                        alpha: s.pressed ? 0.10 : 0.22,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              if (loading || icon != null) const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum EDIconVariant { plain, tonal, outline }

/// 48×48 icon button with tooltip, selected state and optional label below.
class EDIconButton extends StatelessWidget {
  const EDIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.toggle = false,
    this.variant = EDIconVariant.plain,
    this.dark = false,
    this.size = Sizes.touch,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool toggle;
  final EDIconVariant variant;
  final bool dark;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    final bg = selected
        ? p.accent
        : switch (variant) {
            EDIconVariant.plain => Colors.transparent,
            EDIconVariant.tonal =>
              dark ? p.elevated.withValues(alpha: 0.9) : p.elevated,
            EDIconVariant.outline => Colors.transparent,
          };
    final fg = selected ? p.onAccent : (color ?? p.text);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        toggled: toggle ? selected : null,
        excludeChildSemantics: true,
        borderRadius: Radii.buttonR,
        builder: (context, s) => AnimatedOpacity(
          duration: Motion.of(context, Motion.fast),
          opacity: onPressed == null ? 0.38 : 1,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Color.alphaBlend(stateOverlay(p, s), bg),
              borderRadius: Radii.buttonR,
              border: variant == EDIconVariant.outline && !selected
                  ? Border.all(color: p.border)
                  : null,
            ),
            child: Icon(icon, size: Sizes.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Square tool button with a caption, used in workspaces and tool rails.
/// Active = lime tile with dark icon, plus bold caption (not colour alone).
class EDToolButton extends StatelessWidget {
  const EDToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.toggle = false,
    this.dark = true,
    this.width = 64,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool toggle;
  final bool dark;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    final t = context.text;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      toggled: toggle ? active : null,
      excludeChildSemantics: true,
      borderRadius: Radii.buttonR,
      builder: (context, s) => AnimatedOpacity(
        duration: Motion.of(context, Motion.fast),
        opacity: onPressed == null ? 0.38 : 1,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 48,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      stateOverlay(p, s),
                      active ? p.accent : p.elevated,
                    ),
                    borderRadius: Radii.buttonR,
                    border: Border.all(color: active ? p.accent : p.border),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: active ? p.onAccent : p.text,
                  ),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(
                    color: active ? p.text : p.textMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips, segmented control, tabs
// ---------------------------------------------------------------------------

/// Filter chip. Selection = raised tone, stronger border, bold label and a
/// small lime marker — never colour alone.
class EDChip extends StatelessWidget {
  const EDChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      borderRadius: Radii.controlR,
      builder: (context, s) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.touch),
        child: Center(
          widthFactor: 1,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s,
              vertical: Space.xs,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                stateOverlay(p, s),
                selected ? p.elevated : p.surface,
              ),
              borderRadius: Radii.controlR,
              border: Border.all(color: selected ? p.borderStrong : p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: selected ? 6 : 0,
                  height: 6,
                  margin: EdgeInsetsDirectional.only(
                    end: selected ? Space.xs : 0,
                  ),
                  decoration: BoxDecoration(
                    color: p.isDark ? p.accent : p.accentText,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? p.text : p.textMuted),
                  const SizedBox(width: Space.xs),
                ],
                Text(
                  label,
                  style: t.labelSm.copyWith(
                    color: selected ? p.text : p.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EDSegment<T> {
  const EDSegment(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control: the selected segment is raised with a lime underline.
class EDSegmented<T> extends StatelessWidget {
  const EDSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.dark = false,
  });
  final List<EDSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.xxs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.buttonR,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (final seg in segments)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(seg.value),
                selected: seg.value == value,
                semanticLabel: seg.label,
                excludeChildSemantics: true,
                borderRadius: Radii.controlR,
                builder: (context, s) {
                  final sel = seg.value == value;
                  return AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    constraints: const BoxConstraints(minHeight: Sizes.touch),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xs,
                      vertical: Space.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        stateOverlay(p, s),
                        sel ? p.elevated : Colors.transparent,
                      ),
                      borderRadius: Radii.controlR,
                      border: Border(
                        bottom: BorderSide(
                          color: sel
                              ? (p.isDark ? p.accent : p.accentText)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (seg.icon != null) ...[
                          Icon(
                            seg.icon,
                            size: 18,
                            color: sel ? p.text : p.textMuted,
                          ),
                          if (seg.label.isNotEmpty)
                            const SizedBox(width: Space.xxs + 2),
                        ],
                        if (seg.label.isNotEmpty)
                          Flexible(
                            child: Text(
                              seg.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSm.copyWith(
                                color: sel ? p.text : p.textMuted,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Text tabs with an animated lime underline, driven by a [TabController].
class EDTabs extends StatelessWidget implements PreferredSizeWidget {
  const EDTabs({super.key, required this.controller, required this.labels});
  final TabController controller;
  final List<(IconData, String)> labels;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: AnimatedBuilder(
        animation: controller.animation!,
        builder: (context, _) {
          final pos = controller.animation!.value;
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / labels.length;
              final rtl = Directionality.of(context) == TextDirection.rtl;
              final x = rtl ? c.maxWidth - w * (pos + 1) : w * pos;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: Pressable(
                            onTap: () => controller.animateTo(
                              i,
                              duration: Motion.of(context),
                            ),
                            selected: controller.index == i,
                            semanticLabel: labels[i].$2,
                            excludeChildSemantics: true,
                            scale: 1,
                            builder: (context, s) {
                              final sel = (pos - i).abs() < 0.5;
                              return Container(
                                constraints: const BoxConstraints(
                                  minHeight: 51,
                                ),
                                color: stateOverlay(p, s),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      labels[i].$1,
                                      size: 18,
                                      color: sel ? p.text : p.textMuted,
                                    ),
                                    const SizedBox(width: Space.xs),
                                    Flexible(
                                      child: Text(
                                        labels[i].$2,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.label.copyWith(
                                          color: sel ? p.text : p.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: x + w * 0.3,
                    width: w * 0.4,
                    bottom: 0,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.isDark ? p.accent : p.accentText,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ));
  }
}

// ---------------------------------------------------------------------------
// Switch and slider
// ---------------------------------------------------------------------------

class EDSwitch extends StatelessWidget {
  const EDSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Pressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      toggled: value,
      isButton: false,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      scale: 1,
      borderRadius: Radii.controlR,
      builder: (context, s) => SizedBox(
        width: 56,
        height: Sizes.touch,
        child: Center(
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? p.accent : p.elevated,
              borderRadius: Radii.controlR,
              border: Border.all(color: value ? p.accent : p.borderStrong),
            ),
            child: AnimatedAlign(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curve,
              alignment: (value != rtl)
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? p.onAccent : p.textMuted,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: value
                    ? Icon(Icons.check_rounded, size: 15, color: p.accent)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom slider: label + live value on top, angular thumb, lime fill.
/// Supports drag, tap-to-jump, keyboard arrows and screen-reader adjust.
class EDSlider extends StatefulWidget {
  const EDSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.valueText,
    this.icon,
    this.onChangeEnd,
    this.enabled = true,
    this.dark = false,
    this.step,
    this.dense = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String valueText;
  final IconData? icon;
  final bool enabled;
  final bool dark;
  final double? step; // keyboard / accessibility step (default 5%)
  final bool dense; // single-row layout for compact panels

  @override
  State<EDSlider> createState() => _EDSliderState();
}

class _EDSliderState extends State<EDSlider> {
  bool _dragging = false;
  bool _focused = false;

  double get _t =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  double get _step => widget.step ?? (widget.max - widget.min) / 20;

  void _setFrom(double dx, double width, bool rtl) {
    var t = (dx / width).clamp(0.0, 1.0);
    if (rtl) t = 1 - t;
    widget.onChanged(widget.min + t * (widget.max - widget.min));
  }

  void _nudge(double dir) {
    final v = (widget.value + dir * _step).clamp(widget.min, widget.max);
    widget.onChanged(v);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.dark ? EDPalette.dark : context.ds;
    final t = context.text;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final active = widget.enabled;
    final labelRow = Row(
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: p.textMuted),
          const SizedBox(width: Space.xs),
        ],
        Expanded(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSm.copyWith(color: p.textMuted),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: _dragging ? p.accent : p.elevated,
            borderRadius: Radii.tagR,
          ),
          child: Text(
            widget.valueText,
            style: t.numeric.copyWith(color: _dragging ? p.onAccent : p.text),
          ),
        ),
      ],
    );
    final track = LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        const thumbW = 20.0;
        final usable = w - thumbW;
        final pos = (rtl ? 1 - _t : _t) * usable;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: active
              ? (d) => _setFrom(d.localPosition.dx - thumbW / 2, usable, rtl)
              : null,
          onTapUp: active
              ? (_) => widget.onChangeEnd?.call(widget.value)
              : null,
          onHorizontalDragStart: active
              ? (d) {
                  setState(() => _dragging = true);
                  Haptics.select();
                  _setFrom(d.localPosition.dx - thumbW / 2, usable, rtl);
                }
              : null,
          onHorizontalDragUpdate: active
              ? (d) => _setFrom(d.localPosition.dx - thumbW / 2, usable, rtl)
              : null,
          onHorizontalDragEnd: active
              ? (_) {
                  setState(() => _dragging = false);
                  widget.onChangeEnd?.call(widget.value);
                }
              : null,
          child: SizedBox(
            height: Sizes.touch,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: thumbW / 2,
                  right: thumbW / 2,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: rtl ? pos + thumbW / 2 : thumbW / 2,
                  width: rtl ? usable - pos : pos,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? p.accent : p.textFaint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: pos,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    width: thumbW,
                    height: _dragging ? 30 : 26,
                    decoration: BoxDecoration(
                      color: active ? p.accent : p.textFaint,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _focused ? p.text : p.bg,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final inc = (widget.value + _step).clamp(widget.min, widget.max);
    final dec = (widget.value - _step).clamp(widget.min, widget.max);
    final incText = widget.valueText.endsWith('%')
        ? '${(inc * 100).round()}%'
        : (inc == inc.roundToDouble() ? inc.round().toString() : inc.toStringAsFixed(1));
    final decText = widget.valueText.endsWith('%')
        ? '${(dec * 100).round()}%'
        : (dec == dec.roundToDouble() ? dec.round().toString() : dec.toStringAsFixed(1));

    return Semantics(
      slider: true,
      enabled: active,
      label: widget.label,
      value: widget.valueText,
      increasedValue: incText,
      decreasedValue: decText,
      onIncrease: active ? () => _nudge(1) : null,
      onDecrease: active ? () => _nudge(-1) : null,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: active,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final inc = rtl
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight;
          final dec = rtl
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft;
          if (e.logicalKey == inc) {
            _nudge(1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == dec) {
            _nudge(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Opacity(
          opacity: active ? 1 : 0.45,
          child: widget.dense
              ? Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: p.textMuted),
                      const SizedBox(width: Space.xs),
                    ],
                    SizedBox(
                      width: 72,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSm.copyWith(color: p.textMuted),
                      ),
                    ),
                    Expanded(child: track),
                    const SizedBox(width: Space.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: Text(
                        widget.valueText,
                        textAlign: TextAlign.end,
                        style: t.numeric.copyWith(
                          color: _dragging ? p.accentText : p.text,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [labelRow, track],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text input
// ---------------------------------------------------------------------------

class EDTextField extends StatelessWidget {
  const EDTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textDirection,
    this.textInputAction,
    this.inputFormatters,
    this.clearable = false,
    this.clearTooltip,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextDirection? textDirection;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool clearable;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: t.labelSm.copyWith(color: p.textMuted)),
          const SizedBox(height: Space.xs),
        ],
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, v, _) => TextField(
            controller: controller,
            autofocus: autofocus,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            textDirection: textDirection,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: t.body,
            cursorWidth: 2,
            decoration: InputDecoration(
              hintText: hint,
              counterStyle: t.caption,
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, color: p.textMuted, size: 20),
              suffixIcon: clearable && v.text.isNotEmpty
                  ? EDIconButton(
                      icon: Icons.close_rounded,
                      tooltip: clearTooltip ?? 'Clear',
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                    )
                  : null,
              constraints: const BoxConstraints(minHeight: Sizes.touch + 4),
            ),
          ),
        ),
      ],
    );
  }
}
