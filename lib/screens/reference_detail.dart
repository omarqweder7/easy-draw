import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'nav.dart';

class ReferenceDetailScreen extends StatelessWidget {
  const ReferenceDetailScreen({super.key, required this.item});
  final ReferenceItem item;

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final title = context.loc(item.title);
    final src = item.toSource();
    final cat = categoryById(item.category);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final t = context.text;
    final p = context.ds;

    final preview = EDCard(
      child: Stack(children: [
        Positioned.fill(
          child: Semantics(
            label: context.trf('ref.preview', 'Preview of {name}. Pinch to zoom.', {'name': title}),
            child: InteractiveViewer(maxScale: 5, child: RefThumb(src, padding: Space.l)),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: ViewfinderCorners(color: p.borderStrong, inset: Space.s, length: 16, stroke: 2))),
      ]),
    );

    final actions = ListenableBuilder(
      listenable: content,
      builder: (context, _) {
        final fav = content.isFavorite('lib:${item.id}');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(context.loc(cat.title).toUpperCase(), style: t.overline),
          const SizedBox(height: Space.xxs),
          Text(title, style: t.headline),
          const SizedBox(height: Space.s),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            DifficultyBadge(item.difficulty),
            EDTag(icon: cat.icon, label: context.loc(cat.title)),
            EDTag(icon: Icons.gesture_rounded, label: context.loc(refStyles[item.style] ?? refStyles['line']!)),
          ]),
          const SizedBox(height: Space.l),
          EDButton(expand: true, icon: Icons.photo_camera_outlined, label: context.tr('action.useCamera', 'Use in Camera'), onPressed: () => openCamera(context, src)),
          const SizedBox(height: Space.s),
          Row(children: [
            Expanded(child: EDButton.secondary(compact: true, icon: Icons.wb_sunny_outlined, label: context.tr('action.traceShort', 'Trace'), onPressed: () => openTrace(context, src))),
            const SizedBox(width: Space.xs),
            Expanded(
              child: EDButton.secondary(
                compact: true,
                icon: item.isColoringPage ? Icons.format_paint_outlined : Icons.brush_outlined,
                label: item.isColoringPage ? context.tr('action.colorShort', 'Color') : context.tr('action.canvasShort', 'Canvas'),
                onPressed: () => openCanvas(context, reference: src),
              ),
            ),
          ]),
          const SizedBox(height: Space.xs),
          EDButton.ghost(
            icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: fav ? context.tr('action.unfavorite', 'Remove from favorites') : context.tr('action.favorite', 'Favorite'),
            onPressed: () => content.toggleFavorite('lib:${item.id}'),
          ),
        ]);
      },
    );

    return Scaffold(
      appBar: EDTopBar(title: title),
      body: SafeArea(
        top: false,
        child: landscape
            ? Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: preview),
                  const SizedBox(width: Space.m),
                  Expanded(child: SingleChildScrollView(child: actions)),
                ]),
              )
            : ListView(padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.xl), children: [
                AspectRatio(aspectRatio: 1, child: preview),
                const SizedBox(height: Space.l),
                actions,
              ]),
      ),
    );
  }
}
