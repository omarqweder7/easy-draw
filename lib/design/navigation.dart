import 'package:material_ui/material_ui.dart';

import 'controls.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Compact top bar: back button, title (+ optional subtitle widget), actions.
class EDTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EDTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.large = false,
    this.onTitleTap,
    this.bottom,
  });

  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final bool large;
  final VoidCallback? onTitleTap;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight((large ? 72 : 60) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    final canPop =
        showBack && (onBack != null || Navigator.of(context).canPop());
    Widget titleW = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: large ? t.headline : t.title,
          ),
        ),
        ?subtitle,
      ],
    );
    if (onTitleTap != null) {
      final content = titleW;
      titleW = Pressable(
        onTap: onTitleTap,
        scale: 1,
        borderRadius: Radii.controlR,
        builder: (_, _) => content,
      );
    }
    return Material(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: large ? 72 : 60,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: canPop ? Space.xxs : Space.m,
                  end: Space.xxs,
                ),
                child: Row(
                  children: [
                    if (canPop) ...[
                      EDIconButton(
                        icon: Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: onBack ?? () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: Space.xxs),
                    ],
                    Expanded(child: titleW),
                    ...actions,
                  ],
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

class EDNavItem {
  const EDNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Custom bottom navigation: outlined icons, concise labels, and a short
/// lime bar that slides to the active destination.
class EDBottomNav extends StatelessWidget {
  const EDBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });
  final List<EDNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / items.length;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final x = rtl ? c.maxWidth - w * (index + 1) : w * index;
            return Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Pressable(
                          onTap: () => onSelect(i),
                          selected: i == index,
                          semanticLabel: items[i].label,
                          excludeChildSemantics: true,
                          scale: 0.94,
                          borderRadius: Radii.controlR,
                          builder: (context, s) {
                            final sel = i == index;
                            return Container(
                              constraints: const BoxConstraints(minHeight: 64),
                              color: stateOverlay(p, s),
                              padding: const EdgeInsets.symmetric(
                                vertical: Space.xs,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    items[i].icon,
                                    size: 24,
                                    color: sel ? p.accentText : p.textMuted,
                                  ),
                                  const SizedBox(height: Space.xxs),
                                  Text(
                                    items[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: sel ? p.text : p.textMuted,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
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
                AnimatedPositioned(
                  duration: Motion.of(context),
                  curve: Motion.curve,
                  top: 0,
                  left: x + w / 2 - 14,
                  width: 28,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.isDark ? p.accent : p.accentText,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Side rail for landscape / wide layouts.
class EDNavRail extends StatelessWidget {
  const EDNavRail({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });
  final List<EDNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: p.surface,
        border: BorderDirectional(end: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: Space.m),
            Image.asset(
              'assets/brand/logo.png',
              width: 40,
              height: 40,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: Space.l),
            for (var i = 0; i < items.length; i++)
              Pressable(
                onTap: () => onSelect(i),
                selected: i == index,
                semanticLabel: items[i].label,
                excludeChildSemantics: true,
                borderRadius: Radii.controlR,
                builder: (context, s) {
                  final sel = i == index;
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(vertical: Space.xxs),
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        stateOverlay(p, s),
                        sel ? p.elevated : Colors.transparent,
                      ),
                      borderRadius: Radii.controlR,
                      border: BorderDirectional(
                        start: BorderSide(
                          color: sel
                              ? (p.isDark ? p.accent : p.accentText)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          items[i].icon,
                          color: sel ? p.accentText : p.textMuted,
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          items[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: t.caption.copyWith(
                            color: sel ? p.text : p.textMuted,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
