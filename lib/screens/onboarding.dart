import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import 'shell.dart';
import '../design/design.dart';

/// Short, skippable introduction.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  /// When opened again from Settings it just closes at the end.
  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _finish() {
    context.settings.update((s) => s.onboardingDone = true);
    if (widget.replay) {
      Navigator.pop(context);
    } else {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = [
      (
        'assets/brand/onboard_1.svg',
        context.tr('ob.t1', 'Choose a reference'),
        context.tr(
          'ob.b1',
          'Pick a picture from the free library, import your own photo, or turn a photo into a sketch.',
        ),
      ),
      (
        'assets/brand/onboard_2.svg',
        context.tr('ob.t2', 'Set your phone above the paper'),
        context.tr(
          'ob.b2',
          'Use a stable phone stand, a glass or a stack of books so the camera looks straight down at your paper, about 20–40 cm above it.',
        ),
      ),
      (
        'assets/brand/onboard_3.svg',
        context.tr('ob.t3', 'Adjust the reference'),
        context.tr(
          'ob.b3',
          'Drag, pinch and rotate the picture until it fits the paper. Lower the opacity so you can see your pencil.',
        ),
      ),
      (
        'assets/brand/onboard_4.svg',
        context.tr('ob.t4', 'Lock it and draw'),
        context.tr(
          'ob.b4',
          'Lock the reference, then draw on the paper while looking at the screen. Keep the phone and paper still.',
        ),
      ),
    ];
    final last = _i == pages.length - 1;
    final dur = Motion.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: EDButton.ghost(
                  onPressed: _finish,
                  label: context.tr('ob.skip', 'Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (c, i) {
                  final pg = pages[i];
                  return LayoutBuilder(
                    builder: (context, box) {
                      final landscape = box.maxWidth > box.maxHeight;
                      final art = ExcludeSemantics(
                        child: SvgPicture.asset(pg.$1, fit: BoxFit.contain),
                      );
                      final text = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.trf('ob.step', 'Step {n} of {total}', {
                              'n': i + 1,
                              'total': pages.length,
                            }),
                            style: TextStyle(
                              color: context.ds.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            header: true,
                            child: Text(
                              pg.$2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            pg.$3,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                          if (i == 0 || i == 3) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: Radii.cardR,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: cs.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      i == 0
                                          ? context.tr(
                                              'ob.note',
                                              'Good to know: the picture appears on your phone screen. Your phone does not project anything onto the paper.',
                                            )
                                          : context.tr(
                                              'ob.note4',
                                              'Locking freezes the picture on the screen. It can’t follow the paper if the phone or paper moves.',
                                            ),
                                      style: TextStyle(
                                        color: cs.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: landscape
                            ? Row(
                                children: [
                                  Expanded(child: art),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: SingleChildScrollView(child: text),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: box.maxHeight * 0.42,
                                      child: art,
                                    ),
                                    const SizedBox(height: 24),
                                    text,
                                  ],
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                children: [
                  Semantics(
                    label: context.trf('ob.step', 'Step {n} of {total}', {
                      'n': _i + 1,
                      'total': pages.length,
                    }),
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        for (var k = 0; k < pages.length; k++)
                          AnimatedContainer(
                            duration: dur,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: k == _i ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: k == _i
                                  ? context.ds.accentText
                                  : context.ds.borderStrong,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EDButton(
                      onPressed: last
                          ? _finish
                          : () => _page.animateToPage(
                              _i + 1,
                              duration: dur == Duration.zero
                                  ? const Duration(milliseconds: 1)
                                  : dur,
                              curve: Curves.easeOut,
                            ),
                      label: last
                          ? context.tr('ob.start', 'Get started')
                          : context.tr('common.next', 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
