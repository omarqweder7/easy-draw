import 'package:material_ui/material_ui.dart';

import 'controls.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Base card: surface tone, hairline border, 12 px corners. Pressable when
/// [onTap] is set; [selected] adds a lime border.
class EDCard extends StatelessWidget {
  const EDCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.padding = EdgeInsets.zero,
    this.color,
    this.semanticLabel,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final String? semanticLabel;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    Widget box(PressState? s) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: padding,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.alphaBlend(s == null ? Colors.transparent : stateOverlay(p, s), color ?? (elevated ? p.elevated : p.surface)),
            borderRadius: Radii.cardR,
            border: Border.all(color: selected ? (p.isDark ? p.accent : p.accentText) : p.border, width: selected ? 1.5 : 1),
            boxShadow: p.isDark ? null : const [BoxShadow(color: Color(0x0F101418), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: child,
        );
    if (onTap == null && onLongPress == null) return box(null);
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      semanticLabel: semanticLabel,
      scale: 0.985,
      borderRadius: Radii.cardR,
      builder: (context, s) => box(s),
    );
  }
}

/// Section heading: small spaced overline + optional action.
class EDSectionHeader extends StatelessWidget {
  const EDSectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.fromSTEB(Space.m, Space.l, Space.xs, Space.xs),
      child: Row(children: [
        Container(width: 3, height: 14, color: p.isDark ? p.accent : p.accentText),
        const SizedBox(width: Space.xs),
        Expanded(child: Semantics(header: true, child: Text(title, style: t.title))),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            semanticLabel: actionLabel,
            excludeChildSemantics: true,
            borderRadius: Radii.controlR,
            builder: (context, s) => Container(
              constraints: const BoxConstraints(minHeight: Sizes.touch),
              padding: const EdgeInsets.symmetric(horizontal: Space.s),
              alignment: Alignment.center,
              color: stateOverlay(p, s),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!, style: t.labelSm.copyWith(color: p.accentText)),
                Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18, color: p.accentText),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A row inside a settings group or a sheet: icon tile, title, description,
/// trailing widget. Minimum 56 px tall.
class EDListRow extends StatelessWidget {
  const EDListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.selected = false,
    this.chevron = false,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool selected;
  final bool chevron;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    final fg = destructive ? p.danger : p.text;
    Widget content(PressState? s) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          color: s == null ? null : stateOverlay(p, s),
          padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
          child: Row(children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? p.accent : (destructive ? p.danger.withValues(alpha: 0.12) : p.elevated),
                  borderRadius: Radii.controlR,
                ),
                child: Icon(icon, size: 19, color: selected ? p.onAccent : fg),
              ),
              const SizedBox(width: Space.s),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: t.label.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySm),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
            if (selected && trailing == null) Icon(Icons.check_rounded, color: p.accentText, size: 22),
            if (chevron)
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.textFaint),
          ]),
        );
    if (onTap == null) return Semantics(container: true, child: content(null));
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      scale: 1,
      borderRadius: BorderRadius.zero,
      builder: (context, s) => content(s),
    );
  }
}

/// A switch row — the whole row toggles.
class EDSwitchRow extends StatelessWidget {
  const EDSwitchRow({super.key, required this.title, required this.value, required this.onChanged, this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: EDListRow(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: () => onChanged(!value),
        trailing: ExcludeFocus(child: EDSwitch(value: value, onChanged: onChanged, semanticLabel: title)),
      ),
    );
  }
}

/// Groups rows in a single bordered card with hairline dividers.
class EDGroup extends StatelessWidget {
  const EDGroup({super.key, required this.children, this.title, this.description});
  final List<Widget> children;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xxs, Space.l, Space.xxs, Space.xs),
          child: Semantics(header: true, child: Text(title!.toUpperCase(), style: t.overline)),
        ),
      if (description != null)
        Padding(padding: const EdgeInsetsDirectional.fromSTEB(Space.xxs, 0, Space.xxs, Space.xs), child: Text(description!, style: t.bodySm)),
      EDCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: Space.m, endIndent: Space.m, color: p.border),
            children[i],
          ],
        ]),
      ),
    ]);
  }
}

