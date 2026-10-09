import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

/// First launch: the one moment Tara needs internet — downloading the models.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool busy = false;
  double? progress;
  String status = '';
  String? error;

  Future<void> _download() async {
    setState(() {
      busy = true;
      error = null;
      status = 'Starting…';
    });
    try {
      await AppState.I.downloadModels((p, s) {
        if (mounted) setState(() {
          progress = p;
          status = s;
        });
      });
    } catch (e) {
      if (mounted) setState(() {
        busy = false;
        error = 'Hindi natapos ang download. Check your internet and try again.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Brandmark(size: 46), SizedBox(width: 12)]),
            const SizedBox(height: 36),
            Text('Your commute,\nmas gets na.', style: T.h(36)),
            const SizedBox(height: 14),
            Text('Tara answers your Taglish commute questions using your own trips. All AI runs on this phone.',
                style: T.b(17, color: T.muted)),
            const SizedBox(height: 28),
            _point(Icons.download_for_offline_outlined, 'Download once, offline forever',
                'Tara’s brain, ears and eyes (~1 GB) download one time. After that, airplane mode is fine.'),
            _point(Icons.lock_outline, 'Walang lumalabas sa phone mo',
                'Trips, GPS and voice stay on this device. No account, no cloud.'),
            _point(Icons.translate, 'Kahit Taglish, gets ko', '“Uulan daw, aabot ba ako by 8 kung mag-jeep?”'),
            const Spacer(),
            if (busy) ...[
              Text(status, style: T.b(14, color: T.muted)),
              const SizedBox(height: 10),
              ProgressBar(progress ?? 0, height: 8),
              const SizedBox(height: 8),
              Text(progress == null ? '' : '${(progress! * 100).round()}%', style: T.h(16)),
            ] else ...[
              if (error != null) ...[
                Text(error!, style: T.b(13, color: T.red), maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
              ],
              PrimaryButton('Download Tara (Wi-Fi)', icon: Icons.download, onTap: _download),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: AppState.I.skipAi,
                  child: Text('Skip for now — basic mode (no AI)', style: T.b(14, color: T.muted, w: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _point(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.h(16, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: T.b(14, color: T.muted)),
            ]),
          ),
        ]),
      );
}
