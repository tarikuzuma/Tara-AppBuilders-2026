import 'dart:convert';

import '../data/models.dart';

const kIntentTypes = [
  'start_trip',
  'stop_trip',
  'can_i_make_it',
  'when_to_leave',
  'how_long',
  'compare_modes',
  'cost',
  'fare_check',
  'log_trip',
  'unknown',
];

/// Structured meaning of a Taglish request. Produced by the on-device LLM,
/// validated and gap-filled by [keywordParse] in code.
class TaraIntent {
  String type;
  String? origin; // place id
  String? destination; // place id
  String? mode;
  int? arriveHour; // 0–23
  int? arriveMinute;
  bool? rain;
  double? fare;
  int? minutes;
  List<String> tags;
  String? note;
  bool strong; // a high-confidence keyword hit decided [type]
  bool fromAi;

  TaraIntent({
    this.type = 'unknown',
    this.origin,
    this.destination,
    this.mode,
    this.arriveHour,
    this.arriveMinute,
    this.rain,
    this.fare,
    this.minutes,
    List<String>? tags,
    this.note,
    this.strong = false,
    this.fromAi = false,
  }) : tags = tags ?? [];

  bool get hasArrival => arriveHour != null;

  String get arriveLabel {
    if (arriveHour == null) return '';
    final h = arriveHour! % 12 == 0 ? 12 : arriveHour! % 12;
    return '$h:${(arriveMinute ?? 0).toString().padLeft(2, '0')} ${arriveHour! < 12 ? 'AM' : 'PM'}';
  }

  Map<String, Object?> toJson() => {
        'intent': type,
        'origin': origin,
        'destination': destination,
        'mode': mode,
        'arrive_by': hasArrival ? '${arriveHour.toString().padLeft(2, '0')}:${(arriveMinute ?? 0).toString().padLeft(2, '0')}' : null,
        'rain': rain,
        'fare': fare,
        'minutes': minutes,
        'tags': tags,
        'note': note,
      };
}

// ---------------------------------------------------------------- keywords

String normalize(String text) {
  var s = text.toLowerCase().replaceAll('’', "'").trim();
  s = s.replaceFirst(RegExp(r'^(hey|hi|uy|oy|ok|okay)?[\s,]*tara[\s,!.:]*'), '');
  return s;
}

bool _any(String s, List<String> words) => words.any((w) => RegExp('(^|[^a-z])${RegExp.escape(w)}([^a-z]|\$)').hasMatch(s));

const _modeWords = <String, List<String>>{
  'jeepney': ['jeep', 'jeepney', 'dyip', 'jip', 'mag-jeep', 'magjeep'],
  'tricycle': ['trike', 'tricycle', 'traysikel', 'tryk', 'mag-trike'],
  'grab': ['grab', 'taxi', 'angkas', 'joyride', 'mag-grab', 'maggrab'],
  'walk': ['walk', 'lakad', 'maglakad', 'naglakad', 'lumakad'],
  'bus': ['bus', 'p2p', 'bus papuntang'],
  'mrt_lrt': ['mrt', 'lrt', 'train', 'tren'],
};

String? detectMode(String s) {
  for (final e in _modeWords.entries) {
    if (_any(s, e.value)) return e.key;
  }
  return null;
}

bool? detectRain(String s) {
  if (_any(s, ['walang ulan', 'no rain', 'hindi umuulan', 'di umuulan', 'maaraw', 'sunny'])) return false;
  if (RegExp(r'(ulan|umuulan|uulan|maulan|rain|bagyo|storm)').hasMatch(s)) return true;
  return null;
}

List<String> detectTags(String s) {
  final tags = <String>[];
  if (RegExp(r'(ulan|umuulan|maulan|rain|bagyo)').hasMatch(s) && detectRain(s) != false) tags.add('rain');
  if (RegExp(r'(traffic|trapik|trapiko|traffik|matrapik|heavy traffic)').hasMatch(s)) tags.add('traffic');
  if (RegExp(r'(baha|flood|binaha)').hasMatch(s)) tags.add('flood');
  return tags;
}

