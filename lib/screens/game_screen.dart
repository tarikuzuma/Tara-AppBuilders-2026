import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../game/barkada_card.dart';
import '../game/shop.dart';
import '../game/xp_engine.dart';
import '../ui/components.dart';
import '../ui/profile.dart';
import 'package:image_picker/image_picker.dart';
import '../ui/theme.dart';
import 'settings_screen.dart';

final _n = NumberFormat.decimalPattern();

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final xp = s.xp;
        return SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
            SizedBox(
              height: 70,
              child: Row(children: [
                const ProfileButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PASADA CLUB', style: T.kicker(color: T.muted)),
                    Text('Your commute game', style: T.h(20)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ]),
            ),
            _PlayerCard(s: s, xp: xp),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFE7E7E0), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                _tab(0, 'Quests', Icons.emoji_events_outlined),
                _tab(1, 'Shop', Icons.storefront_outlined),
                _tab(2, 'Barkada', Icons.qr_code),
              ]),
            ),
            const SizedBox(height: 16),
            if (tab == 0) _Quests(s: s),
            if (tab == 1) _Shop(s: s),
            if (tab == 2) _Barkada(s: s),
          ]),
        );
      },
    );
  }

  Widget _tab(int i, String label, IconData icon) => Expanded(
        child: Material(
          color: tab == i ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => setState(() => tab = i),
            child: SizedBox(
              height: 46,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: tab == i ? T.olive : T.muted),
                const SizedBox(width: 6),
                Text(label, style: T.b(15, color: tab == i ? T.olive : T.muted, w: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.s, required this.xp});
  final AppState s;
  final XpSummary xp;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(17)),
              child: Stack(clipBehavior: Clip.none, children: [
                const Center(child: Icon(Icons.emoji_events_outlined, color: T.ink, size: 28)),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: T.ink, width: 2)),
                    child: Text('${xp.level}', style: T.h(12)),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LEVEL ${xp.level}', style: T.kicker(color: T.lime)),
                Text(xp.title, style: T.h(22, color: Colors.white)),
                if (nextTitle(xp.level) != null) Text('Next: ${nextTitle(xp.level)}', style: T.b(13, color: T.inkMuted)),
              ]),
            ),
            Column(children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFEFA36F), size: 26),
              Text('${s.streak}', style: T.h(20, color: const Color(0xFFEFA36F))),
              Text('day streak', style: T.b(11, color: T.inkMuted)),
            ]),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Text('${_n.format(xp.lifetime)} XP', style: T.b(14, color: T.lime, w: FontWeight.w700)),
            const Spacer(),
            Text('${_n.format(xp.toNext)} to level ${xp.level + 1}', style: T.b(13, color: T.inkMuted)),
          ]),
          const SizedBox(height: 8),
          ProgressBar(xp.progress, color: T.lime, bg: T.inkLine, height: 7),
          const Divider(color: T.inkLine, height: 28),
          Row(children: [
            _stat(Icons.directions_walk, _n.format(s.stepsToday), 'steps today'),
            _stat(Icons.route, '${s.trips.length}', 'trips logged'),
            if (s.shields > 0) _stat(Icons.shield_outlined, '${s.shields}', 'shields') else _stat(Icons.local_fire_department, '${s.streak}', 'day streak'),
          ]),
        ]),
      );

  Widget _stat(IconData i, String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(i, size: 18, color: T.lime), const SizedBox(width: 6), Text(v, style: T.h(16, color: Colors.white))]),
          Text(l, style: T.b(12, color: T.inkMuted)),
        ]),
      );
}

