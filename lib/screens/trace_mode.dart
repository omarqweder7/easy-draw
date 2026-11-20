import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../app/settings.dart';
import '../data/models.dart';
import '../services/ref_loader.dart';
import '../widgets/common.dart';
import '../widgets/overlay.dart';
import '../widgets/overlay_controls.dart';
import 'reference_picker.dart';

Widget traceScreenFor(RefSource s) => TraceModeScreen(source: s);

/// Shows a reference on a plain bright background (no camera) so it can be
/// traced through thin paper laid on the screen.
class TraceModeScreen extends StatefulWidget {
  const TraceModeScreen({super.key, required this.source});
  final RefSource source;

  @override
  State<TraceModeScreen> createState() => _TraceModeScreenState();
}

class _TraceModeScreenState extends State<TraceModeScreen> {
  static const _g = EDPalette.dark;

  late RefSource _source = widget.source;
  ui.Image? _ref;
  bool _failed = false;
  final _m = OverlayModel(opacity: 1, linesOnly: false);
  late final AppSettings _settings;
  double _bg = 1; // backdrop brightness 0..1
  bool _maxBrightness = true;
  bool _brightnessChanged = false;
  bool _showSafety = true;
  bool _panelOpen = true;

  @override
  void initState() {
    super.initState();
    _settings = context.settings;
    _maxBrightness = _settings.traceMaxBrightness;
    WakelockPlus.enable();
    _applyBrightness();
    _load();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _restoreBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _m.dispose();
    super.dispose();
  }

