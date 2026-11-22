import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'explore.dart';
import 'nav.dart';
import 'text_art.dart';

/// Full-screen chooser that returns a [RefSource].
Future<RefSource?> pickReference(BuildContext context, {required String title}) => push<RefSource>(context, ReferencePickerScreen(title: title));

class ReferencePickerScreen extends StatefulWidget {
  const ReferencePickerScreen({super.key, required this.title});
  final String title;

  @override
  State<ReferencePickerScreen> createState() => _ReferencePickerScreenState();
}

class _ReferencePickerScreenState extends State<ReferencePickerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, animationDuration: Motion.base);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EDTopBar(
        title: widget.title,
        bottom: EDTabs(controller: _tabs, labels: [
          (Icons.collections_outlined, context.tr('pick.library', 'Library')),
          (Icons.photo_library_outlined, context.tr('nav.myArt', 'My Art')),
          (Icons.favorite_border_rounded, context.tr('home.favorites', 'Favorites')),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, 0),
          child: Row(children: [
            Expanded(
              child: EDButton.secondary(
                compact: true,
                icon: Icons.add_photo_alternate_outlined,
                label: context.tr('tool.import', 'Import Photo'),
                onPressed: () async {
                  final src = await importReference(context);
                  if (src != null && context.mounted) Navigator.pop(context, src);
                },
              ),
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: EDButton.secondary(
                compact: true,
                icon: Icons.text_fields_rounded,
                label: context.tr('tool.text', 'Text Art'),
                onPressed: () async {
                  final src = await push<RefSource>(context, const TextArtScreen(pickMode: true));
                  if (src != null && context.mounted) Navigator.pop(context, src);
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            LibraryView(onPick: (r) => Navigator.pop(context, r.toSource())),
            const _MyArtPicker(),
            const _FavoritesPicker(),
          ]),
        ),
      ]),
    );
  }
}

Widget _grid(BuildContext context, int count, Widget Function(int) item) {
  return LayoutBuilder(builder: (context, c) {
    final width = c.maxWidth - Space.m * 2;
    final cols = (width / 180).floor().clamp(2, 6);
    return GridView.builder(
      padding: const EdgeInsets.all(Space.m),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: Space.s,
        mainAxisSpacing: Space.s,
        mainAxisExtent: refCardExtent(context, width, cols),
      ),
      itemCount: count,
      itemBuilder: (_, i) => item(i),
    );
  });
}

class _MyArtPicker extends StatelessWidget {
  const _MyArtPicker();

  @override
  Widget build(BuildContext context) {
    final art = context.art;
    final sources = <(ArtItem, RefSource)>[];
    for (final i in art.items.where((i) => i.isImage || i.type == ArtType.project)) {
      final s = art.sourceFor('art:${i.id}');
      if (s != null) sources.add((i, s)); // null when the file is missing
    }
    if (sources.isEmpty) {
      return EDStateView(
        icon: Icons.photo_library_outlined,
        title: context.tr('pick.noArt', 'Nothing in My Art yet'),
        message: context.tr('pick.noArtBody', 'Import a photo, convert a sketch or make text art and it will be available here.'),
      );
    }
    return _grid(context, sources.length, (i) {
      final (item, src) = sources[i];
      return EDCard(
        onTap: () => Navigator.pop(context, src),
        semanticLabel: item.title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 1, child: RefThumb(src, padding: Space.xs, thumbFile: art.thumbOf(item))),
          Padding(padding: const EdgeInsets.all(Space.s), child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.labelSm)),
        ]),
      );
    });
  }
}

class _FavoritesPicker extends StatelessWidget {
  const _FavoritesPicker();

  @override
  Widget build(BuildContext context) {
    final content = context.content;
    final favs = content.favorites.where((f) => f.startsWith('lib:')).map((f) => content.referenceById(f.substring(4))).whereType<ReferenceItem>().toList();
    if (favs.isEmpty) {
      return EDStateView(
        icon: Icons.favorite_border_rounded,
        title: context.tr('pick.noFav', 'No favorites yet'),
        message: context.tr('home.noFav', 'Tap the heart on any reference to keep it here.'),
      );
    }
    return _grid(context, favs.length, (i) => RefCard(item: favs[i], onTap: () => Navigator.pop(context, favs[i].toSource())));
  }
}
