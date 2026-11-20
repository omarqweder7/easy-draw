import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/lesson_painter.dart';
import 'nav.dart';

const _lessonNew = Color(0xFF2F7D00); // current-step lines (≥4.5:1 on paper)
const _lessonDone = Color(0xFFA3ABA9); // already drawn
const _lessonInk = Color(0xFF14191C);

class LessonsView extends StatefulWidget {
  const LessonsView({super.key});

  @override
  State<LessonsView> createState() => _LessonsViewState();
}

class _LessonsViewState extends State<LessonsView> with AutomaticKeepAliveClientMixin {
  String? _subject;
  Difficulty? _difficulty;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = context.content;
    final subjects = {for (final l in content.lessons) l.subject}.toList();
    return ListenableBuilder(
      listenable: content,
      builder: (context, _) {
        final list = content.lessons.where((l) => (_subject == null || l.subject == _subject) && (_difficulty == null || l.difficulty == _difficulty)).toList();
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: context.scaled(28) + 36,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, 0),
                scrollDirection: Axis.horizontal,
                children: [
                  EDChip(label: context.tr('filter.all', 'All'), selected: _subject == null, onTap: () => setState(() => _subject = null)),
                  for (final s in subjects)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: Space.xs),
                      child: EDChip(
                        icon: categoryById(s).icon,
                        label: context.loc(categoryById(s).title),
                        selected: _subject == s,
                        onTap: () => setState(() => _subject = _subject == s ? null : s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.m),
              child: EDSegmented<int>(
                segments: [
                  EDSegment(-1, context.tr('filter.any', 'Any')),
                  for (final d in Difficulty.values) EDSegment(d.index, difficultyLabel(context, d)),
                ],
                value: _difficulty?.index ?? -1,
                onChanged: (v) => setState(() => _difficulty = v < 0 ? null : Difficulty.values[v]),
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EDStateView(
                icon: Icons.school_outlined,
                title: context.tr('lessons.none', 'No lessons match'),
                message: context.tr('lessons.noneBody', 'Try a different subject or difficulty.'),
                actionLabel: context.tr('filter.clear', 'Clear filters'),
                onAction: () => setState(() {
                  _subject = null;
                  _difficulty = null;
                }),
              ),
            )
          else
            SliverLayoutBuilder(builder: (context, c) {
              final width = c.crossAxisExtent - Space.m * 2;
              final cols = (width / 180).floor().clamp(2, 6);
              final w = (width - Space.s * (cols - 1)) / cols;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: Space.s,
                    mainAxisSpacing: Space.s,
                    mainAxisExtent: w / 1.15 + context.scaled(46) + Space.s * 3 + 8,
                  ),
                  delegate: SliverChildBuilderDelegate((c, i) => LessonCard(lesson: list[i]), childCount: list.length),
                ),
              );
            }),
        ]);
      },
    );
  }
}

