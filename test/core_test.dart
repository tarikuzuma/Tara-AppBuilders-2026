import 'package:flutter_test/flutter_test.dart';
import 'package:tara/ai/intent.dart';
import 'package:tara/data/models.dart';
import 'package:tara/data/seed.dart';
import 'package:tara/game/barkada_card.dart';
import 'package:tara/game/quests.dart';
import 'package:tara/game/xp_engine.dart';
import 'package:tara/stats/advisor.dart';
import 'package:tara/stats/fare_check.dart';
import 'package:tara/stats/stats_engine.dart';

Trip t(int mins, {String mode = 'jeepney', double? fare, List<String> tags = const [], int hour = 7, int day = 6}) {
  final s = DateTime(2026, 10, day, hour, 0);
  return Trip(
      id: '$mins-$day-$hour-$mode',
      originId: 'home',
      destinationId: 'school',
      mode: mode,
      start: s,
      end: s.add(Duration(minutes: mins)),
      fare: fare,
      tags: tags);
}

void main() {
  final places = defaultPlaces();
  final now = DateTime(2026, 10, 13, 7, 5); // Tuesday 7:05 AM

  group('stats', () {
    test('median and p80', () {
      final trips = [40, 42, 44, 46, 60].map((m) => t(m)).toList();
      final s = computeStats(trips, const StatsQuery(originId: 'home', destinationId: 'school'));
      expect(s.count, 5);
      expect(s.medianMin, 44);
      expect(s.p80Min, 46);
    });

    test('relaxes tags when thin', () {
      final trips = [t(40), t(41), t(42), t(55, tags: ['rain'])];
      final s = statsWithRelaxation(trips, const StatsQuery(originId: 'home', destinationId: 'school', tags: ['rain']));
      expect(s.relaxed, ['tags']);
      expect(s.count, 4);
    });

    test('verdict onTime / late', () {
      final s = computeStats([40, 45, 50, 55, 58].map((m) => t(m)).toList(),
          const StatsQuery(originId: 'home', destinationId: 'school'));
      final arrive = DateTime(2026, 10, 13, 8, 0);
      expect(verdictFor(DateTime(2026, 10, 13, 6, 30), arrive, s).kind, VerdictKind.onTime);
      expect(leaveByFor(arrive, s.p80Min!), DateTime(2026, 10, 13, 7, 0)); // p80 = 55
      expect(verdictFor(DateTime(2026, 10, 13, 7, 30), arrive, s).kind, VerdictKind.late);
    });

    test('fare check', () {
      final trips = [45.0, 50.0, 50.0, 55.0, 60.0].map((f) => t(25, mode: 'tricycle', fare: f)).toList();
      expect(checkFare(trips, 'home', 'school', 'tricycle', 80).verdict, FareVerdict.overcharge);
      expect(checkFare(trips, 'home', 'school', 'tricycle', 50).verdict, FareVerdict.fair);
      expect(checkFare(trips.take(2).toList(), 'home', 'school', 'tricycle', 80).verdict, FareVerdict.notEnoughData);
    });
  });

  group('intent keywords', () {
    test('rain + jeep + 8am', () {
      final i = keywordParse('Uulan daw, aabot ba ako sa 8AM class ko kung mag-jeep?', places);
      expect(i.type, 'can_i_make_it');
      expect(i.mode, 'jeepney');
      expect(i.rain, true);
      expect(i.arriveHour, 8);
      expect(i.destination, 'school');
    });
    test('voice start trip to LB', () {
      final i = keywordParse("Hey Tara, can you track my location now? I'm going to LB bro", places);
      expect(i.type, 'start_trip');
      expect(i.destination, 'lb');
    });
    test('stop trip', () {
      expect(keywordParse('Tara, nandito na ako', places).type, 'stop_trip');
    });
    test('fare check', () {
      final i = keywordParse('₱80 sa trike papuntang school, overcharge ba?', places);
      expect(i.type, 'fare_check');
      expect(i.fare, 80);
      expect(i.mode, 'tricycle');
      expect(i.destination, 'school');
    });
    test('log trip', () {
      final i = keywordParse('jeep pauwi 50 mins ₱15 baha sa España', places);
      expect(i.type, 'log_trip');
      expect(i.minutes, 50);
      expect(i.fare, 15);
      expect(i.destination, 'home');
      expect(i.tags, contains('flood'));
    });
    test('compare', () {
      expect(keywordParse('Jeep o Grab pag umuulan?', places).type, 'compare_modes');
    });
    test('alas-otso', () {
      expect(keywordParse('aabot ba ako ng alas-otso?', places).arriveHour, 8);
    });
    test('50 mins is not an arrival time', () {
      expect(keywordParse('jeep 50 mins', places).hasArrival, false);
    });
  });

  group('AI merge + guard', () {
    test('extracts json from chatter', () {
      expect(extractJsonObject('<think></think>Sure! {"intent":"how_long","mode":"grab"} done')?['mode'], 'grab');
    });
    test('rejects invented numbers', () {
      final base = keywordParse('magkano grab pauwi?', places);
      final merged = mergeIntent(base, {'intent': 'cost', 'fare': 250, 'mode': 'grab'}, 'magkano grab pauwi?', places);
      expect(merged.fare, isNull);
      expect(merged.type, 'cost');
    });
    test('number guard', () {
      expect(passesNumberGuard('Mga 58 mins, alis ka by 6:57.', 'p80=58 leave_by=6:57 AM', ''), true);
      expect(passesNumberGuard('Mga 45 mins lang.', 'p80=58', ''), false);
    });
  });

  group('game', () {
    test('levels', () {
      expect(levelFor(0), 1);
      expect(levelFor(5600), 12);
      expect(titleFor(12), 'Street Smart');
    });
    test('xp for tagged trip', () {
      expect(xpForTrip(t(40, tags: ['rain'])).fold<int>(0, (a, b) => a + b.amount), 70);
    });
    test('streak with shield', () {
      final days = [12, 11, 9, 8].map((d) => t(40, day: d)).toList();
      expect(streakDays(days, DateTime(2026, 10, 13)), 2);
      expect(streakDays(days, DateTime(2026, 10, 13), shields: 1), 4);
    });
    test('iso week', () {
      expect(isoWeek(DateTime(2026, 10, 10)), '2026-W41');
      expect(isoWeek(DateTime(2026, 1, 1)), '2026-W01');
    });
    test('barkada card round trip', () {
      final f = Friend(name: 'Jolo', week: '2026-W41', xp: 520, steps: 41000, streak: 5, level: 9, title: 'Campus Navigator');
      final back = decodeCard(encodeCard(f))!;
      expect(back.name, 'Jolo');
      expect(back.xp, 520);
      expect(decodeCard('${encodeCard(f)}x'), isNull);
      expect(decodeCard('hello'), isNull);
    });
    test('barkada card carries avatar; old cards still decode', () {
      final f = Friend(name: 'Bea', week: '2026-W41', xp: 410, steps: 1, streak: 9, level: 13, title: 'Street Smart', avatar: '🦊', color: 3);
      final back = decodeCard(encodeCard(f))!;
      expect(back.avatar, '🦊');
      expect(back.color, 3);
      final old = Friend(name: 'Old', week: 'w', xp: 1, steps: 1, streak: 1, level: 1, title: 't');
      expect(decodeCard(encodeCard(old))!.avatar, '🙂');
    });
  });

  group('seed sanity', () {
    final seed = generateSeed(now);
    test('rainy jeep AM stats look like the demo', () {
      final s = statsWithRelaxation(seed.trips,
          const StatsQuery(originId: 'home', destinationId: 'school', mode: 'jeepney', bucket: 'am_rush', tags: ['rain']));
      final dry = computeStats(seed.trips.where((x) => !x.tags.contains('rain')).toList(),
          const StatsQuery(originId: 'home', destinationId: 'school', mode: 'jeepney', bucket: 'am_rush'));
      // ignore: avoid_print
      print('rain jeep n=${s.count} med=${s.medianMin} p80=${s.p80Min} relaxed=${s.relaxed} | '
          'dry n=${dry.count} med=${dry.medianMin} p80=${dry.p80Min}');
      expect(s.count, greaterThanOrEqualTo(3));
      expect(s.p80Min!, greaterThan(dry.p80Min!));
    });
    test('trike fares and quests', () {
      final fc = checkFare(seed.trips, 'home', 'school', 'tricycle', 80);
      final xp = summarize(seed.xp);
      final quests = pickQuests(QuestContext(seed.trips, seed.steps, now));
      // ignore: avoid_print
      print('trike fares n=${fc.pastTrips} med=${fc.median} verdict=${fc.verdict} | xp lifetime=${xp.lifetime} '
          'level=${xp.level} | streak=${streakDays(seed.trips, now)} | '
          'quests=${quests.map((q) => '${q.type}:${q.progress}/${q.target}').join(', ')}');
      expect(fc.verdict, FareVerdict.overcharge);
    });
  });

  test('seed supports the demo on any install weekday', () {
    for (var d = 0; d < 7; d++) {
      final when = DateTime(2026, 10, 10 + d, 7, 5);
      final seed = generateSeed(when);
      int n(String mode, {bool rain = false}) => seed.trips
          .where((t) => t.originId == 'home' && t.destinationId == 'school' && t.mode == mode && t.timeBucket == 'am_rush')
          .where((t) => !rain || t.tags.contains('rain'))
          .length;
      final trikeFares = seed.trips.where((t) => t.mode == 'tricycle' && t.originId == 'home' && t.destinationId == 'school').length;
      // ignore: avoid_print
      print('weekday ${when.weekday}: rainy jeep ${n('jeepney', rain: true)}, rainy grab ${n('grab', rain: true)}, trike $trikeFares');
      expect(n('jeepney', rain: true), greaterThanOrEqualTo(3));
      expect(n('grab', rain: true), greaterThanOrEqualTo(3));
      expect(trikeFares, greaterThanOrEqualTo(3));
    }
  });
}
