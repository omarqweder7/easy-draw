import 'package:material_ui/material_ui.dart';

import '../app/l10n.dart';
import '../app/scope.dart';
import '../app/settings.dart';
import '../data/models.dart';
import '../services/share_service.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'onboarding.dart';
import 'text_art.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('settings.title', 'Settings'),
        large: true,
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            EDGroup(
              title: context.tr('settings.appearance', 'Appearance'),
              description: context.tr(
                'settings.appearanceHint',
                'Make this space your own.',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: EDSegmented<ThemeMode>(
                    segments: [
                      EDSegment(
                        ThemeMode.system,
                        context.tr('settings.system', 'System'),
                      ),
                      EDSegment(
                        ThemeMode.light,
                        context.tr('settings.light', 'Light'),
                      ),
                      EDSegment(
                        ThemeMode.dark,
                        context.tr('settings.dark', 'Dark'),
                      ),
                    ],
                    value: s.themeMode,
                    onChanged: (v) => s.update((x) => x.themeMode = v),
                  ),
                ),
                EDDropdown<String>(
                  label: context.tr('settings.language', 'Language'),
                  icon: Icons.language_rounded,
                  value: s.language ?? 'system',
                  options: [
                    (
                      'system',
                      context.tr('settings.langSystem', 'Device language'),
                    ),
                    ('en', 'English'),
                    ('ar', 'العربية'),
                    ('he', 'עברית'),
                  ],
                  onChanged: (v) =>
                      s.update((x) => x.language = v == 'system' ? null : v),
                ),
              ],
            ),
            EDGroup(
              title: context.tr('settings.access', 'Accessibility & layout'),
              children: [
                EDSwitchRow(
                  icon: Icons.motion_photos_off_rounded,
                  title: context.tr('settings.motion', 'Reduce motion'),
                  subtitle: context.tr(
                    'settings.motionHint',
                    'Turns off page and panel animations. Also follows your device setting.',
                  ),
                  value: s.reduceMotion,
                  onChanged: (v) => s.update((x) => x.reduceMotion = v),
                ),
                EDSwitchRow(
                  icon: Icons.vibration_rounded,
                  title: context.tr('settings.haptics', 'Haptic feedback'),
                  subtitle: context.tr(
                    'settings.hapticsHint',
                    'Gentle vibrations when you use drawing controls.',
                  ),
                  value: s.haptics,
                  onChanged: (v) => s.update((x) => x.haptics = v),
                ),
                EDListRow(
                  icon: Icons.back_hand_rounded,
                  title: context.tr('settings.hand', 'Drawing hand'),
                  subtitle: context.tr(
                    'settings.handHint',
                    "Workspace toolbars move to the opposite side so your hand doesn't cover them.",
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: EDSegmented<Handedness>(
                    segments: [
                      EDSegment(
                        Handedness.right,
                        context.tr('settings.rightHand', 'Right-handed'),
                      ),
                      EDSegment(
                        Handedness.left,
                        context.tr('settings.leftHand', 'Left-handed'),
                      ),
                    ],
                    value: s.handedness,
                    onChanged: (v) => s.update((x) => x.handedness = v),
                  ),
                ),
              ],
            ),
            EDGroup(
              title: context.tr('settings.defaults', 'Drawing defaults'),
              description: context.tr(
                'settings.defaultsHint',
                'Your starting point for every new drawing.',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      EDSlider(
                        label: context.tr('ov.opacity', 'Opacity'),
                        value: s.defaultOpacity,
                        min: 0.1,
                        max: 1,
                        valueText: '${(s.defaultOpacity * 100).round()}%',
                        onChanged: (v) => s.update((x) => x.defaultOpacity = v),
                      ),
                      EDSlider(
                        label: context.tr('canvas.size', 'Size'),
                        value: s.defaultBrushSize,
                        min: 1,
                        max: 60,
                        valueText: s.defaultBrushSize.round().toString(),
                        onChanged: (v) =>
                            s.update((x) => x.defaultBrushSize = v),
                      ),
                    ],
                  ),
                ),
                EDSwitchRow(
                  icon: Icons.grid_on_rounded,
                  title: context.tr(
                    'settings.grid',
                    'Show grid in Camera Drawing',
                  ),
                  value: s.defaultGrid,
                  onChanged: (v) => s.update((x) => x.defaultGrid = v),
                ),
                EDSwitchRow(
                  icon: Icons.format_color_reset_rounded,
                  title: context.tr(
                    'settings.linesOnly',
                    'Start with "Lines only"',
                  ),
                  subtitle: context.tr(
                    'settings.linesOnlyHint',
                    'Hides white areas of the reference over the camera view.',
                  ),
                  value: s.defaultLinesOnly,
                  onChanged: (v) => s.update((x) => x.defaultLinesOnly = v),
                ),
                EDSwitchRow(
                  icon: Icons.mic_none_rounded,
                  title: context.tr('rec.audio', 'Include sound'),
                  subtitle: context.tr(
                    'rec.audioHint',
                    'Off by default. Turning it on asks for microphone access.',
                  ),
                  value: s.recordAudio,
                  onChanged: (v) => s.update((x) => x.recordAudio = v),
                ),
                EDSwitchRow(
                  icon: Icons.brightness_high_rounded,
                  title: context.tr(
                    'settings.traceBright',
                    'Max brightness in Trace Mode',
                  ),
                  value: s.traceMaxBrightness,
                  onChanged: (v) => s.update((x) => x.traceMaxBrightness = v),
                ),
              ],
            ),
            EDGroup(
              title: context.tr('settings.help', 'Help & privacy'),
              children: [
                EDListRow(
                  icon: Icons.menu_book_rounded,
                  title: context.tr('guide.title', 'Drawing setup guide'),
                  chevron: true,
                  onTap: () => push(context, const SetupGuideScreen()),
                ),
                EDListRow(
                  icon: Icons.replay_rounded,
                  title: context.tr(
                    'settings.replay',
                    'Show the introduction again',
                  ),
                  chevron: true,
                  onTap: () =>
                      push(context, const OnboardingScreen(replay: true)),
                ),
                EDListRow(
                  icon: Icons.privacy_tip_rounded,
                  title: context.tr('privacy.title', 'Permissions & privacy'),
                  chevron: true,
                  onTap: () => push(context, const PrivacyScreen()),
                ),
                EDListRow(
                  icon: Icons.storage_rounded,
                  title: context.tr('storage.title', 'Storage'),
                  chevron: true,
                  onTap: () => push(context, const StorageScreen()),
                ),
                EDListRow(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('about.title', 'About Easy Draw'),
                  chevron: true,
                  onTap: () => push(context, const AboutScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EDCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: Radii.controlR,
                ),
                child: Icon(icon, color: context.ds.accentText),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupGuideScreen extends StatelessWidget {
  const SetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EDTopBar(title: context.tr('guide.title', 'Drawing setup guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Para(
            Icons.phone_android_rounded,
            context.tr('guide.t1', 'Mount the phone'),
            context.tr(
              'guide.b1',
              'Use a phone stand, a tripod with a phone clamp, or rest the phone across a glass or two stacks of books. The rear camera should look straight down at the paper.',
            ),
          ),
          _Para(
            Icons.height_rounded,
            context.tr('guide.t2', 'Height'),
            context.tr(
              'guide.b2',
              'About 20–40 cm above the paper works well. Higher shows more paper; lower gives more detail.',
            ),
          ),
          _Para(
            Icons.wb_incandescent_rounded,
            context.tr('guide.t3', 'Light'),
            context.tr(
              'guide.b3',
              'Bright, even light without strong shadows helps. If your phone has a flashlight you can switch it on from the workspace.',
            ),
          ),
          _Para(
            Icons.push_pin_rounded,
            context.tr('guide.t4', 'Keep things still'),
            context.tr(
              'guide.b4',
              'Tape the paper to the table. Lock the reference only when everything is in place — it stays fixed on the screen, not on the paper.',
            ),
          ),
          _Para(
            Icons.visibility_rounded,
            context.tr('guide.t5', 'Draw while watching the screen'),
            context.tr(
              'guide.b5',
              'Look at the screen, not the paper, and follow the lines with your pencil. Hide the reference now and then to check your real drawing.',
            ),
          ),
          _Para(
            Icons.light_mode_rounded,
            context.tr('guide.t6', 'No stand? Try Trace Mode'),
            context.tr(
              'guide.b6',
              'Trace Mode shows the picture on a bright screen. Place thin paper on top and trace gently with a soft pencil — never with sharp tools or heavy pressure.',
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EDTopBar(
        title: context.tr('privacy.title', 'Permissions & privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Para(
            Icons.shield_rounded,
            context.tr('privacy.t0', 'Your art stays on your device'),
            context.tr(
              'privacy.b0',
              'Easy Draw has no accounts, ads, analytics or tracking. Projects, photos and settings are stored only on this device. The app makes no network requests.',
            ),
          ),
          _Para(
            Icons.photo_camera_rounded,
            context.tr(
              'privacy.t1',
              'Camera — asked when you open Camera Drawing',
            ),
            context.tr(
              'privacy.b1',
              'Used to show your paper under the reference, and to take photos and recordings when you press Capture or Record. Without it, you can still use Trace Mode and the Digital Canvas.',
            ),
          ),
          _Para(
            Icons.mic_rounded,
            context.tr('privacy.t2', 'Microphone — only if you turn on sound'),
            context.tr(
              'privacy.b2',
              'Recordings are silent by default. Easy Draw asks for the microphone only if you switch on “Include sound”.',
            ),
          ),
          _Para(
            Icons.photo_library_rounded,
            context.tr('privacy.t3', 'Photos'),
            context.tr(
              'privacy.b3',
              'Importing uses the system photo picker, which shares only the photo you choose. Saving to Photos may ask for permission to add images; you can always use Share instead.',
            ),
          ),
          _Para(
            Icons.share_rounded,
            context.tr('privacy.t4', 'Sharing'),
            context.tr(
              'privacy.b4',
              'Files leave the app only when you tap Share and pick a destination yourself.',
            ),
          ),
          _Para(
            Icons.auto_awesome_outlined,
            context.tr('privacy.t5', 'About AI'),
            context.tr(
              'privacy.b5',
              'Easy Draw doesn’t include AI image generation. Photo to Sketch uses classic image filters that run on your device.',
            ),
          ),
          const SizedBox(height: 8),
          EDButton.secondary(
            onPressed: openSystemSettings,
            icon: Icons.settings_rounded,
            label: context.tr(
              'privacy.manage',
              'Manage permissions in device Settings',
            ),
          ),
        ],
      ),
    );
  }
}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  int? _all, _videos, _projects, _temp;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final art = context.art;
    final all = await art.totalBytes();
    final v = await art.totalBytes((i) => i.type == ArtType.recording);
    final pr = await art.totalBytes((i) => i.type == ArtType.project);
    final t = await tempBytes();
    if (mounted) {
      setState(() {
        _all = all;
        _videos = v;
        _projects = pr;
        _temp = t;
      });
    }
  }

  String _fmt(int? b) => b == null ? '…' : formatBytes(b);

  @override
  Widget build(BuildContext context) {
    final art = context.art;
    return Scaffold(
      appBar: EDTopBar(title: context.tr('storage.title', 'Storage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EDCard(
            child: Column(
              children: [
                EDListRow(
                  icon: Icons.photo_library_rounded,
                  title: context.tr('storage.myArt', 'My Art total'),
                  trailing: Text(_fmt(_all)),
                ),
                EDListRow(
                  icon: Icons.brush_rounded,
                  title: context.tr('art.projects', 'Projects'),
                  trailing: Text(_fmt(_projects)),
                ),
                EDListRow(
                  icon: Icons.videocam_rounded,
                  title: context.tr('art.recordings', 'Recordings'),
                  trailing: Text(_fmt(_videos)),
                ),
                EDListRow(
                  icon: Icons.cleaning_services_rounded,
                  title: context.tr('storage.temp', 'Temporary files'),
                  trailing: Text(_fmt(_temp)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EDButton.secondary(
            onPressed: () async {
              await clearTemp();
              await _measure();
              if (context.mounted) {
                showSnack(
                  context.tr('storage.tempCleared', 'Temporary files cleared.'),
                );
              }
            },
            icon: Icons.cleaning_services_rounded,
            label: context.tr('storage.clearTemp', 'Clear temporary files'),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'storage.tempHint',
              'Safe to clear: these are leftover export and camera files. Your gallery is not affected.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          EDButton(
            variant: EDButtonVariant.danger,
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: context.tr(
                  'storage.delVideosTitle',
                  'Delete all recordings?',
                ),
                message: context.tr(
                  'storage.delVideosBody',
                  'Every recording in My Art will be permanently deleted. This can’t be undone.',
                ),
                confirmLabel: context.tr('common.delete', 'Delete'),
                destructive: true,
              );
              if (!ok) return;
              await art.deleteWhere((i) => i.type == ArtType.recording);
              await _measure();
            },
            icon: Icons.videocam_off_rounded,
            label: context.tr('storage.delVideos', 'Delete all recordings'),
          ),
          const SizedBox(height: 8),
          EDButton(
            variant: EDButtonVariant.danger,
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: context.tr(
                  'storage.delAllTitle',
                  'Delete everything in My Art?',
                ),
                message: context.tr(
                  'storage.delAllBody',
                  'All projects, captures, sketches, imports and recordings will be permanently deleted from this device. This can’t be undone.',
                ),
                confirmLabel: context.tr(
                  'storage.delAllConfirm',
                  'Delete everything',
                ),
                destructive: true,
              );
              if (!ok) return;
              await art.deleteWhere((_) => true);
              await _measure();
            },
            icon: Icons.delete_forever_rounded,
            label: context.tr('storage.delAll', 'Delete all My Art'),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EDTopBar(title: context.tr('about.title', 'About Easy Draw')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Para(
            Icons.volunteer_activism_rounded,
            context.tr('about.freeT', 'Free, for everyone'),
            context.tr(
              'about.freeB',
              'Every feature is free. There are no ads, subscriptions, purchases, credits or locked content, and no account is needed.',
            ),
          ),
          _Para(
            Icons.collections_rounded,
            context.tr('about.contentT', 'Starter content'),
            context.tr(
              'about.contentB',
              'All bundled references and lessons are original artwork made for Easy Draw.',
            ),
          ),
          _Para(
            Icons.font_download_rounded,
            context.tr('about.fontsT', 'Fonts'),
            '${traceFonts.map((f) => f.label).join(', ')} — SIL Open Font License 1.1.',
          ),
          Center(
            child: EDButton.ghost(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Easy Draw',
                applicationVersion: '1.0.0',
              ),
              label: context.tr('about.licenses', 'Open-source licenses'),
            ),
          ),
        ],
      ),
    );
  }
}
