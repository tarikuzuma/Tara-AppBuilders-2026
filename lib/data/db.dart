import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../game/xp_engine.dart';
import 'models.dart';
import 'seed.dart';

/// Local SQLite store. Nothing in here ever leaves the phone.
class TaraDb {
  TaraDb._(this.db);
  final Database db;

  static Future<TaraDb> open({DateTime? now}) async {
    final path = p.join(await getDatabasesPath(), 'tara.db');
    final db = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE places(id TEXT PRIMARY KEY, name TEXT, aliases TEXT, lat REAL, lng REAL)');
      await db.execute('CREATE TABLE trips(id TEXT PRIMARY KEY, origin_id TEXT, destination_id TEXT, mode TEXT, '
          'start_ms INTEGER, end_ms INTEGER, fare REAL, note TEXT, tags TEXT, source TEXT, km REAL)');
      await db.execute('CREATE TABLE trip_points(trip_id TEXT, t_ms INTEGER, lat REAL, lng REAL)');
      await db.execute('CREATE TABLE daily_steps(day_ms INTEGER PRIMARY KEY, steps INTEGER, baseline INTEGER)');
      await db.execute('CREATE TABLE xp_events(id TEXT PRIMARY KEY, at_ms INTEGER, amount INTEGER, reason TEXT, ref_id TEXT)');
      await db.execute('CREATE TABLE owned_items(item_id TEXT, bought_ms INTEGER)');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      await db.execute('CREATE TABLE friends(name TEXT PRIMARY KEY, week TEXT, xp INTEGER, steps INTEGER, '
          'streak INTEGER, level INTEGER, title TEXT, scanned_ms INTEGER)');
    });
    final store = TaraDb._(db);
    if ((await store.getSetting('seeded')) == null) await store.seed(now ?? DateTime.now());
    return store;
  }

  Future<void> seed(DateTime now) async {
    final s = generateSeed(now);
    final batch = db.batch();
    for (final pl in defaultPlaces()) {
      batch.insert('places', pl.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final t in s.trips) {
      batch.insert('trips', t.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    s.steps.forEach((day, steps) {
      batch.insert('daily_steps', {'day_ms': day.millisecondsSinceEpoch, 'steps': steps, 'baseline': null},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    for (final e in s.xp) {
      batch.insert('xp_events', e.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final f in s.friends) {
      batch.insert('friends', {...f.toRow(), 'scanned_ms': now.millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    batch.insert('owned_items', {'item_id': 'tito', 'bought_ms': now.millisecondsSinceEpoch});
    batch.insert('settings', {'key': 'seeded', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('settings', {'key': 'persona', 'value': 'tito'}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('settings', {'key': 'name', 'value': 'Mia'}, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  Future<void> resetDemo(DateTime now) async {
    for (final t in ['places', 'trips', 'trip_points', 'daily_steps', 'xp_events', 'owned_items', 'friends']) {
      await db.delete(t);
    }
    await db.delete('settings', where: 'key IN (?, ?)', whereArgs: ['seeded', 'persona']);
    await seed(now);
  }

  // settings
  Future<String?> getSetting(String key) async {
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) =>
      db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  // places
  Future<List<Place>> places() async => (await db.query('places')).map(Place.fromRow).toList();
  Future<void> savePlace(Place pl) =>
      db.insert('places', pl.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  // trips
  Future<List<Trip>> trips() async =>
      (await db.query('trips', orderBy: 'start_ms DESC')).map(Trip.fromRow).toList();
  Future<void> saveTrip(Trip t) => db.insert('trips', t.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteTrip(String id) => db.delete('trips', where: 'id = ?', whereArgs: [id]);

  Future<void> addPoint(String tripId, DateTime t, double lat, double lng) =>
      db.insert('trip_points', {'trip_id': tripId, 't_ms': t.millisecondsSinceEpoch, 'lat': lat, 'lng': lng});

  Future<List<(double, double)>> points(String tripId) async => (await db.query('trip_points',
          where: 'trip_id = ?', whereArgs: [tripId], orderBy: 't_ms'))
      .map((r) => ((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()))
      .toList();

  // steps
  Future<Map<DateTime, int>> dailySteps() async {
    final rows = await db.query('daily_steps');
    return {
      for (final r in rows) DateTime.fromMillisecondsSinceEpoch(r['day_ms'] as int): r['steps'] as int,
    };
  }

  /// Records a raw step-counter reading (cumulative since boot). The first
  /// reading of the day becomes that day's baseline.
  Future<int> recordStepReading(DateTime now, int cumulative) async {
    final day = dayOf(now).millisecondsSinceEpoch;
    final r = await db.query('daily_steps', where: 'day_ms = ?', whereArgs: [day]);
    int baseline;
    if (r.isEmpty || r.first['baseline'] == null) {
      baseline = cumulative;
    } else {
      baseline = r.first['baseline'] as int;
      if (cumulative < baseline) baseline = cumulative; // phone rebooted
    }
    final steps = cumulative - baseline;
    await db.insert('daily_steps', {'day_ms': day, 'steps': steps, 'baseline': baseline},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return steps;
  }

  // xp
  Future<List<XpEvent>> xpEvents() async => (await db.query('xp_events')).map(XpEvent.fromRow).toList();
  Future<void> addXp(XpEvent e) => db.insert('xp_events', e.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<bool> hasXpFor(String reason, String refId) async =>
      (await db.query('xp_events', where: 'reason = ? AND ref_id = ?', whereArgs: [reason, refId])).isNotEmpty;

  // shop
  Future<List<String>> owned() async =>
      (await db.query('owned_items')).map((r) => r['item_id'] as String).toList();
  Future<void> addOwned(String id, DateTime at) =>
      db.insert('owned_items', {'item_id': id, 'bought_ms': at.millisecondsSinceEpoch});

  // friends
  Future<List<Friend>> friends() async => (await db.query('friends')).map(Friend.fromRow).toList();
  Future<void> saveFriend(Friend f, DateTime at) => db.insert(
      'friends', {...f.toRow(), 'scanned_ms': at.millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace);
}
