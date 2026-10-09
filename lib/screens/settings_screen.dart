import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../config/ai_config.dart';
import '../data/models.dart';
import '../ui/components.dart';
import '../ui/profile.dart';
import '../ui/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: T.cream, surfaceTintColor: T.cream, title: Text('Ikaw ang may control.', style: T.h(20))),
      body: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
            Text('Everything stays on your device.', style: T.b(15, color: T.muted)),
            const SizedBox(height: 18),
            _group('Your places', [
              for (final p in s.places)
                _row(
                  leading: IconTile(Icons.place_outlined, size: 38),
                  title: p.name,
                  sub: p.aliases.isEmpty ? null : 'Also: ${p.aliases.take(4).join(', ')}',
                  onTap: () => _editPlace(context, p),
                ),
            ]),
            _group('Profile', [
              _row(
                leading: Avatar(emoji: s.avatar, color: s.avatarColor, size: 38),
                title: s.name,
                sub: 'Name, avatar at kulay · shown on your barkada card',
                onTap: () => showProfileSheet(context),
              ),
            ]),
            _group('Tara', [
              _row(
                leading: IconTile(Icons.memory, size: 38),
                title: s.ai.ready ? 'On-device AI ready' : 'Basic mode (no AI)',
                sub: s.ai.ready
                    ? '${AiConfig.textModel} · ${AiConfig.sttModel} · ${AiConfig.visionModel}'
                    : 'Download once to enable Taglish AI, voice and screenshots',
                trailing: s.ai.ready
                    ? const Icon(Icons.check_circle, color: T.olive)
                    : TextButton(onPressed: () => _download(context), child: const Text('Download')),
              ),
              _switchRow(Icons.record_voice_over_outlined, 'Tara talks back', 'Speak replies (offline TTS)', s.speakReplies, s.setSpeak),
            ]),
            _group('Demo', [
              _switchRow(Icons.schedule, 'Demo clock', 'Pin “now” to today, 7:05 AM', s.demoClock, s.setDemoClock),
              _row(
                leading: IconTile(Icons.restart_alt, size: 38),
                title: 'Reset demo data',
                sub: 'Re-seed 4 weeks of sample trips',
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Reset demo data?'),
                      content: const Text('Your logged trips, XP and friends will be replaced with the sample data.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                      ],
                    ),
                  );
                  if (ok == true) await s.resetDemo();
                },
              ),
            ]),
            _group('Diagnostics', [
              _row(
                leading: IconTile(Icons.science_outlined, size: 38),
                title: 'Run AI self-test',
                sub: 'Voice clips + images in the selftest folder, on-device',
                onTap: () => _selfTest(context),
              ),
            ]),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(20)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.shield_outlined, color: T.lime, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Private by design', style: T.h(17, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('AI, trips, GPS and voice stay on this phone. No account, no cloud. Tara only tracks when you ask.',
                        style: T.b(14, color: T.inkMuted)),
                    const SizedBox(height: 8),
                    Text('READY OFFLINE', style: T.kicker(color: T.lime)),
                  ]),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _group(String label, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label.toUpperCase(), style: T.kicker(color: T.muted))),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: T.line)),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1) const Divider(height: 1, indent: 64, color: T.line),
              ],
            ]),
          ),
        ]),
      );

  Widget _row({required Widget leading, required String title, String? sub, Widget? trailing, VoidCallback? onTap}) => ListTile(
        minVerticalPadding: 12,
        onTap: onTap,
        leading: leading,
        title: Text(title, style: T.h(16, w: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub, style: T.b(13, color: T.muted)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: T.faint) : null),
      );

  Widget _switchRow(IconData icon, String title, String sub, bool value, Future<void> Function(bool) onChanged) => SwitchListTile(
        secondary: IconTile(icon, size: 38),
        title: Text(title, style: T.h(16, w: FontWeight.w700)),
        subtitle: Text(sub, style: T.b(13, color: T.muted)),
        value: value,
        activeThumbColor: T.ink,
        activeTrackColor: T.lime,
        onChanged: onChanged,
      );

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Downloading models… keep the app open.')));
    try {
      await AppState.I.downloadModels((_, __) {});
      messenger.showSnackBar(const SnackBar(content: Text('On-device AI ready!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _selfTest(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Running on-device…')])),
    );
    final lines = await AppState.I.selfTest();
    if (!context.mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Self-test'),
        content: SingleChildScrollView(child: Text(lines.join('\n\n'), style: T.b(12))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _editPlace(BuildContext context, Place p) async {
    final name = TextEditingController(text: p.name);
    final aliases = TextEditingController(text: p.aliases.join(', '));
    String? status;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.cream,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.of(c).viewInsets.bottom + 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit place', style: T.h(22)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: aliases, decoration: const InputDecoration(labelText: 'Other names (comma-separated)', hintText: 'lb, elbi, uplb')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                set(() => status = 'Getting GPS…');
                try {
                  var perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
                  final pos = await Geolocator.getCurrentPosition();
                  p.lat = pos.latitude;
                  p.lng = pos.longitude;
                  set(() => status = 'Saved: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
                } catch (e) {
                  set(() => status = 'GPS unavailable');
                }
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Set to my current location'),
            ),
            if (status != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(status!, style: T.b(13, color: T.muted))),
            const SizedBox(height: 16),
            PrimaryButton('Save', onTap: () async {
              p.name = name.text.trim().isEmpty ? p.name : name.text.trim();
              p.aliases = aliases.text.split(',').map((a) => a.trim().toLowerCase()).where((a) => a.isNotEmpty).toList();
              await AppState.I.savePlace(p);
              if (c.mounted) Navigator.pop(c);
            }),
          ]),
        ),
      ),
    );
  }
}