/// Small square tag (e.g. difficulty) with an icon pattern + text.
class EDTag extends StatelessWidget {
  const EDTag({super.key, required this.label, this.level, this.icon, this.onDark = false});
  final String label;
  final int? level; // 1..3 renders filled bars
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = onDark ? EDPalette.dark : context.ds;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: p.elevated, borderRadius: Radii.tagR, border: Border.all(color: p.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (level != null)
          for (var i = 0; i < 3; i++)
            Container(
              width: 3,
              height: 6.0 + i * 3,
              margin: const EdgeInsetsDirectional.only(end: 2),
              decoration: BoxDecoration(color: i < level! ? (p.isDark ? p.accent : p.accentText) : p.borderStrong, borderRadius: BorderRadius.circular(1)),
            ),
        if (icon != null) Icon(icon, size: 12, color: p.textMuted),
        if (level != null || icon != null) const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: p.text, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// The camera "viewfinder" corner brackets from the app icon — Easy Draw's
/// recurring visual motif.
class ViewfinderCorners extends StatelessWidget {
  const ViewfinderCorners({super.key, this.color, this.length = 18, this.stroke = 2.5, this.inset = 0, this.child});
  final Color? color;
  final double length;
  final double stroke;
  final double inset;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _CornersPainter(color ?? context.ds.textMuted, length, stroke, inset),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color, this.len, this.stroke, this.inset);
  final Color color;
  final double len;
  final double stroke;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final r = (Offset.zero & size).deflate(inset + stroke / 2);
    final path = Path()
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + len, r.top)
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + len)
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - len, r.bottom)
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - len);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color || old.len != len || old.stroke != stroke || old.inset != inset;
}

/// Empty / error / permission state with the viewfinder motif.
class EDStateView extends StatelessWidget {
  const EDStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = EDStateTone.neutral,
    this.dark = false,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final EDStateTone tone;
  final bool dark;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    final t = context.text;
    final accent = switch (tone) {
      EDStateTone.neutral => p.isDark ? p.accent : p.accentText,
      EDStateTone.error => p.danger,
      EDStateTone.warning => p.warning,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 104,
              height: 104,
              child: ViewfinderCorners(
                color: accent,
                length: 20,
                child: Center(child: Icon(icon, size: 44, color: p.text)),
              ),
            ),
            const SizedBox(height: Space.l),
            Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: t.headline.copyWith(color: p.text))),
            const SizedBox(height: Space.xs),
            Text(message, textAlign: TextAlign.center, style: t.body.copyWith(color: p.textMuted)),
            if (extra != null) ...[const SizedBox(height: Space.m), extra!],
            if (actionLabel != null) ...[
              const SizedBox(height: Space.l),
              EDButton(label: actionLabel!, onPressed: onAction, dark: dark),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: Space.xs),
              EDButton.ghost(label: secondaryLabel!, onPressed: onSecondary, dark: dark),
            ],
          ]),
        ),
      ),
    );
  }
}

enum EDStateTone { neutral, error, warning }

/// Calm loading indicator with an optional message.
class EDLoading extends StatelessWidget {
  const EDLoading({super.key, this.message, this.dark = false});
  final String? message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = dark ? EDPalette.dark : context.ds;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: p.isDark ? p.accent : p.accentText, backgroundColor: p.border)),
        if (message != null) ...[
          const SizedBox(height: Space.s),
          Text(message!, style: context.text.bodySm.copyWith(color: p.textMuted)),
        ],
      ]),
    );
  }
}

/// Placeholder block for content that is still loading (gently pulses unless
/// reduced motion is on).
class EDSkeleton extends StatefulWidget {
  const EDSkeleton({super.key});
  @override
  State<EDSkeleton> createState() => _EDSkeletonState();
}

class _EDSkeletonState extends State<EDSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context) == Duration.zero) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => ColoredBox(color: Color.lerp(p.elevated, p.border, _c.value * 0.6)!),
    );
  }
}
