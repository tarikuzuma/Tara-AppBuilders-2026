import 'package:flutter/foundation.dart';

import '../config/ai_config.dart';

import '../data/models.dart';
import '../game/shop.dart';
import '../stats/advisor.dart';
import '../stats/fare_check.dart';
import '../stats/stats_engine.dart';
import 'intent.dart';
import 'local_ai.dart';
import 'prompts.dart';

enum TaraAction { none, startTrip, stopTrip, logTrip }

class Fact {
  final String value;
  final String label;
  const Fact(this.value, this.label);
}

/// Everything the UI needs to render one answer, and to prove where each
/// number came from.
class TaraAnswer {
  final String question;
  final TaraIntent intent;
  String headline = '';
  String text = '';
  List<Fact> facts = [];
  String footer = '';
  List<String> steps = [];
  bool aiUnderstood = false;
  bool aiExplained = false;
  bool guardBlocked = false;
  TaraAction action = TaraAction.none;
  Trip? draft;
  String? followUp;
  String? altMode;

  TaraAnswer(this.question, this.intent);

  String get factsText => facts.map((f) => '${f.label}: ${f.value}').join('\n');
}

class Context {
  final List<Place> places;
  final List<Trip> trips;
  final DateTime now;
  final String persona;
  Context(this.places, this.trips, this.now, this.persona);

  String placeName(String? id) => places.firstWhere((p) => p.id == id, orElse: () => Place(id: '', name: id ?? '?')).name;
}

/// Understand → compute (code) → explain (AI) → guard.
class TaraBrain {
  TaraBrain(this.ai);
  LocalAI ai;
  TaraIntent? _last;

  static const _followUp = r'^(eh|e|paano|pano|how about|what about|what if)\b';

  Future<TaraIntent> understand(String text, Context c, TaraAnswer? into) async {
    var intent = keywordParse(text, c.places);
    if (ai.ready) {
      try {
        final raw = await ai.chat(kIntentSystem, intentPrompt(text, c.places), maxTokens: 60);
        final json = extractJsonObject(raw);
        debugPrint('[tara] intent raw: ${raw.replaceAll('\n', ' ')}');
        intent = mergeIntent(intent, json, text, c.places);
        into?.aiUnderstood = json != null;
      } catch (e) {
        debugPrint('[tara] intent AI failed: $e');
      }
    }
    // Follow-ups like "Eh kung Grab?" inherit the previous question.
    final last = _last;
    if (last != null && RegExp(_followUp).hasMatch(normalize(text))) {
      intent.type = (intent.type == 'unknown' || intent.type == 'how_long') ? last.type : intent.type;
      intent.origin ??= last.origin;
      intent.destination ??= last.destination;
      intent.arriveHour ??= last.arriveHour;
      intent.arriveMinute ??= last.arriveMinute;
      intent.rain ??= last.rain;
    }
    return intent;
  }

  Future<TaraAnswer> ask(String text, Context c, {void Function(TaraAnswer)? onStep}) async {
    final answer = TaraAnswer(text, TaraIntent());
    final intent = await understand(text, c, answer);
    final a = TaraAnswer(text, intent)..aiUnderstood = answer.aiUnderstood;
    a.steps.add('Naintindihan: ${_describe(intent, c)}');
    onStep?.call(a);

    _compute(a, c);
    onStep?.call(a);

    if (AiConfig.explainWithAi && _explainable(intent.type) && ai.ready && a.facts.isNotEmpty) {
      try {
        final style = kPersonaStyle[c.persona] ?? kPersonaStyle['tito']!;
        final reply = await ai.chat(explainSystem(style), explainPrompt(text, a.factsText, a.text), maxTokens: 110);
        final cleaned = reply.replaceAll('"', '').trim();
        debugPrint('[tara] explain raw: $cleaned');
        if (cleaned.isNotEmpty && passesNumberGuard(cleaned, '${a.factsText}\n${a.text}', text)) {
          a.text = cleaned;
          a.aiExplained = true;
        } else if (cleaned.isNotEmpty) {
          a.guardBlocked = true;
          debugPrint('[tara] number guard blocked: $cleaned');
        }
      } catch (e) {
        debugPrint('[tara] explain AI failed: $e');
      }
    }
    if (!a.aiExplained && _explainable(intent.type)) {
      final opener = kPersonaOpener[c.persona] ?? '';
      final body = opener.isEmpty ? a.text : '$opener${a.text[0].toLowerCase()}${a.text.substring(1)}';
      a.text = '$body ${kPersonaSignoff[c.persona] ?? ''}'.trim();
    }
    a.steps.add(a.aiExplained ? 'Sinulat ni Tara ang sagot' : 'Sagot mula sa template (numbers checked)');
    if (intent.type != 'unknown') _last = intent;
    return a;
  }

