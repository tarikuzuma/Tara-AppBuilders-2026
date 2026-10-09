import 'dart:convert';

/// Transport modes Tara understands. Stored as these exact strings.
const kModes = ['jeepney', 'tricycle', 'grab', 'walk', 'bus', 'mrt_lrt'];

const kModeLabels = {
  'jeepney': 'Jeepney',
  'tricycle': 'Tricycle',
  'grab': 'Grab',
  'walk': 'Walk',
  'bus': 'Bus',
  'mrt_lrt': 'MRT/LRT',
};

/// Condition tags a trip can carry.
const kTags = ['rain', 'traffic', 'flood'];

const kTagLabels = {'rain': 'Rain', 'traffic': 'Traffic', 'flood': 'Baha'};

/// Time-of-day buckets used to group trips.
const kBuckets = ['early_morning', 'am_rush', 'midday', 'pm_rush', 'night'];

const kBucketLabels = {
  'early_morning': 'Early morning',
  'am_rush': 'AM rush',
  'midday': 'Midday',
  'pm_rush': 'PM rush',
  'night': 'Night',
};

String timeBucketOf(DateTime t) {
  final m = t.hour * 60 + t.minute;
  if (m >= 4 * 60 && m < 6 * 60 + 30) return 'early_morning';
  if (m >= 6 * 60 + 30 && m < 9 * 60 + 30) return 'am_rush';
  if (m >= 9 * 60 + 30 && m < 16 * 60) return 'midday';
  if (m >= 16 * 60 && m < 20 * 60) return 'pm_rush';
  return 'night';
}

class Place {
  final String id;
  String name;
  List<String> aliases;
  double? lat;
  double? lng;

  Place({required this.id, required this.name, this.aliases = const [], this.lat, this.lng});

  /// All lowercase names this place answers to.
  List<String> get matchNames => [name.toLowerCase(), ...aliases.map((a) => a.toLowerCase())];

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'aliases': jsonEncode(aliases),
        'lat': lat,
        'lng': lng,
      };

  factory Place.fromRow(Map<String, Object?> r) => Place(
        id: r['id'] as String,
        name: r['name'] as String,
        aliases: (jsonDecode((r['aliases'] as String?) ?? '[]') as List).cast<String>(),
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
      );
}

class Trip {
  final String id;
  String originId;
  String destinationId;
  String mode;
  DateTime start;
  DateTime end;
  double? fare;
  String? note;
  List<String> tags;
  String source; // manual | text_ai | voice | image_ai | tracked | seed
  double? km;

  Trip({
    required this.id,
    required this.originId,
    required this.destinationId,
    required this.mode,
    required this.start,
    required this.end,
    this.fare,
    this.note,
    this.tags = const [],
    this.source = 'manual',
    this.km,
  });

  int get minutes => end.difference(start).inMinutes;
  String get timeBucket => timeBucketOf(start);

  Map<String, Object?> toRow() => {
        'id': id,
        'origin_id': originId,
        'destination_id': destinationId,
        'mode': mode,
        'start_ms': start.millisecondsSinceEpoch,
        'end_ms': end.millisecondsSinceEpoch,
        'fare': fare,
        'note': note,
        'tags': tags.join(','),
        'source': source,
        'km': km,
      };

  factory Trip.fromRow(Map<String, Object?> r) => Trip(
        id: r['id'] as String,
        originId: r['origin_id'] as String,
        destinationId: r['destination_id'] as String,
        mode: r['mode'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(r['start_ms'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(r['end_ms'] as int),
        fare: (r['fare'] as num?)?.toDouble(),
        note: r['note'] as String?,
        tags: ((r['tags'] as String?) ?? '').split(',').where((t) => t.isNotEmpty).toList(),
        source: (r['source'] as String?) ?? 'manual',
        km: (r['km'] as num?)?.toDouble(),
      );
}

class XpEvent {
  final String id;
  final DateTime at;
  final int amount;
  final String reason;
  final String? refId;

  XpEvent({required this.id, required this.at, required this.amount, required this.reason, this.refId});

  Map<String, Object?> toRow() =>
      {'id': id, 'at_ms': at.millisecondsSinceEpoch, 'amount': amount, 'reason': reason, 'ref_id': refId};

  factory XpEvent.fromRow(Map<String, Object?> r) => XpEvent(
        id: r['id'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(r['at_ms'] as int),
        amount: r['amount'] as int,
        reason: r['reason'] as String,
        refId: r['ref_id'] as String?,
      );
}

class Friend {
  final String name;
  final String week;
  final int xp;
  final int steps;
  final int streak;
  final int level;
  final String title;
  final String avatar; // emoji
  final int color; // index into kAvatarColors

  Friend({
    required this.name,
    required this.week,
    required this.xp,
    required this.steps,
    required this.streak,
    required this.level,
    required this.title,
    this.avatar = '🙂',
    this.color = 0,
  });

  Map<String, Object?> toRow() => {
        'name': name,
        'week': week,
        'xp': xp,
        'steps': steps,
        'streak': streak,
        'level': level,
        'title': title,
        'avatar': avatar,
        'color': color,
      };

  factory Friend.fromRow(Map<String, Object?> r) => Friend(
        name: r['name'] as String,
        week: r['week'] as String,
        xp: r['xp'] as int,
        steps: r['steps'] as int,
        streak: r['streak'] as int,
        level: r['level'] as int,
        title: r['title'] as String,
        avatar: (r['avatar'] as String?) ?? '🙂',
        color: (r['color'] as int?) ?? 0,
      );
}

/// Avatar choices for the profile (emoji only, nothing uploaded anywhere).
const kAvatarEmojis = ['🙂', '😎', '🧑‍🎓', '👩‍💻', '🧑‍💼', '🐱', '🐶', '🦊', '🐸', '🌻', '⚡', '🚌'];

/// Avatar background colours (ARGB), readable with an emoji on top.
const kAvatarColors = [0xFFD7EF6E, 0xFFBFE3FF, 0xFFFFD6A5, 0xFFFFC2D1, 0xFFCDE8D6, 0xFFE2D4F5];
