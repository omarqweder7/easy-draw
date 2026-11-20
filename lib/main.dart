import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/scope.dart';
import 'app/settings.dart';
import 'app/theme.dart';
import 'data/art_store.dart';
import 'data/content_repo.dart';
import 'design/design.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final content = ContentRepo(prefs);
  final art = ArtStore();
  await Future.wait([content.load(), art.init()]);
  PaintingBindingHelper.evictor = (File f) => FileImage(f).evict();
  runApp(EasyDrawApp(settings: settings, content: content, art: art));
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EasyDrawApp extends StatelessWidget {
  const EasyDrawApp({super.key, required this.settings, required this.content, required this.art, this.home});

  final AppSettings settings;
  final ContentRepo content;
  final ArtStore art;

  /// Overrides the start screen (used by layout tests).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      content: content,
      art: art,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          Haptics.enabled = settings.haptics;
          return MaterialApp(
            title: 'Easy Draw',
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootMessengerKey,
            theme: EDTheme.build(EDPalette.light, 'en'),
            darkTheme: EDTheme.build(EDPalette.dark, 'en'),
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('ar'), Locale('he')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            localeResolutionCallback: (locale, supported) {
              for (final s in supported) {
                if (s.languageCode == locale?.languageCode) return s;
              }
              return const Locale('en');
            },
            builder: (context, child) {
              // Rebuild the theme for the active language so Arabic uses Cairo
              // and Hebrew uses Rubik, and honour the in-app reduce-motion switch.
              final mq = MediaQuery.of(context);
              final lang = Localizations.localeOf(context).languageCode;
              final dark = switch (settings.themeMode) {
                ThemeMode.dark => true,
                ThemeMode.light => false,
                ThemeMode.system => mq.platformBrightness == Brightness.dark,
              };
              final palette = dark ? EDPalette.dark : EDPalette.light;
              return Theme(
                data: EDTheme.build(palette, lang),
                child: MediaQuery(
                  data: mq.copyWith(disableAnimations: mq.disableAnimations || settings.reduceMotion),
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                      systemNavigationBarColor: palette.surface,
                      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                    ),
                    child: child!,
                  ),
                ),
              );
            },
            home: home ?? (settings.onboardingDone ? const AppShell() : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}