  bool _explainable(String type) =>
      const ['can_i_make_it', 'when_to_leave', 'how_long', 'compare_modes', 'cost', 'fare_check', 'start_trip']
          .contains(type);

  String _describe(TaraIntent i, Context c) {
    final bits = <String>[
      _typeLabel[i.type] ?? i.type,
      if (i.rain == true) 'ulan',
      if (i.mode != null) modeLabel(i.mode!).toLowerCase(),
      if (i.destination != null) c.placeName(i.destination),
      if (i.hasArrival) i.arriveLabel,
      if (i.fare != null) '₱${i.fare!.round()}',
      if (i.minutes != null) '${i.minutes} min',
    ];
    return bits.join(' + ');
  }

  static const _typeLabel = {
    'start_trip': 'start trip',
    'stop_trip': 'tapos na ang trip',
    'can_i_make_it': 'aabot ba',
    'when_to_leave': 'kailan aalis',
    'how_long': 'gaano katagal',
    'compare_modes': 'compare',
    'cost': 'magkano',
    'fare_check': 'fare check',
    'log_trip': 'log trip',
    'unknown': 'hindi sigurado',
  };

  /// Default route: morning → Home to School, afternoon → School to Home.
  (String, String) _route(TaraIntent i, Context c) {
    final morning = c.now.hour < 12;
    var dest = i.destination ?? (morning ? 'school' : 'home');
    var origin = i.origin ?? (dest == 'home' ? 'school' : 'home');
    if (origin == dest) origin = dest == 'home' ? 'school' : 'home';
    return (origin, dest);
  }

