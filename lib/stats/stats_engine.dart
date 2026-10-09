import '../data/models.dart';

/// What slice of the trip history to look at.
class StatsQuery {
  final String originId;
  final String destinationId;
  final String? mode;
  final String? bucket;
  final int? weekday; // DateTime.monday..sunday
  final List<String> tags; // trips must carry all of these

  const StatsQuery({
    required this.originId,
    required this.destinationId,
    this.mode,
    this.bucket,
    this.weekday,
    this.tags = const [],
  });

  StatsQuery copyWith({String? mode, bool dropBucket = false, bool dropWeekday = false, bool dropTags = false}) =>
      StatsQuery(
        originId: originId,
        destinationId: destinationId,
        mode: mode ?? this.mode,
        bucket: dropBucket ? null : bucket,
        weekday: dropWeekday ? null : weekday,
        tags: dropTags ? const [] : tags,
      );

  bool matches(Trip t) {
    if (t.originId != originId || t.destinationId != destinationId) return false;
    if (mode != null && t.mode != mode) return false;
    if (bucket != null && t.timeBucket != bucket) return false;
    if (weekday != null && t.start.weekday != weekday) return false;
    for (final tag in tags) {
      if (!t.tags.contains(tag)) return false;
    }
    return true;
  }
}

/// Numbers computed by code. The AI is only ever allowed to repeat these.
class RouteStats {
  final StatsQuery query;
  final int count;
  final int? medianMin;
  final int? p80Min;
  final double? avgFare;
  final double? medianFare;
  final double? p90Fare;
  final List<double> fares;
  final List<String> relaxed; // filters dropped because data was thin

  const RouteStats({
    required this.query,
    required this.count,
    this.medianMin,
    this.p80Min,
    this.avgFare,
    this.medianFare,
    this.p90Fare,
    this.fares = const [],
    this.relaxed = const [],
  });

  bool get isEmpty => count == 0;
  bool get isUncertain => count < 3;
}

const kMinTrips = 3;

int _medianInt(List<int> sorted) {
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return ((sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2).round();
}

double _medianDouble(List<double> sorted) {
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

/// Nearest-rank percentile: the value that p% of trips are at or under.
T percentile<T extends num>(List<T> sorted, double p) {
  final rank = (p * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

RouteStats computeStats(List<Trip> trips, StatsQuery q, {List<String> relaxed = const []}) {
  final matched = trips.where(q.matches).toList();
  if (matched.isEmpty) return RouteStats(query: q, count: 0, relaxed: relaxed);
  final mins = matched.map((t) => t.minutes).toList()..sort();
  final fares = matched.where((t) => t.fare != null).map((t) => t.fare!).toList()..sort();
  return RouteStats(
    query: q,
    count: matched.length,
    medianMin: _medianInt(mins),
    p80Min: percentile(mins, 0.8),
    avgFare: fares.isEmpty ? null : fares.reduce((a, b) => a + b) / fares.length,
    medianFare: fares.isEmpty ? null : _medianDouble(fares),
    p90Fare: fares.isEmpty ? null : percentile(fares, 0.9),
    fares: fares,
    relaxed: relaxed,
  );
}

/// Like [computeStats] but widens the filter (tags → weekday → time bucket)
/// until at least [kMinTrips] trips match, recording what was dropped.
RouteStats statsWithRelaxation(List<Trip> trips, StatsQuery q) {
  var current = q;
  final relaxed = <String>[];
  var result = computeStats(trips, current);
  if (result.count >= kMinTrips) return result;

  if (current.tags.isNotEmpty) {
    current = current.copyWith(dropTags: true);
    relaxed.add('tags');
    result = computeStats(trips, current, relaxed: List.of(relaxed));
    if (result.count >= kMinTrips) return result;
  }
  if (current.weekday != null) {
    current = current.copyWith(dropWeekday: true);
    relaxed.add('weekday');
    result = computeStats(trips, current, relaxed: List.of(relaxed));
    if (result.count >= kMinTrips) return result;
  }
  if (current.bucket != null) {
    current = current.copyWith(dropBucket: true);
    relaxed.add('bucket');
    result = computeStats(trips, current, relaxed: List.of(relaxed));
  }
  // Still thin: return the widest attempt, or the original if widening found nothing.
  if (result.count == 0) return computeStats(trips, q);
  return result;
}

/// Modes that have at least one trip on this route.
List<String> modesOnRoute(List<Trip> trips, String originId, String destinationId) {
  final seen = <String>{};
  for (final t in trips) {
    if (t.originId == originId && t.destinationId == destinationId) seen.add(t.mode);
  }
  return kModes.where(seen.contains).toList();
}

/// The mode most often used on a route (ties → first in [kModes]).
String? usualMode(List<Trip> trips, String originId, String destinationId) {
  final counts = <String, int>{};
  for (final t in trips) {
    if (t.originId == originId && t.destinationId == destinationId) {
      counts[t.mode] = (counts[t.mode] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}