const _alasHours = <String, int>{
  'una': 1, 'dos': 2, 'tres': 3, 'kwatro': 4, 'kuwatro': 4, 'singko': 5, 'sais': 6,
  'siyete': 7, 'syete': 7, 'otso': 8, 'nuwebe': 9, 'nueve': 9, 'diyes': 10, 'dyes': 10, 'onse': 11, 'dose': 12,
};

/// "by 8", "8am", "8:30", "8AM class", "alas-otso" → (hour, minute).
(int, int)? detectArrival(String s) {
  final alas = RegExp(r'alas[\s-]?([a-z]+)').firstMatch(s);
  if (alas != null && _alasHours.containsKey(alas.group(1))) {
    final h = _alasHours[alas.group(1)]!;
    final pm = RegExp(r'(gabi|hapon|pm)').hasMatch(s);
    return (_inferHour(h, pm: pm, am: RegExp(r'(umaga|am)').hasMatch(s)), 0);
  }
  final patterns = [
    RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)'),
    RegExp(r'(?:by|bago|before|until|hanggang|sa|ng|at)\s+(\d{1,2})(?::(\d{2}))?(?!\s*(?:min|mins|minutes|minuto|km|pesos|piso|php))'),
    RegExp(r'(\d{1,2}):(\d{2})'),
    RegExp(r'(\d{1,2})\s*(?:o.?clock)?\s*(?:class|klase|pasok|meeting|shift|work)'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(s);
    if (m == null) continue;
    final h = int.tryParse(m.group(1)!);
    if (h == null || h > 23) continue;
    final minute = m.groupCount >= 2 && m.group(2) != null ? int.tryParse(m.group(2)!) ?? 0 : 0;
    final ampm = m.groupCount >= 3 ? m.group(3) : null;
    final pm = ampm != null && ampm.startsWith('p');
    final am = ampm != null && ampm.startsWith('a');
    return (_inferHour(h, pm: pm, am: am), minute.clamp(0, 59));
  }
  return null;
}

int _inferHour(int h, {bool pm = false, bool am = false}) {
  if (h >= 13) return h;
  if (pm) return h == 12 ? 12 : h + 12;
  if (am) return h == 12 ? 0 : h;
  // No am/pm: commute hours 5–11 are mornings, 1–4 afternoons.
  if (h >= 1 && h <= 4) return h + 12;
  return h;
}

int? detectMinutes(String s) {
  final m = RegExp(r'(\d{1,3})\s*(?:mins?|minutes?|minuto|minutos)\b').firstMatch(s);
  if (m != null) return int.parse(m.group(1)!);
  final hr = RegExp(r'(\d(?:\.\d)?)\s*(?:hrs?|hours?|oras)\b').firstMatch(s);
  if (hr != null) return (double.parse(hr.group(1)!) * 60).round();
  if (RegExp(r'(isang oras|one hour|an hour)').hasMatch(s)) return 60;
  return null;
}

