import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'art_detail.dart';
import 'canvas/canvas_screen.dart';
import 'nav.dart';

String artTypeLabel(BuildContext context, ArtType t) => switch (t) {
  ArtType.project => context.tr('art.project', 'Project'),
  ArtType.capture => context.tr('art.capture', 'Capture'),
  ArtType.recording => context.tr('art.recording', 'Recording'),
  ArtType.imported => context.tr('art.imported', 'Imported'),
  ArtType.sketch => context.tr('art.sketch', 'Sketch'),
  ArtType.textArt => context.tr('art.textArt', 'Text art'),
  ArtType.export => context.tr('art.export', 'Drawing'),
};

IconData artTypeIcon(ArtType t) => switch (t) {
  ArtType.project => Icons.brush_rounded,
  ArtType.capture => Icons.photo_camera_rounded,
  ArtType.recording => Icons.videocam_rounded,
  ArtType.imported => Icons.image_rounded,
  ArtType.sketch => Icons.auto_fix_high_rounded,
  ArtType.textArt => Icons.text_fields_rounded,
  ArtType.export => Icons.palette_rounded,
};

class MyArtScreen extends StatefulWidget {
  const MyArtScreen({super.key});

  @override
  State<MyArtScreen> createState() => _MyArtScreenState();
}

class _MyArtScreenState extends State<MyArtScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final art = context.art;
    final filters = <(String, String)>[
      ('all', context.tr('filter.all', 'All')),
      ('fav', context.tr('home.favorites', 'Favorites')),
      ('project', context.tr('art.projects', 'Projects')),
      ('capture', context.tr('art.captures', 'Captures')),
      ('recording', context.tr('art.recordings', 'Recordings')),
      ('imported', context.tr('art.imports', 'Imports')),
      ('sketch', context.tr('art.sketches', 'Sketches')),
      ('textArt', context.tr('art.textArt', 'Text art')),
      ('export', context.tr('art.exports', 'Drawings')),
    ];
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('nav.myArt', 'My Art'),
        large: true,
        showBack: false,
      ),
      body: ListenableBuilder(
        listenable: art,
        builder: (context, _) {
          final all = art.items;
          final items = all.where((i) {
            if (_filter == 'all') return true;
            if (_filter == 'fav') return i.favorite;
            return i.type.name == _filter;
          }).toList();
          return Column(
            children: [
              SizedBox(
                height: context.scaled(64),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in filters)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: EDChip(
                          label: f.$2,
                          selected: _filter == f.$1,
                          onTap: () => setState(() => _filter = f.$1),
                        ),
                      ),
                  ],
                ),
              ),
              if (art.loadError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.tr(
                      'art.loadError',
                      'Some saved items could not be read. A backup copy was used where possible.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? (all.isEmpty
                          ? EDStateView(
                              icon: Icons.palette_outlined,
                              title: context.tr(
                                'art.empty',
                                'Your gallery is empty',
                              ),
                              message: context.tr(
                                'art.emptyBody',
                                'Captures of your paper drawings, canvas projects, sketches and recordings are saved here on your device.',
                              ),
                              actionLabel: context.tr(
                                'home.start',
                                'Start Drawing',
                              ),
                              onAction: () => openCamera(context),
                            )
                          : EDStateView(
                              icon: Icons.filter_alt_off_rounded,
                              title: context.tr(
                                'art.emptyFilter',
                                'Nothing here yet',
                              ),
                              message: context.tr(
                                'art.emptyFilterBody',
                                'No items match this filter.',
                              ),
                              actionLabel: context.tr(
                                'filter.showAll',
                                'Show all',
                              ),
                              onAction: () => setState(() => _filter = 'all'),
                            ))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 160 + context.scaled(88),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: items.length,
                        itemBuilder: (c, i) => ArtCard(item: items[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ArtCard extends StatelessWidget {
  const ArtCard({super.key, required this.item});
  final ArtItem item;

  @override
  Widget build(BuildContext context) {
    final art = context.art;
    final thumb = art.thumbOf(item);
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat.yMMMd(context.lang).format(item.modified);
    return EDCard(
      onTap: () => item.type == ArtType.project
          ? push(context, CanvasScreen(project: item))
          : push(context, ArtDetailScreen(item: item)),
      onLongPress: () => push(context, ArtDetailScreen(item: item)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: item.type == ArtType.recording
                      ? const Color(0xFF1A2124)
                      : Colors.white,
                  child: item.type == ArtType.recording
                      ? const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 56,
                          color: Colors.white70,
                        )
                      : thumb == null
                      ? Icon(
                          artTypeIcon(item.type),
                          size: 40,
                          color: Colors.black26,
                        )
                      : Image.file(
                          thumb,
                          fit: BoxFit.contain,
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) => const MissingFile(),
                        ),
                ),
                PositionedDirectional(
                  bottom: 6,
                  start: 6,
                  end: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: Radii.tagR,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          artTypeIcon(item.type),
                          size: 13,
                          color: cs.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            artTypeLabel(context, item.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (item.favorite)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: context.ds.accentText,
                      semanticLabel: context.tr('home.favorites', 'Favorites'),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                EDIconButton(
                  tooltip: context.tr('art.more', 'More options'),
                  onPressed: () => push(context, ArtDetailScreen(item: item)),
                  icon: Icons.more_vert_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
