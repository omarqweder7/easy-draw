import 'dart:math';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'art_detail.dart';
import 'canvas/canvas_screen.dart';
import 'lessons.dart';
import 'nav.dart';
import 'reference_detail.dart';
import 'settings_screen.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final art = context.art;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Watch(
          listenables: [content, art],
          builder: (context) {
            final projects = art.items.where((i) => i.type == ArtType.project && !i.finished).toList();
            final featured = content.references.where((r) => r.featured).toList();
            final beginner = content.lessons.where((l) => l.difficulty == Difficulty.easy).toList();
            final recents = _resolve(context, content.recents);
            final favorites = _resolve(context, content.favorites.toList());
            final wide = MediaQuery.sizeOf(context).width >= 600;
            return CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(child: _Hero(featured: featured)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: _ImportCard()),
                        const SizedBox(width: Space.s),
                        Expanded(child: _BrowseCard(featured: featured)),
                      ]),
                    ),
                    const SizedBox(height: Space.s),
                    _ContinueCard(project: projects.isEmpty ? null : projects.first, more: projects.length > 1),
                  ]),
                ),
              ),
              SliverToBoxAdapter(child: EDSectionHeader(context.tr('home.tools', 'More ways to draw'))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                sliver: SliverToBoxAdapter(
                  child: EDGroup(children: [
                    EDListRow(
                      icon: Icons.wb_sunny_outlined,
                      title: context.tr('tool.trace', 'Trace Mode'),
                      subtitle: context.tr('tool.traceDesc', 'Show a reference on a bright screen and trace it through thin paper.'),
                      chevron: true,
                      onTap: () => openTrace(context),
                    ),
                    EDListRow(
                      icon: Icons.auto_fix_high_outlined,
                      title: context.tr('tool.sketch', 'Photo to Sketch'),
                      subtitle: context.tr('tool.sketchDesc', 'Turn a photo into outlines, pencil shading or bold black and white.'),
                      chevron: true,
                      onTap: () => photoToSketchFlow(context),
                    ),
                    EDListRow(
                      icon: Icons.text_fields_rounded,
                      title: context.tr('tool.text', 'Text Art'),
                      subtitle: context.tr('tool.textDesc', 'Type a name or quote and trace beautiful letters. Arabic and Hebrew supported.'),
                      chevron: true,
                      onTap: () => openTextArt(context),
                    ),
                    EDListRow(
                      icon: Icons.brush_outlined,
                      title: context.tr('tool.canvas', 'Digital Canvas'),
                      subtitle: context.tr('tool.canvasDesc', 'Draw and color on screen with brushes, layers and undo.'),
                      chevron: true,
                      onTap: () => openCanvas(context),
                    ),
                  ]),
                ),
              ),
              if (beginner.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: EDSectionHeader(context.tr('home.lessons', 'Beginner lessons'),
                      actionLabel: context.tr('common.seeAll', 'See all'), onAction: () => AppShell.goTo(context, 1, exploreTab: 1)),
                ),
                SliverToBoxAdapter(
                  child: _HList(
                    height: 168 + context.scaled(64),
                    children: [for (final l in beginner) LessonCard(lesson: l, width: wide ? 200 : 168)],
                  ),
                ),
              ],
              if (recents.isNotEmpty) ...[
                SliverToBoxAdapter(child: EDSectionHeader(context.tr('home.recent', 'Recently used'))),
                SliverToBoxAdapter(child: _HList(height: 112 + context.scaled(40), children: [for (final r in recents) _SourceTile(src: r)])),
              ],
              if (favorites.isNotEmpty) ...[
                SliverToBoxAdapter(child: EDSectionHeader(context.tr('home.favorites', 'Favorites'))),
                SliverToBoxAdapter(child: _HList(height: 112 + context.scaled(40), children: [for (final r in favorites) _SourceTile(src: r)])),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.m, Space.xl, Space.m, Space.xl),
                  child: Row(children: [
                    Icon(Icons.verified_outlined, size: 18, color: context.ds.textMuted),
                    const SizedBox(width: Space.xs),
                    Expanded(child: Text(context.tr('home.free', 'Easy Draw is completely free: no ads, no accounts, no locked features.'), style: context.text.caption)),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  List<RefSource> _resolve(BuildContext context, List<String> ids) {
    final out = <RefSource>[];
    for (final id in ids) {
      if (id.startsWith('lib:')) {
        final r = context.content.referenceById(id.substring(4));
        if (r != null) out.add(r.toSource());
      } else {
        final s = context.art.sourceFor(id);
        if (s != null) out.add(s); // null when the file is missing
      }
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.xs),
      child: Row(children: [
        ClipRRect(borderRadius: Radii.controlR, child: Image.asset('assets/brand/logo.png', width: 40, height: 40, excludeFromSemantics: true)),
        const SizedBox(width: Space.s),
        Expanded(child: Semantics(header: true, child: Text('Easy Draw', style: t.headline))),
        EDIconButton(
          icon: Icons.settings_outlined,
          variant: EDIconVariant.outline,
          tooltip: context.tr('settings.title', 'Settings'),
          onPressed: () => push(context, const SettingsScreen()),
        ),
      ]),
    );
  }
}

