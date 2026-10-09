import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../stats/advisor.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import 'home_screen.dart';
import 'log_trip_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String filter = 'all';

  bool _match(Trip t) => switch (filter) {
        'all' => true,
        'rain' => t.tags.contains('rain'),
        _ => t.mode == filter,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final list = s.trips.where(_match).toList();
        final routes = <String, int>{};
        for (final t in s.trips) {
          final k = '${t.originId}>${t.destinationId}';
          routes[k] = (routes[k] ?? 0) + 1;
        }
        final top = routes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final maxCount = top.isEmpty ? 1 : top.first.value;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: T.ink,
            foregroundColor: T.lime,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogTripScreen())),
            icon: const Icon(Icons.add),
            label: Text('Log trip', style: T.b(15, color: T.lime, w: FontWeight.w700)),
          ),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              const TopBar(label: 'Your local history'),
              const SizedBox(height: 14),
              Text('LAST 4 WEEKS', style: T.kicker(color: T.muted)),
              const SizedBox(height: 4),
              Text('Mga biyahe mo', style: T.h(28)),
              const SizedBox(height: 4),
              Text('${s.trips.length} trips · stored only on this phone', style: T.b(15, color: T.muted)),
              const SizedBox(height: 18),
              SectionTitle('Most visited', kicker: 'Your routines'),
              CardBox(
                padding: 4,
                child: Column(children: [
                  for (var i = 0; i < top.length && i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('0${i + 1}', style: T.h(13, color: T.faint))),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                                '${s.place(top[i].key.split('>')[0]).name} → ${s.place(top[i].key.split('>')[1]).name}',
                                style: T.h(15, w: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ProgressBar(top[i].value / maxCount, height: 4),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Text('${top[i].value}×', style: T.h(17, color: T.olive)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 22),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in const [('all', 'All'), ('jeepney', 'Jeepney'), ('grab', 'Grab'), ('tricycle', 'Trike'), ('bus', 'Bus'), ('rain', 'Rain')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(f.$2, selected: filter == f.$1, dense: true, onTap: () => setState(() => filter = f.$1)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('Wala pang trips dito.', style: T.b(15, color: T.muted))),
              for (final t in list) ...[
                Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: T.redSoft, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.delete_outline, color: T.red),
                  ),
                  confirmDismiss: (_) => showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete this trip?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                      ],
                    ),
                  ),
                  onDismissed: (_) => s.deleteTrip(t.id),
                  child: TripRow(
                    trip: t,
                    from: s.place(t.originId).name,
                    to: s.place(t.destinationId).name,
                    when: '${DateFormat('EEE, MMM d · h:mm a').format(t.start)} · ${modeLabel(t.mode)}',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        );
      },
    );
  }
}