class _Quests extends StatelessWidget {
  const _Quests({required this.s});
  final AppState s;
  @override
  Widget build(BuildContext context) {
    final now = s.now;
    final end = weekStart(now).add(const Duration(days: 7));
    final left = end.difference(now);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tara, level up!',
          kicker: 'Weekly challenges', trailing: Text('${left.inDays}d ${left.inHours % 24}h left', style: T.b(13, color: T.muted))),
      for (final (i, q) in s.quests.indexed) ...[
        CardBox(
          color: i == 0 ? const Color(0xFFF4F7E9) : Colors.white,
          border: i == 0 ? T.oliveLine : T.line,
          padding: 14,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(
              q.type == 'steps' || q.type == 'walk_instead' ? Icons.directions_walk : (q.type == 'log_days' ? Icons.route : Icons.water_drop_outlined),
              bg: i == 0 ? T.lime : T.tealSoft,
              fg: i == 0 ? T.ink : T.teal,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (i == 0) Text('PERSONALIZED FOR YOU', style: T.kicker()),
                Text(q.title, style: T.h(17, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(q.description, style: T.b(14, color: T.muted)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ProgressBar(q.fraction)),
                  const SizedBox(width: 10),
                  Text(q.done ? 'Done!' : '${q.progress} / ${q.target} ${q.unit}', style: T.b(13, color: T.muted, w: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            Column(children: [
              Text('+${q.reward}', style: T.h(16, color: T.olive)),
              Text('XP', style: T.b(11, color: T.olive, w: FontWeight.w700)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFECECE6), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, size: 18, color: T.olive),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(style: T.b(13, color: T.muted), children: [
              TextSpan(text: 'Picked from your patterns, tracked by code. ', style: T.b(13, color: T.ink, w: FontWeight.w700)),
              const TextSpan(text: 'Targets, progress and rewards never rely on AI guesses.'),
            ])),
          ),
        ]),
      ),
    ]);
  }
}

class _Shop extends StatelessWidget {
  const _Shop({required this.s});
  final AppState s;

