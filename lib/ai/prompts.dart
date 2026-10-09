import '../data/models.dart';

const kIntentSystem =
    'You turn a Filipino commuter\'s message (English, Tagalog or Taglish) into JSON. Reply with one JSON object only.';

String intentPrompt(String message, List<Place> places) {
  final ids = places.map((p) => p.id).join('|');
  return '''JSON keys: intent (start_trip|stop_trip|can_i_make_it|when_to_leave|how_long|compare_modes|cost|fare_check|log_trip|unknown), destination ($ids|null), mode (jeepney|tricycle|grab|walk|bus|mrt_lrt|null), rain (true|false|null).
"aabot ba ako sa 8 kung mag-jeep, umuulan" -> {"intent":"can_i_make_it","destination":"school","mode":"jeepney","rain":true}
"$message" ->''';
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
