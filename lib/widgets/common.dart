import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/art_store.dart';
import '../data/models.dart';
import '../design/design.dart';
import '../main.dart';
import 'lesson_painter.dart';

export '../design/design.dart';

/// Reference artwork on a "paper" tile, with loading and error states.
class RefThumb extends StatelessWidget {
  const RefThumb(
    this.source, {
    super.key,
    this.padding = Space.s,
    this.fit = BoxFit.contain,
    this.thumbFile,
  });
  final RefSource source;
  final double padding;
  final BoxFit fit;
  final File? thumbFile;

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    Widget child;
    switch (source.kind) {
      case RefKind.asset:
        child = source.isSvg
            ? SvgPicture.asset(
                source.path,
                fit: fit,
                excludeFromSemantics: true,
                placeholderBuilder: (_) => const EDSkeleton(),
                errorBuilder: (_, _, _) => const MissingFile(),
              )
            : Image.asset(
                source.path,
                fit: fit,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const MissingFile(),
              );
      case RefKind.file:
        final f = thumbFile ?? File(source.path);
        child = Image.file(
          f,
          fit: fit,
          excludeFromSemantics: true,
          cacheWidth: 600,
          frameBuilder: (c, w, frame, sync) =>
              frame == null && !sync ? const EDSkeleton() : w,
          errorBuilder: (c, e, s) => const MissingFile(),
        );
      case RefKind.lessonStep:
        child = CustomPaint(
          painter: LessonPainter(
            source.lesson!,
            source.step,
            doneColor: const Color(0xFF14191C),
            newColor: const Color(0xFF14191C),
            highlightCurrent: false,
          ),
        );
    }
    return ColoredBox(
      color: p.paper,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class MissingFile extends StatelessWidget {
  const MissingFile({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, color: Color(0xFF6E7A74)),
        const SizedBox(height: Space.xxs),
        Text(
          context.tr('common.missingFile', 'File missing'),
          style: context.text.caption.copyWith(color: const Color(0xFF4C5852)),
        ),
      ],
    ),
  );
}

/// Difficulty as rising bars + text (never colour alone).
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge(this.difficulty, {super.key, this.dense = false});
  final Difficulty difficulty;
  final bool dense;

  @override
  Widget build(BuildContext context) => EDTag(
    label: difficultyLabel(context, difficulty),
    level: difficulty.index + 1,
  );
}

String difficultyLabel(BuildContext context, Difficulty d) => switch (d) {
  Difficulty.easy => context.tr('diff.easy', 'Easy'),
  Difficulty.medium => context.tr('diff.medium', 'Medium'),
  Difficulty.hard => context.tr('diff.hard', 'Challenging'),
};