/// Hero: a "camera view" mock-up showing real reference art inside the
/// viewfinder corners, the headline, and the dominant Start drawing action.
class _Hero extends StatelessWidget {
  const _Hero({required this.featured});
  final List<ReferenceItem> featured;

  @override
  Widget build(BuildContext context) {
    const g = EDPalette.dark; // the hero is always graphite, like the camera
    final t = context.text;
    final art = featured.where((r) => r.id == 'mountains').firstOrNull ?? featured.firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sheet),
          border: Border.all(color: g.border),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color(0xFF26312A), Color(0xFF151B1F), Color(0xFF101418)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Viewfinder preview.
          SizedBox(
            height: 188,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _HeroBackdrop())),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
                  child: ViewfinderCorners(
                    color: g.accent,
                    length: 22,
                    stroke: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.m),
                      child: art == null ? const SizedBox() : Semantics(
                        image: true,
                        label: context.trf('home.heroArt', 'Example: {name} shown over the camera view', {'name': context.loc(art.title)}),
                        child: SvgPicture.asset(
                          art.asset,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(Color(0xE6F4F7F5), BlendMode.srcIn),
                          placeholderBuilder: (_) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Section tag sits above the headline (it used to overlap the
              // viewfinder bracket).
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: g.accent, borderRadius: BorderRadius.circular(1))),
                const SizedBox(width: Space.xs),
                Flexible(child: Text(context.tr('home.heroTag', 'Camera tracing').toUpperCase(), style: t.overline.copyWith(color: g.accent))),
              ]),
              const SizedBox(height: Space.xs),
              Text(context.tr('home.heroTitle', 'Draw it on real paper'), style: t.display.copyWith(color: g.text)),
              const SizedBox(height: Space.xs),
              Text(context.tr('home.heroBody', 'See a reference over your camera view, then follow the lines with your pencil.'),
                  style: t.body.copyWith(color: g.textMuted)),
              const SizedBox(height: Space.l),
              EDButton(
                label: context.tr('home.start', 'Start Drawing'),
                icon: Icons.photo_camera_outlined,
                expand: true,
                dark: true,
                onPressed: () => openCamera(context),
              ),
              const SizedBox(height: Space.xs),
              EDButton.ghost(
                label: context.tr('home.howItWorks', 'How the setup works'),
                icon: Icons.menu_book_outlined,
                dark: true,
                onPressed: () => push(context, const SetupGuideScreen()),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Faint tilted "paper" under the camera, like the app icon.
class _HeroBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 6);
    canvas.rotate(-0.06);
    final r = Rect.fromCenter(center: Offset.zero, width: min(size.width * 0.62, 320), height: size.height * 0.78);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = const Color(0xFF252E36));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroBackdrop old) => false;
}

