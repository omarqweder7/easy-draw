import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_draw/app/settings.dart';
import 'package:easy_draw/data/art_store.dart';
import 'package:easy_draw/data/content_repo.dart';
import 'package:easy_draw/data/models.dart';
import 'package:easy_draw/design/design.dart';
import 'package:easy_draw/main.dart';
import 'package:easy_draw/screens/art_detail.dart';
import 'package:easy_draw/screens/create.dart';
import 'package:easy_draw/screens/explore.dart';
import 'package:easy_draw/screens/home.dart';
import 'package:easy_draw/screens/lessons.dart';
import 'package:easy_draw/screens/my_art.dart';
import 'package:easy_draw/screens/onboarding.dart';
import 'package:easy_draw/screens/reference_detail.dart';
import 'package:easy_draw/screens/settings_screen.dart';
import 'package:easy_draw/screens/text_art.dart';
import 'package:easy_draw/widgets/common.dart' show HoldToUnlockButton;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppSettings settings;
  late ContentRepo content;
  late ArtStore art;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings = AppSettings(prefs);
    content = ContentRepo(prefs);
    await content.load();
    expect(content.loadFailed, isFalse);
    root = await Directory.systemTemp.createTemp('easy_draw_layout_');
    // Populate the gallery without relying on camera or platform decoders.
    final items = [
      for (final type in ArtType.values)
        ArtItem(
          id: type.name,
          type: type,
          title: 'A long drawing title / رسمة جميلة',
          created: DateTime(2026, 11, 20),
          modified: DateTime(2026, 11, 20),
          favorite: true,
          file: '${type.name}.png',
        ),
    ];
    await File('${root.path}/items.json')
        .writeAsString(jsonEncode(items.map((i) => i.toJson()).toList()));
    art = ArtStore();
    await art.init(root: root);
  });

  tearDown(() async {
    settings.dispose();
    content.dispose();
    art.dispose();
    await root.delete(recursive: true);
  });

  testWidgets('haptics preference persists and controls shared feedback', (
    tester,
  ) async {
    settings.language = 'en';
    await tester.pumpWidget(
      EasyDrawApp(
        settings: settings,
        content: content,
        art: art,
        home: const SettingsScreen(),
      ),
    );
    final toggle = find.widgetWithText(EDSwitchRow, 'Haptic feedback');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(settings.haptics, isFalse);
    expect(Haptics.enabled, isFalse);
    final restored = AppSettings(await SharedPreferences.getInstance());
    expect(restored.haptics, isFalse);
    restored.dispose();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'compact unlock fits the 320dp action row with large Arabic text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      settings.language = 'ar';
      await tester.pumpWidget(
        EasyDrawApp(
          settings: settings,
          content: content,
          art: art,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    HoldToUnlockButton(
                      compact: true,
                      label: 'إلغاء القفل',
                      onUnlocked: () {},
                    ),
                    EDToolButton(
                      icon: Icons.visibility,
                      label: 'إخفاء',
                      onPressed: () {},
                    ),
                    const Spacer(),
                    EDIconButton(
                      icon: Icons.fiber_manual_record,
                      tooltip: 'تسجيل',
                      size: 52,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    EDIconButton(
                      icon: Icons.camera_alt,
                      tooltip: 'التقاط',
                      size: 60,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(HoldToUnlockButton)).width, 64);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(915, 412),
  ]) {
    for (final scale in [1.0, 1.3]) {
      for (final lang in ['en', 'ar']) {
        for (final mode in [ThemeMode.dark, ThemeMode.light]) {
          testWidgets('screen layouts $size / $scale / $lang / ${mode.name}', (
            tester,
          ) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            settings.language = lang;
            settings.themeMode = mode;
            settings.reduceMotion = true;
            final screens = <Widget>[
              const HomeScreen(),
              const ExploreScreen(),
              const CreateScreen(),
              const MyArtScreen(),
              const SettingsScreen(),
              const TextArtScreen(),
              LessonPlayerScreen(lesson: content.lessons.first),
              LessonDetailScreen(lesson: content.lessons.first),
              ReferenceDetailScreen(item: content.references.first),
              const OnboardingScreen(),
              const SetupGuideScreen(),
              const PrivacyScreen(),
              const AboutScreen(),
              ArtDetailScreen(
                item: art.items.firstWhere((i) => i.type == ArtType.textArt),
              ),
            ];
            for (final screen in screens) {
              await tester.pumpWidget(
                EasyDrawApp(
                  key: UniqueKey(),
                  settings: settings,
                  content: content,
                  art: art,
                  home: screen,
                ),
              );
              // Fixed pumps allow skeleton animations without pumpAndSettle timeouts.
              await tester.pump(const Duration(milliseconds: 500));
              expect(
                tester.takeException(),
                isNull,
                reason: '${screen.runtimeType} initial',
              );
              if (screen is ExploreScreen) {
                tester
                    .state<ExploreScreenState>(find.byType(ExploreScreen))
                    .showTab(1);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'Explore lessons tab',
                );
              }
              if (screen is SettingsScreen) {
                await tester.tap(find.byType(EDDropdown<String>));
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'Language sheet',
                );
                rootNavigatorKey.currentState!.pop();
                await tester.pumpAndSettle();
              }
              if (screen is OnboardingScreen) {
                for (var page = 1; page < 4; page++) {
                  final pv = tester.widget<PageView>(find.byType(PageView));
                  pv.controller!.jumpToPage(page);
                  await tester.pump();
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: 'Onboarding page $page',
                  );
                }
              }
              // Exercise content below the fold, where settings and text tools live.
              final scrolls = find.byType(Scrollable);
              for (final element in scrolls.evaluate().toList()) {
                final state =
                    (element as StatefulElement).state as ScrollableState;
                if (state.position.axis == Axis.vertical &&
                    state.position.hasContentDimensions) {
                  state.position.jumpTo(state.position.maxScrollExtent);
                }
              }
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: '${screen.runtimeType} scrolled',
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            }
          });
        }
      }
    }
  }
}
