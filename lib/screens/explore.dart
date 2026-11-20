import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'lessons.dart';
import 'nav.dart';
import 'reference_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, animationDuration: Motion.base);

  void showTab(int i) => _tabs.animateTo(i);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('nav.explore', 'Explore'),
        large: true,
        showBack: false,
        bottom: EDTabs(controller: _tabs, labels: [
          (Icons.collections_outlined, context.tr('explore.refs', 'References')),
          (Icons.school_outlined, context.tr('explore.lessons', 'Lessons')),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: const [LibraryView(), LessonsView()]),
    );
  }
}

/// Searchable, filterable reference library.
class LibraryView extends StatefulWidget {
  const LibraryView({super.key, this.onPick});

  /// When set, tapping a card returns it instead of opening details.
  final ValueChanged<ReferenceItem>? onPick;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String? _category;
  Difficulty? _difficulty;
  String? _style;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _filterCount => (_difficulty != null ? 1 : 0) + (_style != null ? 1 : 0);

  void _clearAll() => setState(() {
        _search.clear();
        _category = null;
        _difficulty = null;
        _style = null;
      });

  Future<void> _openFilters() async {
    await showEDSheet<void>(
      context,
      title: context.tr('filter.title', 'Filters'),
      builder: (c) => StatefulBuilder(builder: (c, setSheet) {
        void upd(VoidCallback f) {
          setState(f);
          setSheet(() {});
        }

        final t = c.text;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('filter.difficulty', 'Difficulty').toUpperCase(), style: t.overline),
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.xs, children: [
            EDChip(label: context.tr('filter.any', 'Any'), selected: _difficulty == null, onTap: () => upd(() => _difficulty = null)),
            for (final d in Difficulty.values)
              EDChip(label: difficultyLabel(context, d), selected: _difficulty == d, onTap: () => upd(() => _difficulty = d)),
          ]),
          const SizedBox(height: Space.l),
          Text(context.tr('filter.style', 'Drawing style').toUpperCase(), style: t.overline),
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.xs, children: [
            EDChip(label: context.tr('filter.any', 'Any'), selected: _style == null, onTap: () => upd(() => _style = null)),
            for (final s in refStyles.entries)
              EDChip(label: context.loc(s.value), selected: _style == s.key, onTap: () => upd(() => _style = s.key)),
          ]),
          const SizedBox(height: Space.l),
          Row(children: [
            Expanded(
              child: EDButton.secondary(
                label: context.tr('filter.clear', 'Clear filters'),
                onPressed: _filterCount == 0 ? null : () => upd(() {
                      _difficulty = null;
                      _style = null;
                    }),
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(child: EDButton(label: context.tr('filter.show', 'Show results'), onPressed: () => Navigator.pop(c))),
          ]),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = context.content;
    final p = context.ds;
    final t = context.text;
    if (content.loadFailed) {
      return EDStateView(
        icon: Icons.error_outline_rounded,
        tone: EDStateTone.error,
        title: context.tr('lib.errorTitle', 'The library couldn’t be loaded'),
        message: context.tr('lib.errorBody', 'Something went wrong reading the built-in references. Restarting the app usually fixes this. Your own art is not affected.'),
      );
    }
    final results = content.query(text: _search.text, category: _category, difficulty: _difficulty, style: _style);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, 0),
          child: Row(children: [
            Expanded(
              child: EDTextField(
                controller: _search,
                hint: context.tr('lib.search', 'Search references'),
                prefixIcon: Icons.search_rounded,
                clearable: true,
                clearTooltip: context.tr('common.clear', 'Clear'),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: Space.xs),
            Stack(clipBehavior: Clip.none, children: [
              EDIconButton(
                icon: Icons.tune_rounded,
                variant: EDIconVariant.outline,
                selected: _filterCount > 0,
                tooltip: context.tr('filter.title', 'Filters'),
                onPressed: _openFilters,
              ),
              if (_filterCount > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: p.text, borderRadius: Radii.tagR),
                    child: Text('$_filterCount', style: t.caption.copyWith(color: p.bg, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: context.scaled(28) + 36,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xxs),
            scrollDirection: Axis.horizontal,
            children: [
              EDChip(label: context.tr('filter.all', 'All'), selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final c in refCategories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.xs),
                  child: EDChip(
                    icon: c.icon,
                    label: context.loc(c.title),
                    selected: _category == c.id,
                    onTap: () => setState(() => _category = _category == c.id ? null : c.id),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xxs, Space.m, Space.xs),
          child: Semantics(
            liveRegion: true,
            child: Text(context.trf('lib.count', '{n} references', {'n': results.length}), style: t.caption),
          ),
        ),
      ),
      if (results.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EDStateView(
            icon: Icons.search_off_rounded,
            title: context.tr('lib.none', 'No matches'),
            message: context.tr('lib.noneBody', 'Try another word, or clear the filters.'),
            actionLabel: context.tr('filter.clear', 'Clear filters'),
            onAction: _clearAll,
          ),
        )
      else
        SliverLayoutBuilder(builder: (context, constraints) {
          final width = constraints.crossAxisExtent - Space.m * 2;
          final cols = (width / 180).floor().clamp(2, 6);
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: Space.s,
                mainAxisSpacing: Space.s,
                mainAxisExtent: refCardExtent(context, width, cols),
              ),
              delegate: SliverChildBuilderDelegate(
                (c, i) => RefCard(
                  item: results[i],
                  onTap: () => widget.onPick != null ? widget.onPick!(results[i]) : push(context, ReferenceDetailScreen(item: results[i])),
                ),
                childCount: results.length,
              ),
            ),
          );
        }),
    ]);
  }
}

/// Card height = square artwork + text block (scales with text size), so
/// every card has the same proportions and nothing clips.
double refCardExtent(BuildContext context, double width, int cols) {
  final w = (width - Space.s * (cols - 1)) / cols;
  return w + context.scaled(22) + context.scaled(20) + Space.s * 3 + 4;
}
