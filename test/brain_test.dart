import 'package:flutter_test/flutter_test.dart';
import 'package:tara/ai/brain.dart';
import 'package:tara/ai/local_ai.dart';
import 'package:tara/data/seed.dart';

void main() {
  final now = DateTime(2026, 10, 13, 7, 5);
  final seed = generateSeed(now);
  final ctx = Context(defaultPlaces(), seed.trips, now, 'tito');

  for (final q in [
    'Uulan daw, aabot ba ako sa 8AM class ko kung mag-jeep?',
    'Eh kung Grab?',
    'Jeep o Grab pag umuulan?',
    '₱80 sa trike papuntang school, overcharge ba?',
    "Hey Tara, can you track my location now? I'm going to LB bro",
    'jeep pauwi 50 mins ₱15 baha sa España',
    'Magkano usually ang Grab pauwi?',
    'nandito na ako',
  ]) {
    test(q, () async {
      final brain = TaraBrain(NoAI());
      if (q.startsWith('Eh kung')) await brain.ask('Uulan daw, aabot ba ako sa 8AM class ko kung mag-jeep?', ctx);
      final a = await brain.ask(q, ctx);
      // ignore: avoid_print
      print('[${a.intent.type}] ${a.headline} ${a.text}\n   facts: ${a.factsText.replaceAll('\n', ' | ')} · ${a.footer} · action=${a.action}');
      expect(a.intent.type, isNot('unknown'));
    });
  }
}
