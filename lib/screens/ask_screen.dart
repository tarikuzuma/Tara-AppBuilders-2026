import 'package:flutter/material.dart';

import '../ai/brain.dart';
import '../app_state.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/voice_sheet.dart';
import 'log_trip_screen.dart';

const kPrompts = [
  'Uulan daw, aabot ba ako sa 8AM class kung mag-jeep?',
  'Jeep o Grab pag umuulan?',
  '₱80 sa trike papuntang school, overcharge ba?',
  'Magkano usually ang Grab pauwi?',
];

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  String? pendingQuestion;
  List<String> pendingSteps = [];
  bool busy = false;

  AppState get s => AppState.I;

  @override
  void initState() {
    super.initState();
    s.askRequest.addListener(_onRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
  }

  @override
  void dispose() {
    s.askRequest.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    final q = s.askRequest.value;
    if (q == null) return;
    s.askRequest.value = null;
    _ask(q);
  }

  Future<void> _ask(String q) async {
    if (q.trim().isEmpty || busy) return;
    setState(() {
      busy = true;
      pendingQuestion = q.trim();
      pendingSteps = [s.ai.ready ? 'Iniintindi ni Tara (on-device)…' : 'Iniintindi (basic mode)…'];
    });
    input.clear();
    _toBottom();
    final a = await s.ask(q.trim(), onStep: (a) {
      if (!mounted) return;
      setState(() {
        pendingSteps = [
          ...a.steps,
          if (a.facts.isNotEmpty && a.steps.length == 1) 'Kinuha ang ${a.facts.length > 1 ? a.facts[1].value : ''} trips mo — code computed',
          if (a.steps.length == 1 && s.ai.ready) 'Sinusulat ni Tara ang sagot…',
        ];
      });
    });
    if (!mounted) return;
    setState(() {
      s.chat.add(a);
      busy = false;
      pendingQuestion = null;
    });
    _toBottom();
    _handleAction(a);
  }

  void _handleAction(TaraAnswer a) {
    if (a.action == TaraAction.logTrip && a.draft != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LogTripScreen(draft: a.draft, review: true)));
    } else if (a.action == TaraAction.stopTrip) {
      final t = s.stopTracking();
      if (t != null) Navigator.push(context, MaterialPageRoute(builder: (_) => LogTripScreen(draft: t, review: true)));
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final empty = s.chat.isEmpty && pendingQuestion == null;
    return SafeArea(
      child: Column(children: [
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.line))),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YOUR COMMUTE COPILOT', style: T.kicker(color: T.muted)),
                Text('Tanong kay Tara', style: T.h(21)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: T.line)),
              child: Row(children: [
                Icon(Icons.memory, size: 15, color: s.ai.ready ? T.olive : T.faint),
                const SizedBox(width: 5),
                Text(s.ai.ready ? 'Local AI' : 'Basic mode', style: T.b(12, w: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: empty
              ? _Empty(onPick: _ask)
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  children: [
                    for (final a in s.chat) ...[
                      _UserBubble(a.question),
                      _AnswerBlock(a: a, onFollowUp: _ask),
                      const SizedBox(height: 22),
                    ],
                    if (pendingQuestion != null) ...[
                      _UserBubble(pendingQuestion!),
                      _Pipeline(steps: pendingSteps),
                    ],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.line),
              boxShadow: const [BoxShadow(color: Color(0x1417233C), blurRadius: 18, offset: Offset(0, 6))],
            ),
            child: Row(children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  style: T.b(16),
                  decoration: const InputDecoration(
                    hintText: 'Tanong tungkol sa biyahe…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              _RoundBtn(icon: Icons.mic_none, bg: const Color(0xFFEDF0E8), onTap: () => showVoiceSheet(context), label: 'Talk to Tara'),
              const SizedBox(width: 6),
              _RoundBtn(icon: Icons.send, bg: T.lime, onTap: () => _ask(input.text), label: 'Send'),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.bg, required this.onTap, required this.label});
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(width: 48, height: 48, child: Icon(icon, color: T.ink)),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.auto_awesome, size: 32, color: T.ink),
            ),
          ),
          const SizedBox(height: 20),
          Text('Kahit Taglish, gets ko.', textAlign: TextAlign.center, style: T.h(26)),
          const SizedBox(height: 8),
          Text('Tanong mo kung kailan aalis, gaano katagal, o anong sakay ang mas okay — base sa sarili mong trips.',
              textAlign: TextAlign.center, style: T.b(15, color: T.muted)),
          const SizedBox(height: 28),
          for (final p in kPrompts) ...[
            CardBox(
              padding: 14,
              onTap: () => onPick(p),
              child: Row(children: [
                Expanded(child: Text(p, style: T.b(15, w: FontWeight.w500))),
                const Icon(Icons.chevron_right, color: T.olive),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            color: T.ink,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
          ),
          child: Text(text, style: T.b(15, color: Colors.white)),
        ),
      );
}

/// Turns on-device latency into a visible understand → compute → explain trail.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.steps});
  final List<String> steps;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                i == steps.length - 1
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: T.olive))
                    : const Icon(Icons.check_circle, size: 18, color: T.olive),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: T.b(14, color: i == steps.length - 1 ? T.ink : T.muted))),
              ]),
            ),
        ]),
      );
}

class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({required this.a, required this.onFollowUp});
  final TaraAnswer a;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.auto_awesome, size: 16, color: T.ink),
        ),
        const SizedBox(width: 8),
        Text('TARA', style: T.kicker()),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            a.steps.isNotEmpty ? a.steps.first : '',
            style: T.b(12, color: T.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: T.line),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(19), bottomLeft: Radius.circular(19), bottomRight: Radius.circular(19)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (a.headline.isNotEmpty) Text(a.headline, style: T.h(17, w: FontWeight.w800)),
          if (a.headline.isNotEmpty) const SizedBox(height: 4),
          Text(a.text, style: T.b(16, height: 1.5)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(a.aiExplained ? Icons.memory : Icons.rule, size: 14, color: T.faint),
            const SizedBox(width: 4),
            Text(
              a.aiExplained
                  ? 'Written on-device by ${s.persona[0].toUpperCase()}${s.persona.substring(1)} Tara'
                  : (a.guardBlocked ? 'AI reply had an unverified number — showing checked answer' : 'Checked template answer'),
              style: T.b(12, color: T.faint),
            ),
          ]),
        ]),
      ),
      if (a.facts.isNotEmpty) ...[
        const SizedBox(height: 10),
        FactsCard(facts: a.facts, footer: a.footer, aiExplained: a.aiExplained, guardBlocked: a.guardBlocked),
      ],
      if (a.action == TaraAction.startTrip && a.draft != null) ...[
        const SizedBox(height: 10),
        PrimaryButton(s.live == null ? 'Simulan ang tracking' : 'Tracking na…', icon: Icons.my_location, onTap: s.live != null
            ? null
            : () async {
                final msg = await s.startTracking(a.draft!);
                if (msg != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }),
      ],
      if (a.followUp != null) ...[
        const SizedBox(height: 10),
        CardBox(
          padding: 13,
          onTap: () => onFollowUp(a.followUp!),
          child: Row(children: [
            const Icon(Icons.local_taxi_outlined, color: T.olive),
            const SizedBox(width: 10),
            Expanded(child: Text(a.followUp!, style: T.b(15, w: FontWeight.w600))),
            const Icon(Icons.arrow_forward, color: T.olive),
          ]),
        ),
      ],
    ]);
  }
}
