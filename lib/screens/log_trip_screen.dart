import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ai/intent.dart';
import '../ai/prompts.dart';
import '../ai/receipt.dart';
import '../app_state.dart';
import '../data/models.dart';
import '../stats/advisor.dart';
import '../ui/components.dart';
import '../ui/theme.dart';

/// Log or review a trip. AI only ever pre-fills; the user always confirms.
class LogTripScreen extends StatefulWidget {
  const LogTripScreen({super.key, this.draft, this.review = false});
  final Trip? draft;
  final bool review;
  @override
  State<LogTripScreen> createState() => _LogTripScreenState();
}

class _LogTripScreenState extends State<LogTripScreen> {
  AppState get s => AppState.I;
  bool smart = true;
  late String origin;
  late String dest;
  late String mode;
  final minutes = TextEditingController();
  final fare = TextEditingController();
  final note = TextEditingController();
  final typed = TextEditingController();
  List<String> tags = [];
  Set<String> aiFilled = {};
  String source = 'manual';
  double? km;
  bool busy = false;
  String? status;
  DateTime? timerStart;
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    origin = d?.originId ?? 'home';
    dest = d?.destinationId ?? 'school';
    mode = d?.mode ?? 'jeepney';
    if (d != null) {
      minutes.text = '${d.minutes}';
      if (d.fare != null) fare.text = d.fare!.round().toString();
      note.text = d.note ?? '';
      tags = List.of(d.tags);
      source = d.source;
      km = d.km;
      if (widget.review && d.source != 'tracked') aiFilled = {'route', 'mode', 'minutes', if (d.fare != null) 'fare', if (d.tags.isNotEmpty) 'tags'};
      smart = false;
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _understand() async {
    final text = typed.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      status = s.ai.ready ? 'Iniintindi on-device…' : 'Iniintindi (basic mode)…';
    });
    final intent = await s.brain.understand(text, s.ctx, null);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (intent.destination != null) dest = intent.destination!;
      origin = intent.origin ?? (dest == 'home' ? 'school' : 'home');
      if (origin == dest) origin = dest == 'home' ? 'school' : 'home';
      if (intent.mode != null) mode = intent.mode!;
      if (intent.minutes != null) minutes.text = '${intent.minutes}';
      if (intent.fare != null) fare.text = intent.fare!.round().toString();
      if (intent.note != null) note.text = intent.note!;
      tags = {...tags, ...intent.tags}.toList();
      aiFilled = {
        if (intent.destination != null) 'route',
        if (intent.mode != null) 'mode',
        if (intent.minutes != null) 'minutes',
        if (intent.fare != null) 'fare',
        if (intent.tags.isNotEmpty) 'tags',
      };
      source = s.ai.ready ? 'text_ai' : 'manual';
      status = aiFilled.isEmpty ? 'Di ko nakuha — punan mo na lang sa baba.' : 'Understood on-device. I-check mo bago i-save.';
    });
  }

  Future<void> _importScreenshot() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (img == null) return;
    if (!s.ai.ready) {
      setState(() => status = 'Kailangan ng AI models para mabasa ang screenshot.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Binabasa ang screenshot on-device… (first time: one-time download ng vision model)';
    });
    try {
      final raw = await s.ai.readImage(img.path, kTripExtractPrompt);
      final r = parseReceipt(raw);
      if (!mounted) return;
      setState(() {
        mode = 'grab';
        aiFilled = {'mode'};
        if (r.fare != null && r.fare! > 0 && r.fare! < 5000) {
          fare.text = r.fare!.round().toString();
          aiFilled.add('fare');
        }
        if (r.minutes != null && r.minutes! > 0 && r.minutes! < 300) {
          minutes.text = '${r.minutes}';
          aiFilled.add('minutes');
        }
        final notes = [r.pickup, r.dropoff].whereType<String>().join(' → ');
        if (notes.isNotEmpty) note.text = notes;
        for (final (key, v) in [('pickup', r.pickup), ('dropoff', r.dropoff)]) {
          if (v == null) continue;
          final i = TaraIntent();
          resolvePlaces(v.toLowerCase(), s.places, i);
          if (i.destination != null) {
            if (key == 'pickup') origin = i.destination!;
            if (key == 'dropoff') dest = i.destination!;
            aiFilled.add('route');
          }
        }
        source = 'image_ai';
        status = aiFilled.length > 1 ? 'Nabasa ang screenshot. I-check mo bago i-save.' : 'Konti lang nabasa — punan mo na lang.';
        busy = false;
        smart = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        busy = false;
        status = 'Hindi nabasa ang screenshot. Punan mo na lang.';
      });
    }
  }

  void _toggleTimer() {
    if (timerStart == null) {
      setState(() => timerStart = DateTime.now());
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else {
      ticker?.cancel();
      final mins = DateTime.now().difference(timerStart!).inMinutes;
      setState(() {
        minutes.text = '${mins < 1 ? 1 : mins}';
        timerStart = null;
      });
    }
  }

  Future<void> _save() async {
    final mins = int.tryParse(minutes.text.trim());
    if (mins == null || mins <= 0 || mins > 600) {
      setState(() => status = 'Ilagay ang tagal ng biyahe (minutes).');
      return;
    }
    if (origin == dest) {
      setState(() => status = 'Magkaiba dapat ang from at to.');
      return;
    }
    final end = widget.draft?.source == 'tracked' ? widget.draft!.end : s.now;
    final t = Trip(
      id: widget.draft?.source == 'tracked' ? widget.draft!.id : 'trip-${DateTime.now().millisecondsSinceEpoch}',
      originId: origin,
      destinationId: dest,
      mode: mode,
      start: end.subtract(Duration(minutes: mins)),
      end: end,
      fare: double.tryParse(fare.text.trim()),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      tags: tags,
      source: source,
      km: km,
    );
    final nav = Navigator.of(context);
    final ctx = context;
    final xp = await s.saveTrip(t);
    if (!ctx.mounted) return;
    showXpToast(ctx, xp, tags.isNotEmpty ? 'Trip + condition tag' : 'Trip logged');
    nav.pop();
  }

  Widget _aiMark(String field) => aiFilled.contains(field)
      ? Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: T.lime, borderRadius: BorderRadius.circular(6)),
          child: Text('AI', style: T.b(11, w: FontWeight.w800)),
        )
      : const SizedBox();

  Widget _label(String text, [String? field]) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [Text(text.toUpperCase(), style: T.kicker(color: T.muted)), if (field != null) _aiMark(field)]),
      );

  @override
  Widget build(BuildContext context) {
    final placeItems = [for (final p in s.places) DropdownMenuItem(value: p.id, child: Text(p.name, style: T.b(16, w: FontWeight.w600)))];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: T.cream,
        surfaceTintColor: T.cream,
        title: Text(widget.review ? 'I-review ang trip' : 'Kamusta ang biyahe?', style: T.h(20)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
          if (!widget.review) ...[
            Text('I-type mo lang naturally. Ikaw pa rin ang magco-confirm.', style: T.b(15, color: T.muted)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFE9E8E1), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                _tab('Type-a-trip', Icons.auto_awesome, smart, () => setState(() => smart = true)),
                _tab('Manual', Icons.timer_outlined, !smart, () => setState(() => smart = false)),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.review && widget.draft?.source != 'tracked')
            CardBox(
              color: T.oliveSoft,
              border: T.oliveLine,
              padding: 12,
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: T.olive, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Si Tara ang nag-fill ng may “AI” tag. I-check mo bago i-save.', style: T.b(14, color: T.olive, w: FontWeight.w600))),
              ]),
            ),
          if (widget.draft?.source == 'tracked')
            CardBox(
              color: T.oliveSoft,
              border: T.oliveLine,
              padding: 12,
              child: Text('Tracked trip · ${km?.toStringAsFixed(1) ?? '0'} km · GPS stayed on this phone.',
                  style: T.b(14, color: T.olive, w: FontWeight.w600)),
            ),
          if (smart && !widget.review) ...[
            TextField(
              controller: typed,
              minLines: 2,
              maxLines: 3,
              style: T.b(16),
              decoration: const InputDecoration(hintText: '“jeep pauwi 50 mins ₱15 baha sa España”'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: PrimaryButton('Fill the form', icon: Icons.auto_awesome, onTap: busy ? null : _understand)),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: T.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: busy ? null : _importScreenshot,
                  icon: const Icon(Icons.image_outlined, color: T.ink),
                  label: Text('Grab\nscreenshot', style: T.b(12, w: FontWeight.w700), textAlign: TextAlign.center),
                ),
              ),
            ]),
          ],
          if (!smart && !widget.review) ...[
            CardBox(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(timerStart == null ? 'Trip timer' : 'Nasa biyahe…', style: T.h(16, w: FontWeight.w700)),
                    Text(
                      timerStart == null
                          ? 'Start pag sumakay ka na'
                          : _fmtElapsed(DateTime.now().difference(timerStart!)),
                      style: T.b(14, color: T.muted),
                    ),
                  ]),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: timerStart == null ? T.ink : T.red, minimumSize: const Size(96, 48)),
                  onPressed: _toggleTimer,
                  child: Text(timerStart == null ? 'Start' : 'Stop', style: T.b(15, color: Colors.white, w: FontWeight.w700)),
                ),
              ]),
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: T.olive)),
              if (!busy) const Icon(Icons.info_outline, size: 16, color: T.olive),
              const SizedBox(width: 8),
              Expanded(child: Text(status!, style: T.b(14, color: T.olive, w: FontWeight.w600))),
            ]),
          ],
          _label('Route', 'route'),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: origin, items: placeItems, onChanged: (v) => setState(() => origin = v!))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: T.olive)),
            Expanded(child: DropdownButtonFormField<String>(initialValue: dest, items: placeItems, onChanged: (v) => setState(() => dest = v!))),
          ]),
          _label('Mode', 'mode'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in kModes) Pill(modeLabel(m), icon: modeIcon(m), selected: mode == m, onTap: () => setState(() => mode = m)),
          ]),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Duration (min)', 'minutes'),
                TextField(controller: minutes, keyboardType: TextInputType.number, style: T.b(17, w: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Fare (₱)', 'fare'),
                TextField(controller: fare, keyboardType: TextInputType.number, style: T.b(17, w: FontWeight.w600)),
              ]),
            ),
          ]),
          _label('Conditions', 'tags'),
          Wrap(spacing: 8, children: [
            for (final t in kTags)
              Pill(kTagLabels[t]!, icon: tagIcon(t), selected: tags.contains(t), onTap: () {
                setState(() => tags.contains(t) ? tags.remove(t) : tags.add(t));
              }),
          ]),
          _label('Note'),
          TextField(controller: note, style: T.b(16), decoration: const InputDecoration(hintText: 'hal. baha sa España')),
          const SizedBox(height: 22),
          PrimaryButton('Confirm & save trip', icon: Icons.check, onTap: busy ? null : _save),
        ]),
      ),
    );
  }

  String _fmtElapsed(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _tab(String label, IconData icon, bool active, VoidCallback onTap) => Expanded(
        child: Material(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: active ? T.olive : T.muted),
                const SizedBox(width: 6),
                Text(label, style: T.b(15, color: active ? T.olive : T.muted, w: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}
