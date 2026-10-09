import '../data/models.dart';
import 'stats_engine.dart';

enum FareVerdict { overcharge, fair, cheap, notEnoughData }

class FareCheck {
  final FareVerdict verdict;
  final double asked;
  final int pastTrips;
  final double? median;
  final double? low;
  final double? high;

  const FareCheck(this.verdict, this.asked, this.pastTrips, {this.median, this.low, this.high});
}

/// Compare a quoted fare against your own fare history on that route + mode.
/// Overcharge when above both the 90th percentile and 1.3× the median.
FareCheck checkFare(List<Trip> trips, String originId, String destinationId, String mode, double asked) {
  final s = computeStats(trips, StatsQuery(originId: originId, destinationId: destinationId, mode: mode));
  final fares = s.fares;
  if (fares.length < kMinTrips) {
    return FareCheck(FareVerdict.notEnoughData, asked, fares.length,
        median: s.medianFare, low: fares.isEmpty ? null : fares.first, high: fares.isEmpty ? null : fares.last);
  }
  final median = s.medianFare!;
  final p90 = s.p90Fare!;
  final FareVerdict v;
  if (asked > p90 && asked > median * 1.3) {
    v = FareVerdict.overcharge;
  } else if (asked < fares.first) {
    v = FareVerdict.cheap;
  } else {
    v = FareVerdict.fair;
  }
  return FareCheck(v, asked, fares.length, median: median, low: fares.first, high: fares.last);
}