class _ImportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final p = context.ds;
    final sample = context.content.referenceById('portrait');
    return EDCard(
      onTap: () => importPhotoFlow(context),
      semanticLabel: context.tr('tool.import', 'Import Photo'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: Stack(fit: StackFit.expand, children: [
            if (sample != null) RefThumb(sample.toSource(), padding: Space.s) else ColoredBox(color: p.paper),
            PositionedDirectional(
              bottom: Space.xs,
              end: Space.xs,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: p.accent, borderRadius: Radii.controlR),
                child: Icon(Icons.add_photo_alternate_outlined, color: p.onAccent, size: 20),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('tool.import', 'Import Photo'), style: t.titleSm),
            const SizedBox(height: Space.xxs),
            Text(context.tr('home.importBody', 'Use your own picture'), style: t.caption),
          ]),
        ),
      ]),
    );
  }
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({required this.featured});
  final List<ReferenceItem> featured;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final p = context.ds;
    final picks = featured.where((r) => r.id != 'mountains').take(4).toList();
    return EDCard(
      onTap: () => AppShell.goTo(context, 1, exploreTab: 0),
      semanticLabel: context.tr('home.browse', 'Browse references'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: ColoredBox(
            color: p.border,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              childAspectRatio: 1.25,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final r in picks) RefThumb(r.toSource(), padding: Space.xs)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('home.browse', 'Browse references'), style: t.titleSm),
            const SizedBox(height: Space.xxs),
            Text(context.tr('home.browseBody', 'Animals, cars, portraits & more'), style: t.caption),
          ]),
        ),
      ]),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.project, required this.more});
  final ArtItem? project;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final p = context.ds;
    final thumb = project == null ? null : context.art.thumbOf(project!);
    return EDCard(
      onTap: () => project == null ? openCanvas(context) : push(context, CanvasScreen(project: project)),
      semanticLabel: project == null ? context.tr('home.newCanvas', 'New canvas') : context.trf('home.continueNamed', 'Continue {name}', {'name': project!.title}),
      child: Row(children: [
        SizedBox(
          width: 96,
          height: 96,
          child: thumb == null
              ? ColoredBox(color: p.elevated, child: Icon(Icons.brush_outlined, color: p.textMuted, size: 32))
              : ColoredBox(color: p.paper, child: Image.file(thumb, fit: BoxFit.contain, errorBuilder: (_, _, _) => const MissingFile())),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('home.continue', 'Continue creating').toUpperCase(), style: t.overline),
              const SizedBox(height: Space.xxs),
              Text(project?.title ?? context.tr('home.newCanvas', 'New canvas'), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
              const SizedBox(height: Space.xxs),
              Text(
                project == null
                    ? context.tr('home.noProjects', 'Canvas projects you start will appear here so you can pick up where you left off.')
                    : context.tr('home.continueBody', 'Pick up where you left off'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.caption,
              ),
            ]),
          ),
        ),
        if (more)
          EDIconButton(icon: Icons.collections_outlined, tooltip: context.tr('common.seeAll', 'See all'), onPressed: () => AppShell.goTo(context, 3))
        else
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.m),
            child: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.textFaint),
          ),
      ]),
    );
  }
}

class _HList extends StatelessWidget {
  const _HList({required this.height, required this.children});
  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: Space.s),
          itemBuilder: (_, i) => children[i],
        ),
      );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.src});
  final RefSource src;

  @override
  Widget build(BuildContext context) {
    final id = src.refId ?? '';
    final title = id.startsWith('lib:') ? context.loc(context.content.referenceById(id.substring(4))!.title) : src.title;
    void open() {
      if (id.startsWith('lib:')) {
        final r = context.content.referenceById(id.substring(4));
        if (r != null) push(context, ReferenceDetailScreen(item: r));
      } else if (id.startsWith('art:')) {
        final item = context.art.byId(id.substring(4));
        if (item != null) push(context, ArtDetailScreen(item: item));
      }
    }

    return SizedBox(
      width: 112,
      child: EDCard(
        onTap: open,
        semanticLabel: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 104, child: RefThumb(src, padding: Space.xs)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSm),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
