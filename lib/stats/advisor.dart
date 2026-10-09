import '../data/models.dart';
import 'stats_engine.dart';

const kBufferMin = 5;

enum VerdictKind { onTime, tight, late, unknown }

class Verdict {
  final VerdictKind kind;
  final DateTime? leaveBy; // arriveBy − p80 − buffer
  final int? slackMin; // minutes to spare before leaveBy (onTime)
  final int? lateByMin; // minutes late if leaving now at the median (late)
  final DateTime? etaMedian; // now + median

  const Verdict(this.kind, {this.leaveBy, this.slackMin, this.lateByMin, this.etaMedian});
}

DateTime leaveByFor(DateTime arriveBy, int p80Min, {int bufferMin = kBufferMin}) =>
    arriveBy.subtract(Duration(minutes: p80Min + bufferMin));

/// Can you make it if you leave [now]? Pure arithmetic on code-computed stats.
Verdict verdictFor(DateTime now, DateTime arriveBy, RouteStats s, {int bufferMin = kBufferMin}) {
  if (s.isEmpty || s.p80Min == null || s.medianMin == null) return const Verdict(VerdictKind.unknown);
  final leaveBy = leaveByFor(arriveBy, s.p80Min!, bufferMin: bufferMin);
  final etaMedian = now.add(Duration(minutes: s.medianMin!));
  if (!now.isAfter(leaveBy)) {
    return Verdict(VerdictKind.onTime,
        leaveBy: leaveBy, slackMin: leaveBy.difference(now).inMinutes, etaMedian: etaMedian);
  }
  if (!etaMedian.isAfter(arriveBy)) {
    return Verdict(VerdictKind.tight, leaveBy: leaveBy, etaMedian: etaMedian);
  }
  return Verdict(VerdictKind.late,
      leaveBy: leaveBy, lateByMin: etaMedian.difference(arriveBy).inMinutes, etaMedian: etaMedian);
}

class ModeOption {
  final String mode;
  final RouteStats stats;
  ModeOption(this.mode, this.stats);
}

/// Stats for every mode used on the route, fastest (by p80) first.
List<ModeOption> compareModes(List<Trip> trips, StatsQuery base) {
  final options = <ModeOption>[];
  for (final mode in modesOnRoute(trips, base.originId, base.destinationId)) {
    final s = statsWithRelaxation(trips, base.copyWith(mode: mode));
    if (!s.isEmpty) options.add(ModeOption(mode, s));
  }
  options.sort((a, b) => a.stats.p80Min!.compareTo(b.stats.p80Min!));
  return options;
}

/// The next weekday class/work start after [now] (simple fixed schedule for the demo).
DateTime nextArrival(DateTime now, {int hour = 8, int minute = 0}) {
  var t = DateTime(now.year, now.month, now.day, hour, minute);
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  return t;
}

String hhmm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String hhmmShort(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

String modeLabel(String mode) => kModeLabels[mode] ?? mode;
