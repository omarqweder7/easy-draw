import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Global haptics switch (set from Settings). Haptics are a no-op on devices
/// without a vibration motor.
abstract final class Haptics {
  static bool enabled = true;
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void press() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void confirm() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}

enum PressHaptic { none, select, press }

/// Accessible interaction primitive used by every Easy Draw control.
///
/// Provides keyboard focus with a visible lime focus ring, hover/pressed
/// tonal overlays, a gentle press scale, disabled handling, semantics and
/// optional haptics. Visuals are supplied by [builder].
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.selected,
    this.toggled,
    this.isButton = true,
    this.haptic = PressHaptic.select,
    this.borderRadius,
    this.scale = 0.97,
    this.focusRing = true,
    this.excludeChildSemantics = false,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget Function(BuildContext context, PressState state) builder;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? selected;
  final bool? toggled;
  final bool isButton;
  final PressHaptic haptic;
  final BorderRadius? borderRadius;
  final double scale;
  final bool focusRing;
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class PressState {
  const PressState({required this.pressed, required this.hovered, required this.focused, required this.enabled});
  final bool pressed;
  final bool hovered;
  final bool focused;
  final bool enabled;
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _activate() {
    if (widget.onTap == null) return;
    switch (widget.haptic) {
      case PressHaptic.select:
        Haptics.select();
      case PressHaptic.press:
        Haptics.press();
      case PressHaptic.none:
        break;
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final state = PressState(pressed: _pressed, hovered: _hovered, focused: _focused, enabled: _enabled);
    final radius = widget.borderRadius ?? Radii.buttonR;
    Widget child = widget.builder(context, state);
    child = AnimatedScale(
      scale: _pressed && _enabled ? widget.scale : 1,
      duration: Motion.of(context, Motion.fast),
      curve: Motion.curve,
      child: child,
    );
    if (widget.focusRing) {
      child = AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        foregroundDecoration: _focused
            ? BoxDecoration(borderRadius: radius, border: Border.all(color: p.isDark ? p.accent : p.accentText, width: 2))
            : null,
        child: child,
      );
    }
    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: widget.onTap == null ? null : _activate,
      onLongPress: widget.onLongPress,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onTap == null ? null : _activate,
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  setState(() => _pressed = false);
                  Haptics.press();
                  widget.onLongPress!();
                },
          child: child,
        ),
      ),
    );
  }
}

/// Tonal overlay colour for interaction states.
Color stateOverlay(EDPalette p, PressState s) {
  if (!s.enabled) return Colors.transparent;
  if (s.pressed) return p.text.withValues(alpha: 0.10);
  if (s.hovered) return p.text.withValues(alpha: 0.05);
  return Colors.transparent;
}