/// Library card: square artwork tile, title, difficulty and favourite toggle.
class RefCard extends StatelessWidget {
  const RefCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
  });
  final ReferenceItem item;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final title = context.loc(item.title);
    final t = context.text;
    return SizedBox(
      width: width,
      child: EDCard(
        onTap: onTap,
        semanticLabel: '$title, ${difficultyLabel(context, item.difficulty)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RefThumb(item.toSource(), padding: Space.m),
                  ),
                  PositionedDirectional(
                    top: Space.xxs,
                    end: Space.xxs,
                    child: ListenableBuilder(
                      listenable: content,
                      builder: (context, _) => FavoriteButton(
                        selected: content.isFavorite('lib:${item.id}'),
                        onPressed: () =>
                            content.toggleFavorite('lib:${item.id}'),
                        subject: title,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.s,
                Space.s,
                Space.s,
                Space.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSm,
                  ),
                  const SizedBox(height: Space.xs),
                  DifficultyBadge(item.difficulty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.subject,
  });
  final bool selected;
  final VoidCallback onPressed;
  final String subject;

  @override
  Widget build(BuildContext context) {
    const p = EDPalette.dark;
    return Pressable(
      onTap: onPressed,
      toggled: selected,
      semanticLabel: selected
          ? context.trf('fav.remove', 'Remove {name} from favorites', {
              'name': subject,
            })
          : context.trf('fav.add', 'Add {name} to favorites', {
              'name': subject,
            }),
      excludeChildSemantics: true,
      borderRadius: Radii.controlR,
      builder: (context, s) => SizedBox(
        width: Sizes.touch,
        height: Sizes.touch,
        child: Center(
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? p.accent : p.bg.withValues(alpha: 0.78),
              borderRadius: Radii.controlR,
            ),
            child: Icon(
              selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: selected ? p.onAccent : p.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Press-and-hold control used for deliberate unlocking. Shows a filling
/// progress bar; screen readers get a direct action.
class HoldToUnlockButton extends StatefulWidget {
  const HoldToUnlockButton({
    super.key,
    required this.onUnlocked,
    this.duration = const Duration(milliseconds: 1200),
    this.label,
    this.compact = false,
  });
  final VoidCallback onUnlocked;
  final Duration duration;
  final String? label;
  final bool compact;

  @override
  State<HoldToUnlockButton> createState() => _HoldToUnlockButtonState();
}

class _HoldToUnlockButtonState extends State<HoldToUnlockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            Haptics.confirm();
            widget.onUnlocked();
            _c.reset();
          }
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const p = EDPalette.dark;
    final t = context.text;
    final label = widget.label ?? context.tr('lock.hold', 'Hold to unlock');
    return Semantics(
      button: true,
      label: label,
      hint: context.tr(
        'lock.holdHint',
        'Double-tap and hold, or use the screen reader action to unlock',
      ),
      onTap: widget.onUnlocked,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) {
          Haptics.select();
          _c.forward();
        },
        onTapUp: (_) => _c.reverse(),
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            width: widget.compact ? 64 : null,
            constraints: const BoxConstraints(
              minHeight: Sizes.touch,
              minWidth: Sizes.touch,
            ),
            decoration: BoxDecoration(
              color: p.bg.withValues(alpha: 0.92),
              borderRadius: Radii.buttonR,
              border: Border.all(color: p.accent, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: _c.value,
                    child: ColoredBox(color: p.accent.withValues(alpha: 0.85)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? Space.xxs : Space.m,
                    vertical: Space.s,
                  ),
                  child: Flex(
                    direction: widget.compact ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: _c.value > 0.25 ? p.onAccent : p.accent,
                      ),
                      SizedBox(
                        width: widget.compact ? 0 : Space.xs,
                        height: widget.compact ? Space.xxs : 0,
                      ),
                      Text(
                        label,
                        maxLines: widget.compact ? 2 : null,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: (widget.compact ? t.caption : t.label).copyWith(
                          color: _c.value > 0.5 ? p.onAccent : p.text,
                        ),
                      ),
                    ],
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

void showSnack(
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool error = false,
}) {
  final m = rootMessengerKey.currentState;
  final ctx = rootNavigatorKey.currentContext;
  if (m == null || ctx == null) return;
  if (error && Haptics.enabled) {
    HapticFeedback.heavyImpact();
  }
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: snackContent(ctx, message, error: error),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      duration: Duration(seconds: error ? 6 : 3),
    ),
  );
}

String storageMessage(BuildContext context, Object e) {
  if (e is StorageFailure) {
    switch (e.reason) {
      case StorageReason.full:
        return context.tr(
          'err.storageFull',
          'Your device is out of storage. Free up space and try again — your existing work is safe.',
        );
      case StorageReason.missing:
        return context.tr(
          'err.missing',
          'That file could not be found. It may have been deleted.',
        );
      case StorageReason.other:
        break;
    }
  }
  return context.tr(
    'err.saveFailed',
    'Saving failed. Your previous version is still safe. Please try again.',
  );
}

/// Debounces rapid calls (e.g. slider drags → preview re-render).
class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void call(VoidCallback f) {
    _t?.cancel();
    _t = Timer(delay, f);
  }

  void dispose() => _t?.cancel();
}

/// Numbered how-to steps in a styled sheet (workspace help).
Future<void> showStepsSheet(
  BuildContext context, {
  required String title,
  required List<String> steps,
  bool dark = false,
}) {
  return showEDSheet<void>(
    context,
    title: title,
    dark: dark,
    builder: (c) {
      final p = c.ds;
      final t = c.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? p.accent : p.elevated,
                      borderRadius: Radii.controlR,
                      border: Border.all(color: p.border),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: t.labelSm.copyWith(
                        color: i == 0 ? p.onAccent : p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(steps[i], style: t.body),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Display title for a reference in the current language. Library items
/// carry their English title in [RefSource.title]; look up the translation.
String refTitle(BuildContext context, RefSource s) {
  final id = s.refId;
  if (id != null && id.startsWith('lib:')) {
    final r = context.content.referenceById(id.substring(4));
    if (r != null) return context.loc(r.title);
  }
  return s.title;
}
