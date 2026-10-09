import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'ai/brain.dart';
import 'ai/local_ai.dart';
import 'ai/prompts.dart';
import 'ai/receipt.dart';
import 'ai/receipt.dart';
import 'config/ai_config.dart';
import 'data/db.dart';
import 'data/models.dart';
import 'data/seed.dart';
import 'game/quests.dart';
import 'game/shop.dart';
import 'game/xp_engine.dart';
import 'stats/advisor.dart';
import 'stats/stats_engine.dart';

/// A trip being tracked by GPS while the app is open.
class LiveTrip {
  final Trip draft;
  final List<(double, double)> points = [];
  double km = 0;
  bool arrived = false;
  int? etaMin;
  LiveTrip(this.draft);
}

/// Single source of truth for the app. Plain ChangeNotifier, no framework.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  late TaraDb db;
  LocalAI ai = NoAI();
  late TaraBrain brain;

  List<Place> places = [];
  List<Trip> trips = [];
  List<XpEvent> xpEvents = [];
  List<String> owned = [];
  List<Friend> friends = [];
  Map<DateTime, int> steps = {};
  String persona = kDefaultPersona;
  String name = 'Mia';
  String avatar = '🙂';
  int avatarColor = 0;
  bool demoClock = true;
  bool speakReplies = false;
  bool modelsReady = false;
  bool aiSkipped = false;
  bool rainToggle = true;
  List<Quest> quests = [];
  LiveTrip? live;
  final chat = <TaraAnswer>[];
  final askRequest = ValueNotifier<String?>(null);
  int stepsToday = 0;

  StreamSubscription<Position>? _gps;
  StreamSubscription<StepCount>? _steps;
  final liveTranscript = ValueNotifier<String>('');
  final _speech = SpeechToText();
  bool _speechReady = false;
  String? _speechLocale;
  String? voiceError;
  AudioRecorder? _rec;
  AudioRecorder get _recorder => _rec ??= AudioRecorder();
  final _tts = FlutterTts();

  DateTime get now {
    final real = DateTime.now();
    return demoClock ? DateTime(real.year, real.month, real.day, 7, 5) : real;
  }

  Context get ctx => Context(places, trips, now, persona);
  XpSummary get xp => summarize(xpEvents);
  int get shields => owned.where((o) => o == 'streak_shield').length;
  int get streak => streakDays(trips, now, shields: shields);
  Place place(String id) => places.firstWhere((p) => p.id == id, orElse: () => Place(id: id, name: id));

  int get weeklyXp {
    final start = weekStart(now);
    return xpEvents.where((e) => e.amount > 0 && !e.at.isBefore(start)).fold(0, (a, e) => a + e.amount);
  }

  Future<void> init() async {
    db = await TaraDb.open(now: DateTime.now());
    brain = TaraBrain(ai);
    demoClock = (await db.getSetting('demo_clock')) != '0';
    speakReplies = (await db.getSetting('tts')) == '1';
    aiSkipped = (await db.getSetting('ai_skipped')) == '1';
    if ((await db.getSetting('models_ready')) == '1' || await _modelsOnDisk()) {
      final c = CactusAI()..markReady();
      ai = c;
      brain.ai = c;
      modelsReady = true;
    }
    await reload();
    _startSteps();
  }

  /// Fills state from seed data without a database (widget previews/tests).
  @visibleForTesting
  void preview() {
    final seed = generateSeed(DateTime.now());
    places = defaultPlaces();
    trips = seed.trips..sort((a, b) => b.start.compareTo(a.start));
    xpEvents = seed.xp;
    owned = ['tito'];
    friends = seed.friends;
    steps = seed.steps;
    stepsToday = 6240;
    brain = TaraBrain(ai);
    aiSkipped = true;
    quests = pickQuests(QuestContext(trips, steps, now));
  }

  /// Models live in the app's documents folder; trust the files over the DB flag.
  Future<bool> _modelsOnDisk() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final slug in [AiConfig.textModel]) {
        final d = Directory('${docs.path}/models/$slug');
        if (!d.existsSync() || d.listSync().isEmpty) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> reload() async {
    places = await db.places();
    trips = await db.trips();
    xpEvents = await db.xpEvents();
    owned = await db.owned();
    friends = await db.friends();
    steps = await db.dailySteps();
    persona = (await db.getSetting('persona')) ?? kDefaultPersona;
    name = (await db.getSetting('name')) ?? 'Mia';
    avatar = (await db.getSetting('avatar')) ?? '🙂';
    avatarColor = int.tryParse((await db.getSetting('avatar_color')) ?? '') ?? 0;
    stepsToday = steps[dayOf(now)] ?? stepsToday;
    quests = pickQuests(QuestContext(trips, steps, now));
    notifyListeners();
  }

  // ------------------------------------------------------------ AI models

  Future<void> downloadModels(void Function(double?, String) onProgress) async {
    final c = CactusAI();
    await c.download(onProgress: onProgress);
    ai = c;
    brain.ai = c;
    modelsReady = true;
    await db.setSetting('models_ready', '1');
    notifyListeners();
  }

  Future<void> skipAi() async {
    aiSkipped = true;
    await db.setSetting('ai_skipped', '1');
    notifyListeners();
  }

  Future<TaraAnswer> ask(String text, {void Function(TaraAnswer)? onStep}) async {
    final a = await brain.ask(text, ctx, onStep: onStep);
    if (speakReplies && a.text.isNotEmpty) speak('${a.headline} ${a.text}');
    return a;
  }

  Future<void> speak(String text) async {
    try {
      await _tts.setLanguage('fil-PH');
      await _tts.setSpeechRate(0.5);
      await _tts.speak(text.replaceAll('₱', 'piso '));
    } catch (_) {}
  }

  // ------------------------------------------------------------ voice

  Future<bool> startListening() async {
    liveTranscript.value = '';
    voiceError = null;
    if (AiConfig.voiceEngine == 'android') return _startAndroidSpeech();
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: '${dir.path}/tara_voice.wav',
    );
    return true;
  }

  /// Android's on-device recognizer: audio never leaves the phone.
  Future<bool> _startAndroidSpeech() async {
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onError: (e) {
          debugPrint('[tara-voice] error ${e.errorMsg} locale=$_speechLocale');
          // Offline pack for this language not installed: fall through the list.
          if (e.errorMsg == 'error_language_unavailable' && _nextLocale()) {
            _listenNow();
            return;
          }
          voiceError = e.errorMsg;
        },
        onStatus: (st) => debugPrint('[tara-voice] status $st'),
      );
      if (!_speechReady) return false;
      _availableLocales = (await _speech.locales()).map((l) => l.localeId).toList();
      _localeIdx = -1;
      _nextLocale();
    }
    await _listenNow();
    return true;
  }

  List<String> _availableLocales = [];
  int _localeIdx = -1;

  /// Advances to the next preferred locale this phone lists. False when exhausted.
  bool _nextLocale() {
    final prefs = [...AiConfig.voiceLocales, ..._availableLocales.take(1)];
    while (++_localeIdx < prefs.length) {
      final id = prefs[_localeIdx];
      if (_availableLocales.isEmpty || _availableLocales.contains(id) || _localeIdx >= AiConfig.voiceLocales.length) {
        _speechLocale = id;
        debugPrint('[tara-voice] trying locale $id');
        return true;
      }
    }
    return false;
  }

  Future<void> _listenNow() => _speech.listen(
        onResult: (r) => liveTranscript.value = r.recognizedWords,
        localeId: _speechLocale,
        listenOptions: SpeechListenOptions(
          onDevice: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
          contextualPhrases: AiConfig.voicePhrases,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );

  /// Stops recording and returns the transcript ('' if nothing understood).
  Future<String> stopListening() async {
    if (AiConfig.voiceEngine == 'android') {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 600)); // final result
      debugPrint('[tara-voice] final "${liveTranscript.value}"');
      return liveTranscript.value.trim();
    }
    final path = await _recorder.stop();
    if (path == null || !File(path).existsSync()) return '';
    if (!ai.ready) return '';
    try {
      return await ai.transcribe(path);
    } catch (e) {
      debugPrint('[tara] transcribe failed: $e');
      return '';
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) await _speech.cancel();
    if (_rec != null && await _rec!.isRecording()) await _rec!.stop();
  }

  // ------------------------------------------------------------ diagnostics

  /// Runs every WAV / image in <app docs>/selftest through the real on-device
  /// pipeline and reports transcript, intent and timings. Used to test voice
  /// and vision without speaking into the phone.
  Future<List<String>> selfTest() async {
    final out = <String>[];
    void log(String l) {
      out.add(l);
      debugPrint('[tara-selftest] $l');
    }

    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/selftest');
    if (!dir.existsSync()) {
      log('No selftest folder.');
      return out;
    }
    // Voice clips first, images last (vision is the heaviest model).
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => (a.path.endsWith('.wav') ? '0${a.path}' : '1${a.path}').compareTo(b.path.endsWith('.wav') ? '0${b.path}' : '1${b.path}'));
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final sw = Stopwatch()..start();
      if (name.endsWith('.wav')) {
        final text = await ai.transcribe(f.path);
        final tStt = sw.elapsedMilliseconds;
        final a = await brain.ask(text, ctx);
        log('$name | stt ${tStt}ms "$text" | brain ${sw.elapsedMilliseconds - tStt}ms -> ${a.intent.type} '
            'dest=${a.intent.destination} mode=${a.intent.mode} rain=${a.intent.rain} fare=${a.intent.fare} '
            'min=${a.intent.minutes} | ${a.headline}');
      } else if (name.endsWith('.png') || name.endsWith('.jpg')) {
        final raw = await ai.readImage(f.path, kTripExtractPrompt);
        final r = parseReceipt(raw);
        log('$name | vision ${sw.elapsedMilliseconds}ms -> fare=${r.fare} pickup=${r.pickup} dropoff=${r.dropoff} '
            'min=${r.minutes} | raw: ${raw.replaceAll('\n', ' / ')}');
      }
    }
    return out;
  }

  // ------------------------------------------------------------ trips + XP

  Future<int> saveTrip(Trip t) async {
    await db.saveTrip(t);
    var total = 0;
    for (final a in xpForTrip(t)) {
      await db.addXp(XpEvent(id: '${t.id}-${a.reason}', at: now, amount: a.amount, reason: a.reason, refId: t.id));
      total += a.amount;
    }
    final before = quests.where((q) => q.done).map((q) => q.type).toSet();
    await reload();
    // Quest rewards are paid by code when progress crosses the target.
    for (final q in quests.where((q) => q.done && !before.contains(q.type))) {
      final ref = '${isoWeek(now)}-${q.type}';
      if (!await db.hasXpFor('Quest', ref)) {
        await db.addXp(XpEvent(id: 'quest-$ref', at: now, amount: q.reward, reason: 'Quest', refId: ref));
        total += q.reward;
      }
    }
    final s = streak;
    if (s > 0 && s % 7 == 0 && !await db.hasXpFor('Streak', '${dayOf(now)}')) {
      await db.addXp(XpEvent(id: 'streak-${dayOf(now)}', at: now, amount: kXpStreakBonus, reason: 'Streak', refId: '${dayOf(now)}'));
      total += kXpStreakBonus;
    }
    await reload();
    return total;
  }

  Future<void> deleteTrip(String id) async {
    await db.deleteTrip(id);
    await reload();
  }

  // ------------------------------------------------------------ shop

  Future<String?> buy(ShopItem item) async {
    if (item.isPersona && owned.contains(item.id)) {
      await setPersona(item.id);
      return null;
    }
    if (xp.balance < item.cost) return 'Kulang pa XP mo.';
    await db.addXp(XpEvent(id: 'buy-${item.id}-${DateTime.now().millisecondsSinceEpoch}', at: now, amount: -item.cost, reason: 'Shop: ${item.name}'));
    await db.addOwned(item.id, now);
    if (item.isPersona) await db.setSetting('persona', item.id);
    await reload();
    return null;
  }

  Future<void> setPersona(String id) async {
    await db.setSetting('persona', id);
    await reload();
  }

  Future<void> addFriend(Friend f) async {
    await db.saveFriend(f, now);
    await reload();
  }

  Friend myCard() => Friend(
        name: name,
        week: isoWeek(now),
        xp: weeklyXp,
        steps: _weekSteps(),
        streak: streak,
        level: xp.level,
        title: xp.title,
        avatar: avatar,
        color: avatarColor,
      );

  int _weekSteps() {
    final start = weekStart(now);
    return steps.entries.where((e) => !e.key.isBefore(start)).fold(0, (a, e) => a + e.value);
  }

  // ------------------------------------------------------------ settings

  void setRain(bool v) {
    rainToggle = v;
    notifyListeners();
  }

  Future<void> setDemoClock(bool on) async {
    demoClock = on;
    await db.setSetting('demo_clock', on ? '1' : '0');
    await reload();
  }

  Future<void> setSpeak(bool on) async {
    speakReplies = on;
    await db.setSetting('tts', on ? '1' : '0');
    notifyListeners();
  }

  Future<void> setProfile(String n, String emoji, int color) async {
    await db.setSetting('name', n.trim().isEmpty ? 'Mia' : n.trim());
    await db.setSetting('avatar', emoji);
    await db.setSetting('avatar_color', '$color');
    await reload();
  }

  Future<void> setName(String n) async {
    await db.setSetting('name', n.trim().isEmpty ? 'Mia' : n.trim());
    await reload();
  }

  Future<void> savePlace(Place p) async {
    await db.savePlace(p);
    await reload();
  }

  Future<void> resetDemo() async {
    await db.resetDemo(DateTime.now());
    await reload();
  }

  // ------------------------------------------------------------ steps

  Future<void> _startSteps() async {
    try {
      if (!await Permission.activityRecognition.request().isGranted) return;
      _steps = Pedometer.stepCountStream.listen((e) async {
        stepsToday = await db.recordStepReading(DateTime.now(), e.steps);
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
  }

  // ------------------------------------------------------------ GPS tracking

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
    } catch (_) {
      return null;
    }
  }

  Place? nearestPlace(double lat, double lng, {double withinM = 400}) {
    Place? best;
    var bestD = withinM;
    for (final p in places) {
      if (p.lat == null) continue;
      final d = Geolocator.distanceBetween(lat, lng, p.lat!, p.lng!);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  /// Starts GPS tracking for a voice/typed "start trip". Location is only
  /// read while the app is open and is stored only on this phone.
  Future<String?> startTracking(Trip draft) async {
    if (live != null) return 'May naka-track na na trip.';
    final t = Trip(
        id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
        originId: draft.originId,
        destinationId: draft.destinationId,
        mode: draft.mode,
        start: DateTime.now(),
        end: DateTime.now(),
        source: 'tracked');
    live = LiveTrip(t);
    final s = statsWithRelaxation(trips, StatsQuery(originId: t.originId, destinationId: t.destinationId, mode: t.mode));
    live!.etaMin = s.medianMin;
    notifyListeners();
    final pos = await _position();
    if (pos == null) {
      // Indoors / no fix yet: keep the timer and keep listening for GPS.
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
      ).listen(_addPoint, onError: (_) {});
      notifyListeners();
      return 'Hinahanap pa ang GPS — tuloy ang timer.';
    }
    final near = nearestPlace(pos.latitude, pos.longitude);
    if (near != null && near.id != t.destinationId) t.originId = near.id;
    _addPoint(pos);
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen(_addPoint, onError: (_) {});
    notifyListeners();
    return null;
  }

  void _addPoint(Position p) {
    final l = live;
    if (l == null) return;
    if (l.points.isNotEmpty) {
      final (lat, lng) = l.points.last;
      l.km += Geolocator.distanceBetween(lat, lng, p.latitude, p.longitude) / 1000;
    }
    l.points.add((p.latitude, p.longitude));
    db.addPoint(l.draft.id, DateTime.now(), p.latitude, p.longitude);
    final dest = place(l.draft.destinationId);
    if (dest.lat != null && Geolocator.distanceBetween(p.latitude, p.longitude, dest.lat!, dest.lng!) < 200) {
      l.arrived = true;
    }
    notifyListeners();
  }

  /// Ends tracking and returns the trip for the user to review.
  Trip? stopTracking() {
    final l = live;
    if (l == null) return null;
    _gps?.cancel();
    _gps = null;
    live = null;
    final now = DateTime.now();
    final t = l.draft
      ..end = now.difference(l.draft.start).inMinutes < 1 ? l.draft.start.add(const Duration(minutes: 1)) : now
      ..km = double.parse(l.km.toStringAsFixed(2));
    notifyListeners();
    return t;
  }

  /// The hero card: leave-by for the next class/work, computed by code.
  ({RouteStats stats, Verdict verdict, String mode, String origin, String dest, DateTime arrive}) heroPlan() {
    final morning = now.hour < 12;
    final origin = morning ? 'home' : 'school';
    final dest = morning ? 'school' : 'home';
    final mode = usualMode(trips, origin, dest) ?? 'jeepney';
    final arrive = nextArrival(now, hour: morning ? 8 : 18);
    // "Not raining" should mean dry trips only, not all trips.
    final pool = rainToggle ? trips : trips.where((t) => !t.tags.contains('rain')).toList();
    final s = statsWithRelaxation(
        pool,
        StatsQuery(
            originId: origin,
            destinationId: dest,
            mode: mode,
            bucket: timeBucketOf(arrive.subtract(const Duration(minutes: 60))),
            tags: rainToggle ? ['rain'] : []));
    return (stats: s, verdict: verdictFor(now, arrive, s), mode: mode, origin: origin, dest: dest, arrive: arrive);
  }

  @override
  void dispose() {
    _gps?.cancel();
    _steps?.cancel();
    _rec?.dispose();
    super.dispose();
  }
}
