import 'package:material_ui/material_ui.dart';

import '../data/art_store.dart';
import '../data/content_repo.dart';
import 'settings.dart';

/// Provides the app-wide services to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.settings, required this.content, required this.art, required super.child});

  final AppSettings settings;
  final ContentRepo content;
  final ArtStore art;

  static AppScope of(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

extension ScopeContext on BuildContext {
  AppSettings get settings => AppScope.of(this).settings;
  ContentRepo get content => AppScope.of(this).content;
  ArtStore get art => AppScope.of(this).art;
}

/// Rebuilds when any of the given listenables change.
class Watch extends StatelessWidget {
  const Watch({super.key, required this.listenables, required this.builder});
  final List<Listenable> listenables;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: Listenable.merge(listenables), builder: (c, _) => builder(c));
}
