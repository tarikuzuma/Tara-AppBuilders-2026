import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../main.dart';
import '../stats/advisor.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/voice_sheet.dart';
import 'log_trip_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              const TopBar(),
              _PlayerStrip(s: s),
              if (s.live != null) ...[const SizedBox(height: 14), const LiveTripCard()],
              _Hero(s: s),
              const SizedBox(height: 26),
              Kicker('Tanong kay Tara', icon: Icons.auto_awesome),
              const SizedBox(height: 6),
              Text('May biyahe ka sa isip?', style: T.h(21)),
              const SizedBox(height: 12),
              CardBox(
                padding: 10,
                onTap: () => Shell.of(context).openAsk(),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text('“Uulan daw, aabot ba ako?”', style: T.b(16, color: T.faint))),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.arrow_forward, color: T.ink),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.mic,
                    title: 'Hey Tara',
                    sub: 'Track my trip…',
                    dark: true,
                    onTap: () => showVoiceSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add,
                    title: 'Log a trip',
                    sub: 'Type or timer',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogTripScreen())),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shield_outlined, size: 15, color: T.muted),
                const SizedBox(width: 6),
                Text('On-device lang. Walang lumalabas sa phone mo.', style: T.b(13, color: T.muted)),
              ]),
              if (s.quests.isNotEmpty) ...[
                const SizedBox(height: 22),
                CardBox(
                  color: const Color(0xFFF2F6E7),
                  border: const Color(0xFFD9DEC9),
                  padding: 14,
                  onTap: () => Shell.of(context).go(4),
                  child: Row(children: [
                    const IconTile(Icons.emoji_events_outlined, bg: T.lime, fg: T.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('WEEKLY QUEST', style: T.kicker()),
                        const SizedBox(height: 2),
                        Text(s.quests.first.title, style: T.h(16, w: FontWeight.w700)),
                        Text('${s.quests.first.description} · ${s.quests.first.progress} of ${s.quests.first.target}',
                            style: T.b(13, color: T.muted)),
                        const SizedBox(height: 6),
                        ProgressBar(s.quests.first.fraction),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Text('+${s.quests.first.reward}\nXP', textAlign: TextAlign.center, style: T.h(15, color: T.olive)),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              SectionTitle('Recent trips',
                  trailing: TextButton(
                      onPressed: () => Shell.of(context).go(3),
                      child: Text('See all', style: T.b(14, color: T.olive, w: FontWeight.w700)))),
              for (final t in s.trips.take(2)) ...[
                TripRow(
                  trip: t,
                  from: s.place(t.originId).name,
                  to: s.place(t.destinationId).name,
                  when: DateFormat('EEE · h:mm a').format(t.start),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final h = s.now.hour;
    final greet = h < 12 ? 'Magandang umaga' : (h < 18 ? 'Magandang hapon' : 'Magandang gabi');
    return SizedBox(
      height: 72,
      child: Row(children: [
        const Brandmark(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((label ?? '$greet, ${s.name}').toUpperCase(), style: T.kicker(color: T.muted), overflow: TextOverflow.ellipsis),
            Text('Tara?', style: T.h(21)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: T.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.ai.ready ? const Color(0xFF6F9836) : T.faint, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(s.ai.ready ? 'On-device AI' : 'Basic mode', style: T.b(12, w: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_outlined, color: T.ink),
        ),
      ]),
    );
  }
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({required this.s});
  final AppState s;
  @override
  Widget build(BuildContext context) {
    final xp = s.xp;
    return InkWell(
      onTap: () => Shell.of(context).go(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.line), bottom: BorderSide(color: T.line))),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(13)),
            child: Text('${xp.level}', style: T.h(16, color: T.lime)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(xp.title, style: T.h(15, w: FontWeight.w700)),
              const SizedBox(height: 5),
              Row(children: [
                SizedBox(width: 90, child: ProgressBar(xp.progress, height: 5)),
                const SizedBox(width: 8),
                Text('${NumberFormat.decimalPattern().format(xp.lifetime)} / ${NumberFormat.decimalPattern().format(xp.nextLevelAt)} XP',
                    style: T.b(12, color: T.muted)),
              ]),
            ]),
          ),
          const Icon(Icons.local_fire_department, color: T.streak, size: 22),
          const SizedBox(width: 2),
          Column(children: [
            Text('${s.streak}', style: T.h(17, color: T.streak)),
            Text('days', style: T.b(11, color: T.muted)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: T.faint),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final plan = s.heroPlan();
    final v = plan.verdict;
    final st = plan.stats;
    final mode = modeLabel(plan.mode);
    final (String head, String accent, String sub, Color tone) = switch (v.kind) {
      VerdictKind.onTime => ('May oras ka pa — alis by ', hhmm(v.leaveBy!), 'Para umabot sa ${hhmm(plan.arrive)} mo. ${v.slackMin} mins pa.', T.olive),
      VerdictKind.tight => ('Alis ka na! Dapat by ', hhmm(v.leaveBy!), 'Sakto lang sa ${hhmm(plan.arrive)} kung aalis ka ngayon.', T.amber),
      VerdictKind.late => ('Late ka na ng ', '${v.lateByMin} min', 'Kung $mode. Tanong mo kay Tara kung ano mas mabilis.', T.red),
      VerdictKind.unknown => ('Kulang pa ', 'data', 'I-log mo ang ilang trips para ma-compute ni Tara.', T.muted),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Text(DateFormat('EEEE · h:mm a').format(s.now).toUpperCase(), style: T.kicker(color: T.muted)),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: [
        TextSpan(text: head, style: T.h(30)),
        TextSpan(text: accent, style: T.h(30, color: tone)),
      ])),
      const SizedBox(height: 6),
      Text(sub, style: T.b(15, color: T.muted)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 6),
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.lime, width: 2))),
              Container(width: 1.5, height: 30, color: const Color(0xFF526079)),
              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: T.lime)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FROM', style: T.kicker(color: T.inkMuted)),
                Text(s.place(plan.origin).name, style: T.h(18, color: Colors.white, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('TO', style: T.kicker(color: T.inkMuted)),
                Text(s.place(plan.dest).name, style: T.h(18, color: Colors.white, w: FontWeight.w700)),
              ]),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(16)),
              child: Icon(s.rainToggle ? Icons.water_drop_outlined : Icons.wb_sunny_outlined, color: T.ink, size: 26),
            ),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _chip(modeIcon(plan.mode), mode),
            _chip(Icons.schedule, st.p80Min == null ? '—' : '${st.p80Min} min p80'),
            _chip(Icons.history, '${st.count} trips'),
          ]),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => s.setRain(!s.rainToggle),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.water_drop_outlined, size: 18, color: s.rainToggle ? Colors.white : T.inkMuted),
                  const SizedBox(width: 6),
                  Text('Umuulan', style: T.b(15, color: s.rainToggle ? Colors.white : T.inkMuted, w: FontWeight.w600)),
                  const Spacer(),
                  Switch(
                    value: s.rainToggle,
                    activeThumbColor: T.ink,
                    activeTrackColor: T.lime,
                    inactiveTrackColor: const Color(0xFF4B5670),
                    onChanged: s.setRain,
                  ),
                ]),
              ),
            ),
          ),
          const Divider(color: T.inkLine, height: 18),
          Row(children: [
            const Icon(Icons.verified_user_outlined, color: T.lime, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(style: T.b(13, color: T.inkMuted), children: [
                const TextSpan(text: 'May '),
                TextSpan(text: '5-min safety buffer', style: T.b(13, color: Colors.white, w: FontWeight.w700)),
                TextSpan(text: st.relaxed.contains('tags') ? '. Kulang rainy trips, all trips ginamit.' : ' na kasama.'),
              ])),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _chip(IconData i, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: T.ink2, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: T.lime, size: 18),
          const SizedBox(width: 6),
          Text(label, style: T.b(14, color: Colors.white, w: FontWeight.w500)),
        ]),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.sub, required this.onTap, this.dark = false});
  final IconData icon;
  final String title;
  final String sub;
  final bool dark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CardBox(
        padding: 12,
        onTap: onTap,
        child: Row(children: [
          IconTile(icon, bg: dark ? T.ink : T.oliveSoft, fg: dark ? T.lime : T.olive, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.h(15, w: FontWeight.w700)),
              Text(sub, style: T.b(12, color: T.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

/// Live GPS trip card (only while the app is open).
class LiveTripCard extends StatelessWidget {
  const LiveTripCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final l = s.live!;
    final elapsed = DateTime.now().difference(l.draft.start).inMinutes;
    final eta = l.etaMin == null ? null : l.draft.start.add(Duration(minutes: l.etaMin!));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: l.arrived ? T.lime : const Color(0xFFE7F0D0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.oliveLine),
      ),
      child: Row(children: [
        const _Pulse(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.arrived ? 'NANDITO KA NA!' : 'LIVE TRIP · TO ${s.place(l.draft.destinationId).name.toUpperCase()}',
                style: T.kicker(color: T.olive)),
            const SizedBox(height: 2),
            Text('$elapsed min${eta != null ? ' · ETA ${hhmm(eta)}' : ''}', style: T.h(18)),
            Text('${l.km.toStringAsFixed(1)} km · ${l.points.length} GPS points (on-device)', style: T.b(13, color: T.muted)),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: T.ink, minimumSize: const Size(72, 48)),
          onPressed: () {
            final t = s.stopTracking();
            if (t != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LogTripScreen(draft: t, review: true)));
            }
          },
          child: Text('Stop', style: T.b(15, color: Colors.white, w: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: T.olive.withValues(alpha: 0.15 * (1 - c.value))),
          child: Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: T.olive)),
        ),
      );
}
