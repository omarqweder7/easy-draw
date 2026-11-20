import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import 'controls.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// Opens a styled bottom sheet with a heading, an explicit close button and
/// scrollable content. Use [EDGroup]/[EDListRow] for grouped options.
Future<T?> showEDSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  bool dark = false,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? Duration.zero : Motion.slow,
      reverseDuration: reduce ? Duration.zero : Motion.base,
      curve: Motion.curve,
    ),
    builder: (c) {
      Widget sheet = _SheetBody(
        title: title,
        subtitle: subtitle,
        builder: builder,
      );
      if (dark) {
        sheet = Theme(
          data: Theme.of(c).copyWith(
            extensions: [EDPalette.dark, EDText.build(EDPalette.dark, c.lang)],
          ),
          child: sheet,
        );
      }
      return sheet;
    },
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.builder,
  });
  final String title;
  final String? subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        border: Border(top: BorderSide(color: p.border)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: Space.xs),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Space.l,
                  Space.s,
                  Space.xs,
                  Space.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(title, style: t.headline),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: Space.xxs),
                              Text(subtitle!, style: t.bodySm),
                            ],
                          ],
                        ),
                      ),
                    ),
                    EDIconButton(
                      icon: Icons.close_rounded,
                      tooltip: context.tr('common.close', 'Close'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.m,
                    Space.xs,
                    Space.m,
                    Space.l,
                  ),
                  child: builder(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Styled confirmation dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final r = await _showEDDialog<bool>(
    context,
    builder: (c) => _DialogBody(
      icon: destructive
          ? Icons.warning_amber_rounded
          : Icons.help_outline_rounded,
      destructive: destructive,
      title: title,
      body: Text(message, style: c.text.body.copyWith(color: c.ds.textMuted)),
      actions: [
        EDButton.secondary(
          label: c.tr('common.cancel', 'Cancel'),
          onPressed: () => Navigator.pop(c, false),
          expand: true,
        ),
        destructive
            ? EDButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(c, true),
                expand: true,
                variant: EDButtonVariant.danger,
              )
            : EDButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(c, true),
                expand: true,
              ),
      ],
    ),
  );
  return r ?? false;
}

/// Styled single-line text prompt (rename etc.).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirmLabel,
}) {
  final ctrl = TextEditingController(text: initial);
  return _showEDDialog<String>(
    context,
    builder: (c) => _DialogBody(
      icon: Icons.edit_outlined,
      title: title,
      body: EDTextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(c, v),
        clearable: true,
        clearTooltip: c.tr('common.clear', 'Clear'),
      ),
      actions: [
        EDButton.secondary(
          label: c.tr('common.cancel', 'Cancel'),
          onPressed: () => Navigator.pop(c),
          expand: true,
        ),
        EDButton(
          label: confirmLabel,
          onPressed: () => Navigator.pop(c, ctrl.text),
          expand: true,
        ),
      ],
    ),
  );
}

Future<T?> _showEDDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: context.ds.scrim,
    transitionDuration: reduce ? Duration.zero : Motion.base,
    pageBuilder: (c, _, _) => builder(c),
    transitionBuilder: (c, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Motion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: Space.l,
            right: Space.l,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: Radii.cardR,
                  border: Border.all(color: p.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(Space.l),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: destructive
                                  ? p.danger.withValues(alpha: 0.14)
                                  : p.accentSoft,
                              borderRadius: Radii.controlR,
                            ),
                            child: Icon(
                              icon,
                              color: destructive ? p.danger : p.accentText,
                            ),
                          ),
                          const SizedBox(width: Space.s),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(title, style: t.title),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      body,
                      const SizedBox(height: Space.l),
                      Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: Space.s),
                            Expanded(child: actions[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown-style field: shows the current value and opens a sheet of
/// options (sheets are easier to use than tiny menus on phones).
class EDDropdown<T> extends StatelessWidget {
  const EDDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
  });
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final current = options
        .firstWhere((o) => o.$1 == value, orElse: () => options.first)
        .$2;
    return EDListRow(
      title: label,
      subtitle: current,
      icon: icon,
      semanticLabel: '$label: $current',
      trailing: Icon(Icons.unfold_more_rounded, color: context.ds.textMuted),
      onTap: () async {
        final picked = await showEDSheet<T>(
          context,
          title: label,
          builder: (c) => EDGroup(
            children: [
              for (final o in options)
                EDListRow(
                  title: o.$2,
                  selected: o.$1 == value,
                  onTap: () => Navigator.pop(c, o.$1),
                ),
            ],
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Full-screen progress overlay for long operations.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.message, this.progress});
  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: ColoredBox(
          color: p.scrim,
          child: Center(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: Radii.cardR,
                border: Border.all(color: p.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message, style: t.label),
                  const SizedBox(height: Space.m),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: p.isDark ? p.accent : p.accentText,
                      backgroundColor: p.border,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      '${(progress! * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: t.numeric.copyWith(color: p.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Snackbar content: icon tile + message. Errors use the danger tone.
Widget snackContent(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final p = context.ds;
  return Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: error ? p.danger : p.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          error ? Icons.priority_high_rounded : Icons.check_rounded,
          size: 18,
          color: error ? p.onDanger : p.onAccent,
        ),
      ),
      const SizedBox(width: Space.s),
      Expanded(
        child: Text(
          message,
          style: context.text.bodySm.copyWith(color: p.isDark ? p.text : p.bg),
        ),
      ),
    ],
  );
}