  Future<void> _buy(BuildContext context, ShopItem item) async {
    final owned = s.owned.contains(item.id);
    if (item.isPersona && owned) {
      await s.setPersona(item.id);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Buy ${item.name}?', style: T.h(20)),
        content: Text('${item.cost} XP. Balance after: ${_n.format(s.xp.balance - item.cost)} XP.\nHindi bababa ang level mo.',
            style: T.b(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buy')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await s.buy(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '${item.name} unlocked!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = shopItem(s.persona);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Text('AVAILABLE BALANCE', style: T.kicker(color: T.inkMuted)),
          const Spacer(),
          const Icon(Icons.auto_awesome, color: T.lime, size: 18),
          const SizedBox(width: 6),
          Text('${_n.format(s.xp.balance)} XP', style: T.h(18, color: T.lime)),
        ]),
      ),
      const SizedBox(height: 10),
      CardBox(
        color: const Color(0xFFF3F7E7),
        border: T.oliveLine,
        padding: 14,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(15)),
            child: Text(active.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ACTIVE VOICE', style: T.kicker()),
              Text(active.name, style: T.h(17, w: FontWeight.w700)),
              Text('“${active.sample}”', style: T.b(13, color: T.muted).copyWith(fontStyle: FontStyle.italic)),
            ]),
          ),
          const Icon(Icons.check_circle, color: T.olive),
        ]),
      ),
      const SizedBox(height: 20),
      const SectionTitle('Unlock your vibe', kicker: 'Pasada Shop'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
        children: [
          for (final item in kShopItems)
            _ShopCard(
              item: item,
              owned: s.owned.contains(item.id),
              equipped: s.persona == item.id,
              affordable: s.xp.balance >= item.cost,
              onTap: () => _buy(context, item),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text('Personas only change how Tara talks. Every number is still computed by code and checked.',
          style: T.b(13, color: T.muted)),
    ]);
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.item, required this.owned, required this.equipped, required this.affordable, required this.onTap});
  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final String label;
    if (item.isPersona && equipped) {
      label = 'Equipped';
    } else if (item.isPersona && owned) {
      label = 'Use';
    } else {
      label = '${item.cost} XP';
    }
    final enabled = !equipped && (owned && item.isPersona || affordable);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: equipped ? const Color(0xFFF5F8EC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: equipped ? T.olive : T.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFEEF1E6), borderRadius: BorderRadius.circular(14)),
          child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 10),
        Text(item.name, style: T.h(16, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Expanded(child: Text(item.blurb, style: T.b(13, color: T.muted))),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: T.ink,
              disabledBackgroundColor: const Color(0xFFDFE3DA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.zero,
            ),
            onPressed: enabled ? onTap : null,
            child: Text(label, style: T.b(14, color: enabled ? Colors.white : T.muted, w: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Barkada extends StatelessWidget {
  const _Barkada({required this.s});
  final AppState s;

  void _showMyCard(BuildContext context) {
    final card = s.myCard();
    showModalBottomSheet(
      context: context,
      backgroundColor: T.cream,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('My barkada card', style: T.h(22)),
            const SizedBox(height: 4),
            Text('Ipa-scan sa friend mo. Scores lang — walang location o routes.', textAlign: TextAlign.center, style: T.b(14, color: T.muted)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: T.line)),
              child: QrImageView(data: encodeCard(card), size: 230, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: T.ink)),
            ),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Avatar(emoji: card.avatar, color: card.color, size: 32),
              const SizedBox(width: 8),
              Flexible(
                child: Text('${card.name} · ${card.title} · ${_n.format(card.xp)} XP this week · 🔥${card.streak}',
                    style: T.b(14, w: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _scan(BuildContext context) async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (raw == null || !context.mounted) return;
    final f = decodeCard(raw);
    if (f == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi Tara card ’yan.')));
      return;
    }
    await s.addFriend(f);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name} added! Saved on this phone.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = s.myCard();
    final board = <Friend>[...s.friends.where((f) => f.name != me.name), me]..sort((a, b) => b.xp.compareTo(a.xp));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Barkada board', kicker: 'Offline leaderboard', trailing: Text('This week', style: T.b(13, color: T.muted))),
      Row(children: [
        Expanded(child: _action(Icons.qr_code_2, 'My card', 'Share stats, never routes', () => _showMyCard(context))),
        const SizedBox(width: 10),
        Expanded(child: _action(Icons.qr_code_scanner, 'Scan a friend', 'Works without internet', () => _scan(context))),
      ]),
      const SizedBox(height: 14),
      CardBox(
        padding: 0,
        child: Column(children: [
          for (final (i, f) in board.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: f.name == me.name ? const Color(0xFFF3F7E7) : null,
                border: i == board.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFEAEBE6))),
              ),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: T.h(15, color: T.faint))),
                Avatar(emoji: f.avatar, color: f.color, size: 40, ring: f.name == me.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(f.name, style: T.h(16, w: FontWeight.w700)),
                      if (f.name == me.name) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(6)),
                          child: Text('YOU', style: T.b(11, w: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    Text('${f.title} · 🔥 ${f.streak}', style: T.b(13, color: T.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_n.format(f.xp), style: T.h(16, w: FontWeight.w700)),
                  Text('weekly XP', style: T.b(11, color: T.muted)),
                ]),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_outline, size: 15, color: T.muted),
        const SizedBox(width: 6),
        Text('QR cards share scores only — never locations or routes.', style: T.b(13, color: T.muted)),
      ]),
    ]);
  }

  Widget _action(IconData icon, String title, String sub, VoidCallback onTap) => CardBox(
        padding: 12,
        onTap: onTap,
        child: Row(children: [
          IconTile(icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.h(15, w: FontWeight.w700)),
              Text(sub, style: T.b(12, color: T.muted), maxLines: 2),
            ]),
          ),
        ]),
      );
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();
  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool done = false;
  final controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Friend sent their card as a screenshot (e.g. over Messenger): read it from a photo.
  Future<void> _fromPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null || !mounted) return;
    final capture = await controller.analyzeImage(img.path);
    final v = (capture == null || capture.barcodes.isEmpty) ? null : capture.barcodes.first.rawValue;
    if (!mounted) return;
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Walang QR code sa photo na ’yan.')));
      return;
    }
    done = true;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Scan a friend’s card', style: T.h(19)),
          actions: [
            TextButton.icon(
              onPressed: _fromPhoto,
              icon: const Icon(Icons.photo_library_outlined, color: T.ink),
              label: Text('From photo', style: T.b(14, w: FontWeight.w700)),
            ),
          ],
        ),
        body: Stack(children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (done) return;
              final v = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
              if (v == null) return;
              done = true;
              Navigator.pop(context, v);
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: T.ink, borderRadius: BorderRadius.circular(16)),
              child: Text('Itapat sa QR ng Tara card ng friend mo. Walang internet na kailangan.',
                  style: T.b(14, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
        ]),
      );
}