  Future<void> _applyBrightness() async {
    try {
      if (_maxBrightness) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
        _brightnessChanged = true;
      } else if (_brightnessChanged) {
        await _restoreBrightness();
      }
    } catch (_) {
      // Unsupported platform: keep going at the current brightness.
    }
  }

  Future<void> _restoreBrightness() async {
    if (!_brightnessChanged) return;
    _brightnessChanged = false;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final img = await loadRefImage(_source, maxSide: 2048);
      if (mounted) {
        setState(() {
          _ref?.dispose();
          _ref = img;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _lock() {
    _m.locked = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Haptics.confirm();
    setState(() {});
  }

  void _unlock() {
    _m.locked = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() {});
  }

  Future<void> _change() async {
    final src = await pickReference(context, title: context.tr('pick.change', 'Choose a different reference'));
    if (src == null || !mounted) return;
    context.content.markUsed(src.refId);
    _source = src;
    _m.resetAll();
    _m.opacity = 1;
    await _load();
  }

  void _help() {
    showStepsSheet(context, dark: true, title: context.tr('trace.helpTitle', 'How Trace Mode works'), steps: [
      context.tr('trace.help1', 'Adjust the reference, then tap Lock. Controls hide and touches are ignored so the paper can rest on the screen.'),
      context.tr('trace.help2', 'Lay a sheet of thin paper (printer, tracing or baking paper) over the screen. You may hold or tape it at the edges of the phone.'),
      context.tr('trace.help3', 'Trace gently with a soft pencil. Avoid pens with sharp tips, metal tools or pressing hard — they can scratch or damage the screen.'),
      context.tr('trace.help4', 'To unlock, press and hold the Unlock button for about 1.5 seconds. This prevents unlocking by accident.'),
      context.tr('trace.help5', 'Screen brightness returns to normal when you leave Trace Mode.'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final locked = _m.locked;
    final bgColor = Color.lerp(const Color(0xFF8A8F8C), Colors.white, _bg)!;
    final unlockRight = _settings.handedness == Handedness.left;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: Theme.of(context).copyWith(extensions: [_g, EDText.build(_g, context.lang)]),
        child: PopScope(
          canPop: !locked,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && locked) showSnack(context.tr('trace.unlockFirst', 'Hold the Unlock button to unlock before leaving.'));
          },
          child: Scaffold(
            backgroundColor: bgColor,
            body: Stack(children: [
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: locked,
                  child: _ref == null
                      ? (_failed
                          ? ColoredBox(
                              color: _g.bg,
                              child: EDStateView(
                                dark: true,
                                tone: EDStateTone.error,
                                icon: Icons.broken_image_outlined,
                                title: context.tr('cam.refFailed', 'This reference couldn’t be loaded.'),
                                message: context.tr('cam.refFailedBody', 'The file may have been moved or deleted.'),
                                actionLabel: context.tr('pick.change', 'Choose a different reference'),
                                onAction: _change,
                              ),
                            )
                          : const EDLoading())
                      : ReferenceOverlay(image: _ref!, model: _m, semanticLabel: context.trf('cam.refLabel', 'Reference: {name}', {'name': refTitle(context, _source)})),
                ),
              ),
              if (!locked) _topBar(),
              if (!locked && _showSafety) _safetyNote(),
              if (!locked) _panel(),
              if (locked)
                Positioned(
                  bottom: Space.m,
                  left: unlockRight ? null : Space.m,
                  right: unlockRight ? Space.m : null,
                  child: SafeArea(child: Opacity(opacity: 0.9, child: HoldToUnlockButton(duration: const Duration(milliseconds: 1500), onUnlocked: _unlock))),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: Container(
              padding: const EdgeInsets.all(Space.xxs),
              decoration: BoxDecoration(color: _g.panel, borderRadius: Radii.cardR, border: Border.all(color: _g.border)),
              child: Row(children: [
                EDIconButton(
                  dark: true,
                  icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: Space.xxs),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(context.tr('tool.trace', 'Trace Mode'), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSm),
                    Text(refTitle(context, _source), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.caption),
                  ]),
                ),
                EDIconButton(dark: true, icon: Icons.photo_library_outlined, tooltip: context.tr('pick.change', 'Choose a different reference'), onPressed: _change),
                EDIconButton(dark: true, icon: Icons.help_outline_rounded, tooltip: context.tr('common.help', 'Help'), onPressed: _help),
              ]),
            ),
          ),
        ),
      );

  Widget _safetyNote() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 72, Space.xs, 0),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xxs, Space.xxs, Space.xxs),
              decoration: BoxDecoration(color: _g.panel, borderRadius: Radii.cardR, border: Border.all(color: _g.warning.withValues(alpha: 0.6))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _g.warning, size: 20),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(context.tr('trace.safety', 'Place thin paper over the screen and trace gently with a soft pencil. Avoid sharp tools and pressing hard.'),
                      style: context.text.bodySm.copyWith(color: _g.text)),
                ),
                EDIconButton(dark: true, icon: Icons.close_rounded, tooltip: context.tr('common.dismiss', 'Dismiss'), onPressed: () => setState(() => _showSafety = false)),
              ]),
            ),
          ),
        ),
      );

  Widget _panel() {
    final dur = Motion.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.xs),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                decoration: BoxDecoration(color: _g.panel, borderRadius: BorderRadius.circular(Radii.sheet), border: Border.all(color: _g.border)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Pressable(
                    onTap: () => setState(() => _panelOpen = !_panelOpen),
                    semanticLabel: _panelOpen ? context.tr('panel.collapse', 'Collapse controls') : context.tr('panel.expand', 'Expand controls'),
                    excludeChildSemantics: true,
                    scale: 1,
                    builder: (context, s) => SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: Center(
                        child: AnimatedRotation(turns: _panelOpen ? 0 : 0.5, duration: dur, child: Icon(Icons.keyboard_arrow_down_rounded, color: _g.textMuted)),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: dur,
                    curve: Motion.curve,
                    alignment: Alignment.bottomCenter,
                    child: _panelOpen
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.xs),
                            child: Column(children: [
                              OverlaySliders(model: _m),
                              EDSlider(
                                dark: true,
                                dense: true,
                                icon: Icons.wb_sunny_outlined,
                                label: context.tr('trace.bg', 'Backdrop'),
                                value: _bg,
                                min: 0,
                                max: 1,
                                valueText: pct(_bg),
                                onChanged: (v) => setState(() => _bg = v),
                              ),
                              const SizedBox(height: Space.xs),
                              OverlayToolRow(model: _m, extra: [
                                EDToolButton(
                                  icon: Icons.brightness_high_outlined,
                                  label: context.tr('trace.maxBright', 'Max screen'),
                                  toggle: true,
                                  active: _maxBrightness,
                                  onPressed: () {
                                    setState(() => _maxBrightness = !_maxBrightness);
                                    _settings.update((s) => s.traceMaxBrightness = _maxBrightness);
                                    _applyBrightness();
                                  },
                                ),
                              ]),
                            ]),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.m),
                    child: EDButton(dark: true, expand: true, icon: Icons.lock_outline_rounded, label: context.tr('trace.lock', 'Lock & hide controls'), onPressed: _ref == null ? null : _lock),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
