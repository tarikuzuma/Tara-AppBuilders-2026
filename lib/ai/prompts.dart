import '../data/models.dart';

const kIntentSystem =
    'You turn a Filipino commuter\'s message (English, Tagalog or Taglish) into JSON. Reply with one JSON object only.';

String intentPrompt(String message, List<Place> places) {
  final names = places.map((p) => '${p.id} (${[p.name, ...p.aliases].join(', ')})').join('; ');
  return '''Schema: {"intent": one of start_trip|stop_trip|can_i_make_it|when_to_leave|how_long|compare_modes|cost|fare_check|log_trip|unknown,
"origin": place id or null, "destination": place id or null,
"mode": jeepney|tricycle|grab|walk|bus|mrt_lrt|null, "arrive_by": "HH:MM" 24h or null,
"rain": true|false|null, "fare": number or null, "minutes": number or null,
"tags": list of rain|traffic|flood, "note": short string or null}
Places: $names
Use null for anything not said. Never guess numbers.
Example: "aabot ba ako sa 8 kung mag-jeep, umuulan" -> {"intent":"can_i_make_it","origin":null,"destination":"school","mode":"jeepney","arrive_by":"08:00","rain":true,"fare":null,"minutes":null,"tags":["rain"],"note":null}
Example: "track mo ako papuntang lb" -> {"intent":"start_trip","origin":null,"destination":"lb","mode":null,"arrive_by":null,"rain":null,"fare":null,"minutes":null,"tags":[],"note":null}
Message: "$message"''';
}

String explainSystem(String personaStyle) => '''$personaStyle
You are Tara, a commute assistant. Answer in Taglish, max 2 short sentences.
Use ONLY the numbers in FACTS, copied exactly. Never add, round or compute numbers.''';

String explainPrompt(String question, String facts, String draft) => '''FACTS:
$facts
QUESTION: "$question"
DRAFT ANSWER: "$draft"
Rewrite the draft answer in your own voice. Keep every number exactly as written.''';

const kTripExtractPrompt =
    'Read this ride-hailing receipt or app screenshot. Reply with JSON only: '
    '{"fare": number or null, "pickup": string or null, "dropoff": string or null, '
    '"minutes": number or null, "time": "HH:MM" or null}. Use null if not visible.';