  void _compute(TaraAnswer a, Context c) {
    final i = a.intent;
    final (origin, dest) = _route(i, c);
    final rainTags = i.rain == true ? ['rain'] : <String>[];
    final mode = i.mode ?? usualMode(c.trips, origin, dest) ?? 'jeepney';
    final routeLabel = '${c.placeName(origin)} → ${c.placeName(dest)}';
    final rainy = i.rain == true ? 'Pag umuulan, ' : '';

    switch (i.type) {
      case 'can_i_make_it':
      case 'when_to_leave':
        final arrive = i.hasArrival
            ? _nextAt(c.now, i.arriveHour!, i.arriveMinute ?? 0)
            : nextArrival(c.now, hour: dest == 'home' ? 18 : 8);
        final q = StatsQuery(
            originId: origin,
            destinationId: dest,
            mode: mode,
            bucket: timeBucketOf(arrive.subtract(const Duration(minutes: 60))),
            tags: rainTags);
        final s = statsWithRelaxation(c.trips, q);
        if (s.isEmpty) return _noData(a, routeLabel, mode);
        final v = verdictFor(c.now, arrive, s);
        a.facts = [
          Fact('${s.p80Min}', 'mins · p80'),
          Fact('${s.count}', i.rain == true && !s.relaxed.contains('tags') ? 'rainy trips' : 'past trips'),
          Fact(hhmm(v.leaveBy!), 'leave by'),
        ];
        a.footer = '$routeLabel · ${modeLabel(mode)}${i.rain == true ? ' · Rain' : ''}${_relaxNote(s)}';
        final arriveTxt = hhmm(arrive);
        final m = modeWord(mode);
        switch (v.kind) {
          case VerdictKind.onTime:
            a.headline = 'May oras ka pa.';
            a.text = '${rainy}umaabot ng ${s.p80Min} mins ang $m mo papuntang ${c.placeName(dest)}. '
                'Alis ka by ${hhmm(v.leaveBy!)} para umabot ng $arriveTxt.';
          case VerdictKind.tight:
            a.headline = 'Medyo tight na.';
            a.text = '${rainy}umaabot ng ${s.p80Min} mins ang $m mo. Dapat nakaalis ka by ${hhmm(v.leaveBy!)} '
                'para umabot ng $arriveTxt — alis na!';
          case VerdictKind.late:
            a.headline = 'Late ka na kung $m.';
            a.text = '${rainy}umaabot ng ${s.p80Min} mins ang $m mo, kaya mga ${v.lateByMin} mins kang late sa $arriveTxt.';
            final alt = compareModes(c.trips, q.copyWith(mode: mode))
                .where((o) => o.mode != mode && verdictFor(c.now, arrive, o.stats).kind != VerdictKind.late)
                .firstOrNull;
            if (alt != null) {
              a.altMode = alt.mode;
              a.text += ' ${modeLabel(alt.mode)} na lang? ${alt.stats.p80Min} mins lang'
                  '${alt.stats.avgFare != null ? ', mga ₱${alt.stats.avgFare!.round()}' : ''}.';
              a.facts.add(Fact('${alt.stats.p80Min}', '${modeLabel(alt.mode)} mins'));
              a.followUp = 'Eh kung ${modeLabel(alt.mode)}?';
            }
          case VerdictKind.unknown:
            return _noData(a, routeLabel, mode);
        }
        a.followUp ??= mode == 'grab' ? null : 'Eh kung Grab?';
      case 'how_long':
        final s = statsWithRelaxation(c.trips,
            StatsQuery(originId: origin, destinationId: dest, mode: mode, bucket: timeBucketOf(c.now), tags: rainTags));
        if (s.isEmpty) return _noData(a, routeLabel, mode);
        a.headline = '${modeLabel(mode)}: mga ${s.medianMin} mins.';
        a.text = '${rainy}usually ${s.medianMin} mins ang ${modeWord(mode)} mo from $routeLabel. '
            '80% ng trips mo, under ${s.p80Min} mins.';
        a.facts = [
          Fact('${s.medianMin}', 'mins · median'),
          Fact('${s.p80Min}', 'mins · p80'),
          Fact('${s.count}', 'past trips'),
          if (s.avgFare != null) Fact('₱${s.avgFare!.round()}', 'avg fare'),
        ];
        a.footer = '$routeLabel · ${modeLabel(mode)}${i.rain == true ? ' · Rain' : ''}${_relaxNote(s)}';
      case 'compare_modes':
        final opts = compareModes(c.trips, StatsQuery(originId: origin, destinationId: dest, tags: rainTags));
        if (opts.isEmpty) return _noData(a, routeLabel, mode);
        final best = opts.first;
        a.headline = '${modeLabel(best.mode)} ang mas mabilis.';
        final rest = opts.skip(1).take(2).map((o) => '${modeLabel(o.mode)} ${o.stats.p80Min} mins').join(', ');
        a.text = '${rainy}${modeLabel(best.mode)} ang mas mabilis: ${best.stats.p80Min} mins'
            '${best.stats.avgFare != null ? ' (mga ₱${best.stats.avgFare!.round()})' : ''}'
            '${rest.isNotEmpty ? ' vs $rest' : ''}.';
        a.facts = [
          for (final o in opts.take(3)) Fact('${o.stats.p80Min}', '${modeLabel(o.mode)} mins'),
        ];
        a.footer = '$routeLabel · p80 per mode${i.rain == true ? ' · Rain' : ''}';
      case 'cost':
        final s = statsWithRelaxation(c.trips, StatsQuery(originId: origin, destinationId: dest, mode: mode, tags: rainTags));
        if (s.avgFare == null) return _noData(a, routeLabel, mode);
        a.headline = 'Mga ₱${s.avgFare!.round()} usually.';
        a.text = '${rainy}usually ₱${s.avgFare!.round()} ang ${modeWord(mode)} mo from $routeLabel, '
            'from ₱${s.fares.first.round()} hanggang ₱${s.fares.last.round()}.';
        a.facts = [
          Fact('₱${s.avgFare!.round()}', 'avg fare'),
          Fact('₱${s.fares.first.round()}–${s.fares.last.round()}', 'range'),
          Fact('${s.count}', 'past trips'),
        ];
        a.footer = '$routeLabel · ${modeLabel(mode)}';
      case 'fare_check':
        final fm = i.mode ?? 'tricycle';
        final fc = checkFare(c.trips, origin, dest, fm, i.fare ?? 0);
        final asked = '₱${fc.asked.round()}';
        a.facts = [
          Fact(fc.median == null ? '—' : '₱${fc.median!.round()}', 'median fare'),
          Fact('${fc.pastTrips}', 'past trips'),
          Fact(asked, 'fare asked'),
        ];
        a.footer = '$routeLabel · ${modeLabel(fm)} · Fare history';
        final range = fc.low == null ? '' : '₱${fc.low!.round()}–₱${fc.high!.round()}';
        switch (fc.verdict) {
          case FareVerdict.overcharge:
            a.headline = 'Mukhang overcharge, bes.';
            a.text = 'Usually $range lang ang ${modeWord(fm)} mo sa route na ’to. '
                'Ang $asked ay above sa usual range mo.';
          case FareVerdict.fair:
            a.headline = 'Okay lang ’yan.';
            a.text = 'Pasok ang $asked sa usual range mo na $range.';
          case FareVerdict.cheap:
            a.headline = 'Mura pa nga!';
            a.text = 'Mas mababa ang $asked kaysa usual mo na $range.';
          case FareVerdict.notEnoughData:
            a.headline = 'Kulang pa data.';
            a.text = '${fc.pastTrips} trips pa lang ang may fare sa route na ’to — di ko pa masabi kung overcharge.';
        }
      case 'start_trip':
        if (i.destination == null) {
          a.headline = 'Saan ka papunta?';
          a.text = 'Sabihin mo lang kung saan, hal. “papunta akong school”.';
          return;
        }
        final s = statsWithRelaxation(c.trips, StatsQuery(originId: origin, destinationId: dest, mode: i.mode));
        final tripMode = i.mode ?? usualMode(c.trips, origin, dest) ?? 'jeepney';
        a.action = TaraAction.startTrip;
        a.draft = Trip(
            id: 'live', originId: origin, destinationId: dest, mode: tripMode,
            start: c.now, end: c.now, source: 'tracked');
        a.headline = 'Sige! Tracking na.';
        if (s.isEmpty) {
          a.text = 'Tracking na papuntang ${c.placeName(dest)}. Bago pa ’tong route mo, kaya ’di pa ako sure sa ETA.';
        } else {
          final eta = c.now.add(Duration(minutes: s.medianMin!));
          a.text = 'Tracking na papuntang ${c.placeName(dest)}. Usually ${_dur(s.medianMin!)} by '
              '${modeWord(tripMode)} — ETA mo ${hhmm(eta)}.';
          a.facts = [
            Fact(_dur(s.medianMin!), 'usual time'),
            Fact(hhmm(eta), 'ETA'),
            Fact('${s.count}', 'past trips'),
          ];
          a.footer = '$routeLabel · ${modeLabel(tripMode)} · GPS only while app is open';
        }
      case 'stop_trip':
        a.action = TaraAction.stopTrip;
        a.headline = 'Nice, nakarating ka!';
        a.text = 'I-review natin ang trip mo bago i-save.';
      case 'log_trip':
        final logDest = i.destination ?? dest;
        var logOrigin = i.origin ?? (logDest == 'home' ? 'school' : 'home');
        if (logOrigin == logDest) logOrigin = logDest == 'home' ? 'school' : 'home';
        final mins = i.minutes ?? 30;
        a.action = TaraAction.logTrip;
        a.draft = Trip(
          id: 'draft',
          originId: logOrigin,
          destinationId: logDest,
          mode: i.mode ?? 'jeepney',
          start: c.now.subtract(Duration(minutes: mins)),
          end: c.now,
          fare: i.fare,
          tags: i.tags,
          note: i.note,
          source: a.aiUnderstood ? 'text_ai' : 'manual',
        );
        a.headline = 'Gets ko!';
        a.text = 'I-check mo muna bago i-save.';
      default:
        a.headline = 'Hmm, di ko pa gets.';
        a.text = 'Subukan mo: “aabot ba ako by 8 kung mag-jeep?” o “track mo ako papuntang school”.';
    }
  }

  void _noData(TaraAnswer a, String route, String mode) {
    a.headline = 'Kulang pa data.';
    a.text = 'Wala pa akong ${modeWord(mode)} trips sa $route. I-log mo muna ang ilang biyahe!';
    a.facts = [];
  }

  String _relaxNote(RouteStats s) {
    if (s.relaxed.isEmpty) return '';
    if (s.relaxed.contains('tags')) return ' · kulang rainy trips, all trips used';
    return ' · widened filter';
  }

  DateTime _nextAt(DateTime now, int h, int m) {
    var t = DateTime(now.year, now.month, now.day, h, m);
    if (t.isBefore(now.subtract(const Duration(hours: 3)))) t = t.add(const Duration(days: 1));
    return t;
  }

  String _dur(int mins) => mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '$mins mins';
}