double? detectFare(String s) {
  final patterns = [
    RegExp(r'(?:₱|php|p)\s?(\d{1,5}(?:\.\d{1,2})?)'),
    RegExp(r'(\d{1,5}(?:\.\d{1,2})?)\s*(?:pesos?|piso|php)'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(s);
    if (m != null) return double.parse(m.group(1)!);
  }
  return null;
}

/// Finds saved places mentioned in [s], in order of appearance.
List<(Place, int)> _placeMentions(String s, List<Place> places) {
  final found = <(Place, int)>[];
  for (final p in places) {
    var best = -1;
    for (final name in p.matchNames) {
      final m = RegExp('(^|[^a-z])${RegExp.escape(name)}([^a-z]|\$)').firstMatch(s);
      if (m != null && (best == -1 || m.start < best)) best = m.start;
    }
    if (best >= 0) found.add((p, best));
  }
  found.sort((a, b) => a.$2.compareTo(b.$2));
  return found;
}

/// Fills origin/destination on [intent] from place names and direction words.
void resolvePlaces(String s, List<Place> places, TaraIntent intent) {
  final mentions = _placeMentions(s, places);
  final home = places.where((p) => p.id == 'home').firstOrNull;
  if (RegExp(r'(pauwi|uuwi|umuwi|going home|heading home|pa-uwi)').hasMatch(s) && home != null) {
    intent.destination ??= home.id;
    final others = mentions.where((m) => m.$1.id != home.id).toList();
    if (others.isNotEmpty) intent.origin ??= others.first.$1.id;
    return;
  }
  if (mentions.length >= 2) {
    // "from X to Y", "X to Y", "X papuntang Y"
    intent.origin ??= mentions[0].$1.id;
    intent.destination ??= mentions[1].$1.id;
    final fromIdx = RegExp(r'\b(from|galing|mula)\b').firstMatch(s)?.start;
    if (fromIdx != null && mentions[1].$2 > fromIdx && mentions[0].$2 < fromIdx) {
      intent.origin = mentions[1].$1.id;
      intent.destination = mentions[0].$1.id;
    }
  } else if (mentions.length == 1) {
    final m = mentions.first;
    final before = s.substring(0, m.$2);
    if (RegExp(r'(from|galing|mula)\s*$').hasMatch(before.trimRight() + ' ')) {
      intent.origin ??= m.$1.id;
    } else {
      intent.destination ??= m.$1.id;
    }
  }
}

/// Deterministic Taglish parser. Always runs; the AI result is merged over it.
TaraIntent keywordParse(String text, List<Place> places) {
  final s = normalize(text);
  final i = TaraIntent();
  i.mode = detectMode(s);
  i.rain = detectRain(s);
  i.tags = detectTags(s);
  final arr = detectArrival(s);
  if (arr != null) {
    i.arriveHour = arr.$1;
    i.arriveMinute = arr.$2;
  }
  i.fare = detectFare(s);
  i.minutes = detectMinutes(s);
  resolvePlaces(s, places, i);

  bool strong = true;
  if (RegExp(r'(nandito na|andito na|nakarating na|dumating na|i.?m here|arrived|nasa .* na ako|stop tracking|tapos na biyahe)').hasMatch(s)) {
    i.type = 'stop_trip';
  } else if (RegExp(r'(track|i-track|itrack|papunta ako|pupunta ako|going to|on my way|start trip|biyahe na ako|alis na ako)').hasMatch(s)) {
    i.type = 'start_trip';
  } else if (RegExp(r'(overcharge|sobra|tama ba (ang )?(singil|bayad|presyo)|mahal ba|ripoff|rip-off|scam|lugi)').hasMatch(s) && i.fare != null) {
    i.type = 'fare_check';
  } else if (i.minutes != null && !s.contains('?') &&
      !RegExp(r'(aabot|abot|kailan|gaano|how long|magkano|ilang)').hasMatch(s)) {
    i.type = 'log_trip';
    final noteBits = RegExp(r'(?:traffic|trapik|baha|flood|ulan|rain)[^,.;]*').allMatches(s).map((m) => m.group(0)!.trim()).toList();
    if (noteBits.isNotEmpty) i.note = noteBits.join(', ');
  } else {
    strong = false;
    if (RegExp(r'(\bo\b|\bor\b|\bvs\b|versus|alin.*mas|which.*(faster|better)|mas mabilis|eh kung|what if)').hasMatch(s) && i.mode != null) {
      i.type = RegExp(r'(eh kung|what if|paano kung)').hasMatch(s) ? 'how_long' : 'compare_modes';
    } else if (RegExp(r'(aabot|abot|makakarating|make it|on time|late ba|ma-le-late|malelate|mahuhuli)').hasMatch(s)) {
      i.type = 'can_i_make_it';
    } else if (RegExp(r'(kailan|anong oras|what time|when should|alis ako|umalis|leave)').hasMatch(s)) {
      i.type = 'when_to_leave';
    } else if (RegExp(r'(gaano katagal|how long|ilang minuto|tagal|gaano kabilis)').hasMatch(s)) {
      i.type = 'how_long';
    } else if (RegExp(r'(magkano|how much|presyo|pamasahe|fare|bayad|cost)').hasMatch(s)) {
      i.type = i.fare != null ? 'fare_check' : 'cost';
    } else if (i.hasArrival) {
      i.type = 'can_i_make_it';
    } else if (i.mode != null || i.destination != null) {
      i.type = 'how_long';
    }
  }
  i.strong = strong;
  return i;
}

// ---------------------------------------------------------------- AI JSON

/// Pulls the first {...} object out of a model reply (ignores <think> blocks,
/// code fences and chatter). Returns null if nothing parses.
Map<String, dynamic>? extractJsonObject(String raw) {
  var s = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  final start = s.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  for (var k = start; k < s.length; k++) {
    final c = s[k];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) {
        try {
          final v = jsonDecode(s.substring(start, k + 1));
          return v is Map<String, dynamic> ? v : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

String? _placeIdFor(Object? name, List<Place> places) {
  if (name is! String || name.trim().isEmpty) return null;
  final n = name.toLowerCase().trim();
  for (final p in places) {
    if (p.id == n || p.matchNames.contains(n)) return p.id;
  }
  for (final p in places) {
    if (p.matchNames.any((m) => n.contains(m) || m.contains(n))) return p.id;
  }
  return null;
}

bool _numberInText(num v, String text) {
  final digits = RegExp(r'\d+(?:\.\d+)?').allMatches(text).map((m) => double.parse(m.group(0)!));
  return digits.any((d) => (d - v).abs() < 0.001);
}

/// Merge a validated AI intent over the keyword parse.
/// - type/mode/places/tags: AI wins when valid, unless the keyword hit was strong.
/// - numbers: only accepted if that number literally appears in the user's text.
TaraIntent mergeIntent(TaraIntent base, Map<String, dynamic>? ai, String text, List<Place> places) {
  if (ai == null) return base;
  final out = base..fromAi = true;
  final type = ai['intent'] ?? ai['type'];
  // Keywords decide the type when they can; the AI only resolves what they couldn't.
  if (type is String && kIntentTypes.contains(type) && type != 'unknown' && base.type == 'unknown') out.type = type;

  final mode = ai['mode'];
  if (mode is String && kModes.contains(mode)) out.mode ??= mode;

  out.origin ??= _placeIdFor(ai['origin'], places);
  out.destination ??= _placeIdFor(ai['destination'], places);

  // Weather must be in the words themselves — small models copy prompt examples.
  final rain = ai['rain'];
  if (rain is bool && detectRain(normalize(text)) != null) out.rain ??= rain;

  final arr = ai['arrive_by'];
  if (!out.hasArrival && arr is String) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(arr.trim());
    if (m != null && _numberInText(int.parse(m.group(1)!) % 12 == 0 ? 12 : int.parse(m.group(1)!) % 12, text)) {
      out.arriveHour = int.parse(m.group(1)!).clamp(0, 23);
      out.arriveMinute = int.parse(m.group(2)!).clamp(0, 59);
    }
  }

  final fare = ai['fare'];
  if (out.fare == null && fare is num && _numberInText(fare, text)) out.fare = fare.toDouble();
  final minutes = ai['minutes'];
  if (out.minutes == null && minutes is num && _numberInText(minutes, text)) out.minutes = minutes.round();

  final tags = ai['tags'];
  if (tags is List) {
    for (final t in tags) {
      if (t is String && kTags.contains(t) && !out.tags.contains(t)) out.tags.add(t);
    }
  }
  final note = ai['note'];
  if (out.note == null && note is String && note.trim().isNotEmpty && note.length < 120) out.note = note.trim();
  return out;
}

// ---------------------------------------------------------------- number guard

final _numRe = RegExp(r'\d+(?:[:.,]\d+)*');

Set<String> numbersIn(String text) {
  final out = <String>{};
  for (final m in _numRe.allMatches(text)) {
    final tok = m.group(0)!.replaceAll(',', '');
    out.add(tok);
    if (tok.contains(':')) out.add(tok.split(':').first); // "6:57" also allows "6"
    if (tok.endsWith('.0')) out.add(tok.substring(0, tok.length - 2));
  }
  return out;
}

/// True when every number in [reply] appears in [facts] (or the question).
/// This is what keeps the AI from inventing durations, fares or times.
bool passesNumberGuard(String reply, String facts, String question) {
  final allowed = {...numbersIn(facts), ...numbersIn(question), '0', '1'};
  for (final n in numbersIn(reply)) {
    if (!allowed.contains(n)) return false;
  }
  return true;
}

/// The rewrite must also keep every number from the code-written draft —
/// a reply that silently drops the answer is as bad as one that invents it.
bool keepsDraftNumbers(String reply, String draft) {
  final have = numbersIn(reply);
  return numbersIn(draft).every(have.contains);
}
