import 'dart:math';

import '../game/xp_engine.dart';
import 'models.dart';

/// Default saved places (Metro Manila + Los Baños), editable in Settings.
List<Place> defaultPlaces() => [
      Place(id: 'home', name: 'Home', aliases: ['bahay', 'house', 'amin'], lat: 14.6195, lng: 121.0537),
      Place(
          id: 'school',
          name: 'School',
          aliases: ['eskwela', 'campus', 'class', 'klase', 'katipunan', 'univ', 'university'],
          lat: 14.6400,
          lng: 121.0770),
      Place(id: 'office', name: 'Office', aliases: ['work', 'opisina', 'trabaho', 'makati'], lat: 14.5547, lng: 121.0244),
      Place(id: 'lb', name: 'Los Baños', aliases: ['lb', 'elbi', 'uplb', 'los banos'], lat: 14.1676, lng: 121.2430),
      Place(id: 'mall', name: 'SM North', aliases: ['mall', 'sm', 'trinoma'], lat: 14.6565, lng: 121.0290),
    ];

class SeedData {
  final List<Trip> trips;
  final Map<DateTime, int> steps;
  final List<XpEvent> xp;
  final List<Friend> friends;
  SeedData(this.trips, this.steps, this.xp, this.friends);
}

/// Four weeks of believable synthetic commutes ending yesterday. Deterministic
/// so the demo numbers are stable. Rain slows jeeps ~25–40%, rush hour is
/// slower, Grab surges in the rain, trikes cost ₱45–60, LB is a long bus ride.
SeedData generateSeed(DateTime now) {
  final r = Random(42);
  final trips = <Trip>[];
  final steps = <DateTime, int>{};
  var n = 0;
  String id() => 'seed-${n++}';
  int noise(int span) => r.nextInt(span + 1);

  final today = dayOf(now);
  var rainDays = 0, rainyAm = 0, dryAm = 0;
  for (var back = 28; back >= 1; back--) {
    final day = today.subtract(Duration(days: back));
    steps[day] = 5200 + r.nextInt(6200);
    if (back == 8) continue; // one missed day → streak resets a week ago
    final rain = back % 2 == 0 || back % 7 == 3; // ~55% rainy days (habagat season)
    if (rain) rainDays++;
    final wd = day.weekday;
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

    if (wd <= DateTime.friday) {
      // Morning: Home → School (or Office on Thursdays)
      final leave = at(6, 40 + noise(25));
      if (wd == DateTime.thursday) {
        final mins = 40 + noise(8) + (rain ? 6 : 0);
        trips.add(Trip(
            id: id(), originId: 'home', destinationId: 'office', mode: 'mrt_lrt',
            start: leave, end: leave.add(Duration(minutes: mins)), fare: 42,
            tags: rain ? ['rain'] : [], source: 'seed', note: rain ? 'siksikan sa MRT pag umuulan' : null));
      } else {
        if (!rain && (++dryAm).isEven) {
          final mins = 22 + noise(8);
          trips.add(Trip(
              id: id(), originId: 'home', destinationId: 'school', mode: 'tricycle',
              start: leave, end: leave.add(Duration(minutes: mins)), fare: 45.0 + 5 * (n % 4),
              source: 'seed'));
        } else if (rain && (++rainyAm).isEven) {
          final mins = 28 + noise(6);
          trips.add(Trip(
              id: id(), originId: 'home', destinationId: 'school', mode: 'grab',
              start: leave, end: leave.add(Duration(minutes: mins)), fare: 225.0 + noise(40),
              tags: ['rain'], source: 'seed'));
        } else {
          final traffic = r.nextDouble() < 0.3;
          final mins = (rain ? 50 : 39) + noise(9) + (traffic ? 4 : 0);
          final tags = [if (rain) 'rain', if (traffic) 'traffic'];
          trips.add(Trip(
              id: id(), originId: 'home', destinationId: 'school', mode: 'jeepney',
              start: leave, end: leave.add(Duration(minutes: mins)), fare: 15,
              tags: tags, source: 'seed',
              note: traffic ? 'traffic sa Katipunan' : (rain && r.nextBool() ? 'baha sa Aurora' : null)));
        }
      }
      // Evening: School/Office → Home
      final back2 = at(17, 10 + noise(40));
      final from = wd == DateTime.thursday ? 'office' : 'school';
      if (wd == DateTime.tuesday && !rain) {
        final mins = 18 + noise(6);
        trips.add(Trip(
            id: id(), originId: from, destinationId: 'home', mode: 'tricycle',
            start: back2, end: back2.add(Duration(minutes: mins)), fare: [50.0, 55.0, 60.0][r.nextInt(3)], source: 'seed'));
      } else if (rain && wd != DateTime.thursday && rainDays % 3 == 1) {
        final mins = 30 + noise(8);
        trips.add(Trip(
            id: id(), originId: from, destinationId: 'home', mode: 'grab',
            start: back2, end: back2.add(Duration(minutes: mins)), fare: 240.0 + noise(50),
            tags: ['rain'], source: 'seed', note: 'surge pricing'));
      } else {
        final flood = rain && r.nextDouble() < 0.4;
        final mins = (rain ? 54 : 44) + noise(10);
        trips.add(Trip(
            id: id(), originId: from, destinationId: 'home', mode: from == 'office' ? 'mrt_lrt' : 'jeepney',
            start: back2, end: back2.add(Duration(minutes: mins)), fare: from == 'office' ? 42 : 15,
            tags: [if (rain) 'rain', if (flood) 'flood'], source: 'seed',
            note: flood ? 'baha sa España' : null));
      }
    } else if (wd == DateTime.saturday) {
      final leave = at(7, 30 + noise(30));
      final mins = 70 + noise(15) + (rain ? 12 : 0);
      trips.add(Trip(
          id: id(), originId: 'home', destinationId: 'lb', mode: 'bus',
          start: leave, end: leave.add(Duration(minutes: mins)), fare: 120,
          tags: rain ? ['rain'] : [], source: 'seed', note: 'bus sa Buendia papuntang LB'));
      final ret = at(18, 0 + noise(40));
      trips.add(Trip(
          id: id(), originId: 'lb', destinationId: 'home', mode: 'bus',
          start: ret, end: ret.add(Duration(minutes: 80 + noise(20))), fare: 120, source: 'seed'));
    } else {
      final leave = at(10, noise(50));
      trips.add(Trip(
          id: id(), originId: 'home', destinationId: 'mall', mode: 'walk',
          start: leave, end: leave.add(Duration(minutes: 24 + noise(6))), km: 2.0, source: 'seed'));
    }
  }

  // XP history derived from the seed with the real rules.
  final xp = <XpEvent>[];
  var x = 0;
  for (final t in trips) {
    for (final a in xpForTrip(t)) {
      xp.add(XpEvent(id: 'seedxp-${x++}', at: t.end, amount: a.amount, reason: a.reason, refId: t.id));
    }
  }
  steps.forEach((day, s) {
    final amt = xpForSteps(s);
    if (amt > 0) xp.add(XpEvent(id: 'seedxp-${x++}', at: day.add(const Duration(hours: 23)), amount: amt, reason: 'Steps'));
  });

  final week = isoWeek(now);
  final friends = [
    Friend(name: 'Bea', week: week, xp: 410, steps: 61200, streak: 9, level: 13, title: 'Street Smart', avatar: '🦊', color: 3),
    Friend(name: 'Paolo', week: week, xp: 260, steps: 40310, streak: 3, level: 8, title: 'Campus Navigator', avatar: '😎', color: 1),
    Friend(name: 'Kaye', week: week, xp: 180, steps: 35870, streak: 2, level: 7, title: 'Lakbay Local', avatar: '🌻', color: 2),
  ];
  return SeedData(trips, steps, xp, friends);
}
