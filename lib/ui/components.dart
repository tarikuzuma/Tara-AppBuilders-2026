import 'package:flutter/material.dart';

import '../ai/brain.dart';
import '../data/models.dart';
import 'theme.dart';

IconData modeIcon(String mode) => switch (mode) {
      'jeepney' => Icons.directions_bus_filled_outlined,
      'tricycle' => Icons.electric_rickshaw_outlined,
      'grab' => Icons.local_taxi_outlined,
      'walk' => Icons.directions_walk,
      'bus' => Icons.directions_bus_outlined,
      'mrt_lrt' => Icons.train_outlined,
      _ => Icons.route,
    };

IconData tagIcon(String tag) => switch (tag) {
      'rain' => Icons.water_drop_outlined,
      'traffic' => Icons.traffic_outlined,
      'flood' => Icons.waves,
      _ => Icons.label_outline,
    };

class Brandmark extends StatelessWidget {
  const Brandmark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(size * 0.33)),
        child: Text('T', style: T.h(size * 0.45)),
      );
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.icon, this.color = T.olive});
  final String text;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
        Text(text.toUpperCase(), style: T.kicker(color: color)),
      ]);
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.color = T.card, this.border = T.line, this.padding = 16, this.onTap, this.radius = 18});
  final Widget child;
  final Color color;
  final Color border;
  final double padding;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: box),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.bg = T.oliveSoft, this.fg = T.olive, this.size = 44});
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: fg, size: size * 0.5),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.selected = false, this.onTap, this.dense = false});
  final String label;
  final IconData? icon;
  final bool selected;
  final bool dense;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? T.oliveSoft : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? T.olive : T.line, width: selected ? 1.4 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: dense ? 36 : 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 17, color: selected ? T.olive : T.muted), const SizedBox(width: 6)],
                Text(label, style: T.b(14, color: selected ? T.olive : T.ink, w: selected ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap, this.icon, this.color = T.ink, this.fg = Colors.white});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: fg,
            disabledBackgroundColor: T.line,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label, style: T.b(16, color: fg, w: FontWeight.w700)),
          ]),
        ),
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color = T.olive, this.bg = const Color(0xFFDDE2D3), this.height = 6});
  final double value;
  final Color color;
  final Color bg;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: height, color: color, backgroundColor: bg),
      );
}

/// The "code-checked facts" card: proof that numbers came from code, not the AI.
class FactsCard extends StatelessWidget {
  const FactsCard({super.key, required this.facts, required this.footer, this.aiExplained = false, this.guardBlocked = false});
  final List<Fact> facts;
  final String footer;
  final bool aiExplained;
  final bool guardBlocked;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3C6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_user_outlined, size: 17, color: T.olive),
          const SizedBox(width: 6),
          Text('CODE-CHECKED FACTS', style: T.kicker()),
          if (guardBlocked) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: T.oliveLine)),
            child: Text('AI reply blocked', style: T.b(11, color: T.olive, w: FontWeight.w600)),
          ),
          ],
        ]),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(children: [
            for (var i = 0; i < facts.length && i < 4; i++) ...[
              if (i > 0) const VerticalDivider(width: 20, color: Color(0xFFD8DFC2)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(facts[i].value, style: T.h(22, color: const Color(0xFF26341B)))),
                  const SizedBox(height: 2),
                  Text(facts[i].label, style: T.b(12, color: T.muted)),
                ]),
              ),
            ],
          ]),
        ),
        if (footer.isNotEmpty) ...[
          const Divider(height: 20, color: Color(0xFFD8DFC2)),
          Text(footer, style: T.b(12, color: T.muted)),
        ],
      ]),
    );
  }
}

class TripRow extends StatelessWidget {
  const TripRow({super.key, required this.trip, required this.from, required this.to, required this.when, this.onTap});
  final Trip trip;
  final String from;
  final String to;
  final String when;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final grab = trip.mode == 'grab';
    return CardBox(
      padding: 14,
      onTap: onTap,
      child: Row(children: [
        IconTile(modeIcon(trip.mode), bg: grab ? T.tealSoft : T.oliveSoft, fg: grab ? T.teal : T.olive),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(from, style: T.h(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 15, color: T.muted)),
              Flexible(child: Text(to, style: T.h(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 3),
            Text(when, style: T.b(13, color: T.muted)),
            if (trip.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                for (final t in trip.tags)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tagIcon(t), size: 14, color: T.olive),
                    const SizedBox(width: 3),
                    Text(kTagLabels[t] ?? t, style: T.b(12, color: T.olive, w: FontWeight.w600)),
                  ]),
              ]),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${trip.minutes} min', style: T.h(15, w: FontWeight.w700)),
          if (trip.fare != null) Text('₱${trip.fare!.round()}', style: T.b(13, color: T.muted)),
        ]),
      ]),
    );
  }
}

/// XP pop shown after saving a trip or finishing a quest.
void showXpToast(BuildContext context, int amount, String detail) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    duration: const Duration(seconds: 3),
    content: Row(children: [
      Text('+$amount', style: T.h(22, color: T.lime)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('XP earned!', style: T.h(15, color: Colors.white, w: FontWeight.w700)),
          Text(detail, style: T.b(13, color: T.inkMuted)),
        ]),
      ),
      const Icon(Icons.auto_awesome, color: T.lime),
    ]),
  ));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.kicker, this.trailing});
  final String title;
  final String? kicker;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (kicker != null) ...[Kicker(kicker!), const SizedBox(height: 4)],
              Text(title, style: T.h(20)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}
