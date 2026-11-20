import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../design/design.dart';
import 'create.dart';
import 'explore.dart';
import 'home.dart';
import 'my_art.dart';

/// Main destinations: Home, Explore, Create, My Art. Bottom bar on phones,
/// side rail in wide landscape layouts. Tabs keep their state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static void goTo(BuildContext context, int index, {int? exploreTab}) =>
      context.findAncestorStateOfType<_AppShellState>()?.select(index, exploreTab: exploreTab);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _exploreKey = GlobalKey<ExploreScreenState>();
  late final _pages = [
    const HomeScreen(),
    ExploreScreen(key: _exploreKey),
    const CreateScreen(),
    const MyArtScreen(),
  ];

  void select(int i, {int? exploreTab}) {
    if (i != _index) setState(() => _index = i);
    if (exploreTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exploreKey.currentState?.showTab(exploreTab));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      EDNavItem(Icons.home_outlined, context.tr('nav.home', 'Home')),
      EDNavItem(Icons.grid_view_outlined, context.tr('nav.explore', 'Explore')),
      EDNavItem(Icons.add_box_outlined, context.tr('nav.create', 'Create')),
      EDNavItem(Icons.collections_outlined, context.tr('nav.myArt', 'My Art')),
    ];
    final size = MediaQuery.sizeOf(context);
    final useRail = size.width > 720 && size.width > size.height;
    final body = _FadeStack(index: _index, children: _pages);
    if (useRail) {
      return Scaffold(body: Row(children: [EDNavRail(items: items, index: _index, onSelect: select), Expanded(child: body)]));
    }
    return Scaffold(body: body, bottomNavigationBar: EDBottomNav(items: items, index: _index, onSelect: select));
  }
}

/// IndexedStack with a short cross-fade (skipped when motion is reduced).
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.fast);
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < children.length; i++)
        Offstage(
          offstage: i != index,
          child: TickerMode(
            enabled: i == index,
            child: AnimatedOpacity(opacity: i == index ? 1 : 0, duration: d, child: children[i]),
          ),
        ),
    ]);
  }
}
