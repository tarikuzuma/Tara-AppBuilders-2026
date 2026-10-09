import 'package:flutter/material.dart';

import '../ai/brain.dart';
import '../app_state.dart';
import '../screens/log_trip_screen.dart';
import 'components.dart';
import 'theme.dart';

Future<void> showVoiceSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const VoiceSheet(),
    );

enum _Phase { listening, transcribing, thinking, answered, typing }

/// "Hey Tara": tap-to-talk → on-device Whisper → same brain as typed questions.
class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});
  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> with SingleTickerProviderStateMixin {
  _Phase phase = _Phase.listening;
  String transcript = '';
  String? error;
  TaraAnswer? answer;
  final typed = TextEditingController();
  late final wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  AppState get s => AppState.I;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    wave.dispose();
    s.cancelListening();
    super.dispose();
  }

  Future<void> _start() async {
    if (!s.ai.ready) {
      setState(() {
        phase = _Phase.typing;
        error = 'Basic mode: walang voice model pa. I-type mo na lang.';
      });
      return;
    }
    final ok = await s.startListening();
    if (!ok && mounted) {
      setState(() {
        phase = _Phase.typing;
        error = 'Kailangan ng mic permission. I-type mo na lang muna.';
      });
    }
  }

  Future<void> _stop() async {
    setState(() => phase = _Phase.transcribing);
    final text = await s.stopListening();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      setState(() {
        phase = _Phase.typing;
        error = 'Di kita narinig nang maayos — ulitin o i-type?';
      });
      return;
    }
    await _run(text);
  }

  Future<void> _run(String text) async {
    setState(() {
      transcript = text;
      phase = _Phase.thinking;
      error = null;
    });
    final a = await s.ask(text);
    if (!mounted) return;
    setState(() {
      answer = a;
      phase = _Phase.answered;
    });
    s.chat.add(a);
  }

  Future<void> _confirm() async {
    final a = answer!;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (a.action) {
      case TaraAction.startTrip:
        nav.pop();
        final msg = await s.startTracking(a.draft!);
        if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
      case TaraAction.stopTrip:
        nav.pop();
        final t = s.stopTracking();
        if (t != null) nav.push(MaterialPageRoute(builder: (_) => LogTripScreen(draft: t, review: true)));
      case TaraAction.logTrip:
        nav.pop();
        nav.push(MaterialPageRoute(builder: (_) => LogTripScreen(draft: a.draft, review: true)));
      case TaraAction.none:
        nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(children: [
              const Brandmark(size: 34),
              const SizedBox(width: 10),
              Text('Hey Tara', style: T.h(20)),
              const Spacer(),
              Text('ON-DEVICE', style: T.kicker(color: T.muted)),
            ]),
            const SizedBox(height: 20),
            ..._body(),
          ]),
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (phase) {
      case _Phase.listening:
        return [
          Text('Nakikinig ako…', style: T.h(24)),
          const SizedBox(height: 6),
          Text('“Track my location, papunta akong LB” · “Aabot ba ako by 8?” · “Nandito na ako”',
              style: T.b(15, color: T.muted)),
          const SizedBox(height: 26),
          Center(
            child: AnimatedBuilder(
              animation: wave,
              builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 7; i++)
                  Container(
                    width: 6,
                    height: 14 + 34 * ((i.isEven ? wave.value : 1 - wave.value) * (0.4 + (i % 3) * 0.3)),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: T.olive, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          PrimaryButton('Tapos na', icon: Icons.stop_rounded, onTap: _stop),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () async {
                await s.cancelListening();
                setState(() => phase = _Phase.typing);
              },
              child: Text('I-type na lang', style: T.b(14, color: T.muted, w: FontWeight.w600)),
            ),
          ),
        ];
      case _Phase.transcribing:
      case _Phase.thinking:
        return [
          if (transcript.isNotEmpty) ...[
            Text('“$transcript”', style: T.b(18, w: FontWeight.w500, height: 1.4)),
            const SizedBox(height: 16),
          ],
          Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: T.olive)),
            const SizedBox(width: 12),
            Text(phase == _Phase.transcribing ? 'Pinapakinggan ulit (Whisper on-device)…' : 'Nag-iisip si Tara…',
                style: T.b(15, color: T.muted)),
          ]),
          const SizedBox(height: 30),
        ];
      case _Phase.typing:
        return [
          if (error != null) ...[
            Text(error!, style: T.b(15, color: T.muted)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: typed,
            autofocus: true,
            style: T.b(16),
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => v.trim().isEmpty ? null : _run(v),
            decoration: const InputDecoration(hintText: 'hal. papunta akong LB, track mo ako'),
          ),
          const SizedBox(height: 12),
          PrimaryButton('Send kay Tara', icon: Icons.send, onTap: () => typed.text.trim().isEmpty ? null : _run(typed.text)),
          if (s.ai.ready) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    phase = _Phase.listening;
                    error = null;
                  });
                  _start();
                },
                child: Text('Subukan ulit ang mic', style: T.b(14, color: T.muted, w: FontWeight.w600)),
              ),
            ),
          ],
        ];
      case _Phase.answered:
        final a = answer!;
        final label = switch (a.action) {
          TaraAction.startTrip => 'Simulan ang tracking',
          TaraAction.stopTrip => 'I-review ang trip',
          TaraAction.logTrip => 'I-review at i-save',
          TaraAction.none => 'Sige, salamat!',
        };
        return [
          Text('“$transcript”', style: T.b(15, color: T.muted)),
          const SizedBox(height: 12),
          CardBox(
            color: T.oliveSoft,
            border: T.oliveLine,
            padding: 12,
            child: Row(children: [
              const Icon(Icons.check_circle, color: T.olive, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(a.steps.isNotEmpty ? a.steps.first : '', style: T.b(14, color: T.olive, w: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 12),
          if (a.headline.isNotEmpty) Text(a.headline, style: T.h(22)),
          const SizedBox(height: 4),
          Text(a.text, style: T.b(16, height: 1.5)),
          if (a.facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            FactsCard(facts: a.facts, footer: a.footer, aiExplained: a.aiExplained, guardBlocked: a.guardBlocked),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label, icon: a.action == TaraAction.startTrip ? Icons.my_location : Icons.check, onTap: _confirm),
          if (a.action != TaraAction.none)
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hindi, cancel', style: T.b(14, color: T.muted, w: FontWeight.w600)),
              ),
            ),
        ];
    }
  }
}