/// Finished-drawing preview of a lesson (or a highlighted step).
class LessonPreview extends StatelessWidget {
  const LessonPreview({super.key, required this.lesson, this.step});
  final Lesson lesson;
  final int? step;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.ds.paper,
        child: Padding(
          padding: const EdgeInsets.all(Space.s),
          child: CustomPaint(
            size: Size.infinite,
            painter: LessonPainter(lesson, step ?? lesson.steps.length - 1, doneColor: _lessonInk, newColor: _lessonNew, highlightCurrent: step != null),
          ),
        ),
      );
}

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson, this.width});
  final Lesson lesson;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final started = content.lessonStarted(lesson.id);
    final done = content.lessonDone(lesson.id);
    final step = content.lessonStep(lesson.id);
    final p = context.ds;
    final t = context.text;
    final title = context.loc(lesson.title);
    return SizedBox(
      width: width,
      child: EDCard(
        onTap: () => push(context, LessonDetailScreen(lesson: lesson)),
        semanticLabel: '$title, ${difficultyLabel(context, lesson.difficulty)}, ${context.trf('lesson.min', '{n} min', {'n': lesson.minutes})}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              LessonPreview(lesson: lesson),
              if (done)
                PositionedDirectional(
                  top: Space.xs,
                  end: Space.xs,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: p.accent, borderRadius: Radii.tagR),
                    child: Icon(Icons.check_rounded, size: 16, color: p.onAccent, semanticLabel: context.tr('lesson.done', 'Completed')),
                  ),
                ),
            ]),
          ),
          if (started && !done)
            LinearProgressIndicator(value: (step + 1) / lesson.steps.length, minHeight: 3, backgroundColor: p.border, color: p.isDark ? p.accent : p.accentText),
          Padding(
            padding: const EdgeInsets.all(Space.s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
              const SizedBox(height: Space.xs),
              Row(children: [
                Flexible(child: DifficultyBadge(lesson.difficulty)),
                const SizedBox(width: Space.xs),
                Icon(Icons.schedule_outlined, size: 14, color: p.textMuted),
                const SizedBox(width: 2),
                Flexible(child: Text(context.trf('lesson.min', '{n} min', {'n': lesson.minutes}), overflow: TextOverflow.ellipsis, style: t.caption)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final p = context.ds;
    final t = context.text;
    return Scaffold(
      appBar: EDTopBar(title: context.loc(lesson.title)),
      body: ListenableBuilder(
        listenable: content,
        builder: (context, _) {
          final started = content.lessonStarted(lesson.id);
          final done = content.lessonDone(lesson.id);
          final step = content.lessonStep(lesson.id);
          final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
          final preview = EDCard(
            child: Semantics(label: context.tr('lesson.finished', 'Finished drawing preview'), child: LessonPreview(lesson: lesson)),
          );
          final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: Space.xs, runSpacing: Space.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DifficultyBadge(lesson.difficulty),
              EDTag(icon: Icons.schedule_outlined, label: context.trf('lesson.about', 'About {n} minutes', {'n': lesson.minutes})),
              EDTag(icon: Icons.format_list_numbered_rounded, label: context.trf('lesson.steps', '{n} steps', {'n': lesson.steps.length})),
              EDTag(icon: categoryById(lesson.subject).icon, label: context.loc(categoryById(lesson.subject).title)),
            ]),
            EDGroup(title: context.tr('lesson.materials', 'Suggested materials'), children: [
              for (final m in lesson.materials) EDListRow(icon: Icons.edit_outlined, title: context.loc(m)),
            ]),
            const SizedBox(height: Space.l),
            EDButton(
              expand: true,
              icon: started && !done ? Icons.play_arrow_rounded : Icons.school_outlined,
              label: started && !done
                  ? context.trf('lesson.resume', 'Resume at step {n}', {'n': step + 1})
                  : done
                      ? context.tr('lesson.again', 'Start again')
                      : context.tr('lesson.start', 'Start lesson'),
              onPressed: () {
                if (!started || done) content.saveLessonProgress(lesson.id, 0, done: false);
                push(context, LessonPlayerScreen(lesson: lesson));
              },
            ),
            if (started) ...[
              const SizedBox(height: Space.xs),
              EDButton.ghost(label: context.tr('lesson.reset', 'Reset progress'), icon: Icons.restart_alt_rounded, onPressed: () => content.resetLesson(lesson.id)),
            ],
            if (done)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.verified_rounded, size: 18, color: p.accentText),
                  const SizedBox(width: Space.xs),
                  Text(context.tr('lesson.done', 'Completed'), style: t.labelSm.copyWith(color: p.accentText)),
                ]),
              ),
          ]);
          if (landscape) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: preview),
                  const SizedBox(width: Space.m),
                  Expanded(child: SingleChildScrollView(child: info)),
                ]),
              ),
            );
          }
          return ListView(padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.xl), children: [
            AspectRatio(aspectRatio: 1.2, child: preview),
            const SizedBox(height: Space.m),
            info,
          ]);
        },
      ),
    );
  }
}

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late int _step = context.content.lessonStep(widget.lesson.id).clamp(0, widget.lesson.steps.length - 1);

  Lesson get l => widget.lesson;

  void _go(int s) {
    setState(() => _step = s.clamp(0, l.steps.length - 1));
    context.content.saveLessonProgress(l.id, _step);
  }

  void _finish() {
    context.content.saveLessonProgress(l.id, l.steps.length - 1, done: true);
    Haptics.confirm();
    showSnack(context.tr('lesson.congrats', 'Lesson complete — great work!'));
    Navigator.pop(context);
  }

  RefSource get _stepSource => RefSource.lessonStep(l, _step,
      title: '${context.loc(l.title)} · ${context.trf('lesson.stepOf', 'Step {n} of {total}', {'n': _step + 1, 'total': l.steps.length})}');

  @override
  Widget build(BuildContext context) {
    final p = context.ds;
    final t = context.text;
    final last = _step == l.steps.length - 1;
    final stepLabel = context.trf('lesson.stepOf', 'Step {n} of {total}', {'n': _step + 1, 'total': l.steps.length});
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    final picture = EDCard(
      child: Semantics(
        label: '$stepLabel. ${context.loc(l.steps[_step].text)}',
        child: ColoredBox(
          color: p.paper,
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: AnimatedSwitcher(
              duration: Motion.of(context),
              child: CustomPaint(
                key: ValueKey(_step),
                size: Size.infinite,
                painter: LessonPainter(l, _step, doneColor: _lessonDone, newColor: _lessonNew),
              ),
            ),
          ),
        ),
      ),
    );

    Widget legend(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 18, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: Space.xs),
          Flexible(child: Text(s, style: t.caption)),
        ]);

    final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              stepLabel.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.overline.copyWith(color: p.accentText),
            ),
          ),
          const SizedBox(width: Space.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < l.steps.length; i++)
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: i == _step ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(start: 4),
                  decoration: BoxDecoration(
                    color: i <= _step ? (p.isDark ? p.accent : p.accentText) : p.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: Space.xs),
      Text(context.loc(l.steps[_step].text), style: t.title),
      const SizedBox(height: Space.s),
      Wrap(spacing: Space.m, runSpacing: Space.xxs, children: [
        legend(_lessonNew, context.tr('lesson.legendNew', 'Green = lines to add now')),
        legend(_lessonDone, context.tr('lesson.legendOld', 'Gray = already drawn')),
      ]),
      const SizedBox(height: Space.m),
      Row(children: [
        Expanded(child: EDButton.secondary(compact: true, icon: Icons.wb_sunny_outlined, label: context.tr('lesson.traceStep', 'Trace this step'), onPressed: () => openTrace(context, _stepSource))),
        const SizedBox(width: Space.xs),
        Expanded(child: EDButton.secondary(compact: true, icon: Icons.photo_camera_outlined, label: context.tr('lesson.cameraStep', 'Camera with this step'), onPressed: () => openCamera(context, _stepSource))),
      ]),
      const SizedBox(height: Space.s),
      Row(children: [
        Expanded(
          child: EDButton.secondary(
            icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
            label: context.tr('common.previous', 'Previous'),
            onPressed: _step == 0 ? null : () => _go(_step - 1),
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: EDButton(
            icon: last ? Icons.check_rounded : (context.isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded),
            label: last ? context.tr('lesson.finish', 'Finish') : context.tr('common.next', 'Next'),
            onPressed: last ? _finish : () => _go(_step + 1),
          ),
        ),
      ]),
    ]);

    return Scaffold(
      appBar: EDTopBar(
        title: context.loc(l.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Semantics(
            label: context.tr('lesson.progress', 'Lesson progress'),
            value: stepLabel,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_step + 1) / l.steps.length),
              duration: Motion.of(context),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: p.border, color: p.isDark ? p.accent : p.accentText),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: landscape
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: picture),
                  const SizedBox(width: Space.m),
                  Expanded(child: SingleChildScrollView(child: info)),
                ])
              : LayoutBuilder(builder: (context, c) {
                  // Tall screens: picture fills the space above the controls.
                  // Short screens / large text: everything scrolls.
                  if (c.maxHeight >= 560 && MediaQuery.textScalerOf(context).scale(1) <= 1.15) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: picture),
                      const SizedBox(height: Space.m),
                      info,
                    ]);
                  }
                  return ListView(children: [
                    AspectRatio(aspectRatio: 1, child: picture),
                    const SizedBox(height: Space.m),
                    info,
                  ]);
                }),
        ),
      ),
    );
  }
}
