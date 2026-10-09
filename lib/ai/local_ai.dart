import 'dart:io';
import 'dart:ui' as ui;

import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/ai_config.dart';

typedef Progress = void Function(double? fraction, String status);

/// On-device AI behind one interface so the runtime/model can be swapped.
abstract class LocalAI {
  bool get ready;
  Future<void> download({Progress? onProgress});
  Future<String> chat(String system, String user, {int maxTokens = 160});
  Future<String> readImage(String imagePath, String prompt);
  Future<String> transcribe(String wavPath);
  void release();
}

/// Cactus runtime: llama.cpp-style GGUF models running on the phone.
/// Local completion mode only — no cloud fallback, telemetry disabled.
class CactusAI implements LocalAI {
  CactusAI() {
    CactusConfig.isTelemetryEnabled = false;
  }

  final _lm = CactusLM(enableToolFiltering: false);
  final _stt = CactusSTT();
  String? _loaded; // which model is currently in memory
  bool _ready = false;

  @override
  bool get ready => _ready;

  @override
  Future<void> download({Progress? onProgress}) async {
    final steps = [
      (AiConfig.textModel, 'Tara’s brain'),
      (AiConfig.sttModel, 'Tara’s ears'),
      if (AiConfig.visionEnabled) (AiConfig.visionModel, 'Tara’s eyes'),
    ];
    for (var i = 0; i < steps.length; i++) {
      final (slug, label) = steps[i];
      void cb(double? p, String msg, bool err) =>
          onProgress?.call(p == null ? null : (i + p) / steps.length, '$label · $msg');
      if (slug == AiConfig.sttModel) {
        await _stt.downloadModel(model: slug, downloadProcessCallback: cb);
      } else {
        await _lm.downloadModel(model: slug, downloadProcessCallback: cb);
      }
    }
    _ready = true;
  }

  /// Marks models as present (they were downloaded on an earlier launch).
  void markReady() => _ready = true;

  Future<void> _useLm(String slug) async {
    if (_loaded == slug && _lm.isLoaded()) return;
    _lm.unload();
    _stt.unload();
    await _lm.initializeModel(params: CactusInitParams(model: slug, contextSize: AiConfig.contextSize));
    _loaded = slug;
  }

  @override
  Future<String> chat(String system, String user, {int maxTokens = 160}) async {
    await _useLm(AiConfig.textModel);
    _lm.reset();
    final res = await _lm.generateCompletion(
      messages: [
        ChatMessage(role: 'system', content: system),
        ChatMessage(role: 'user', content: '$user${AiConfig.textUserSuffix}'),
      ],
      params: CactusCompletionParams(
        temperature: AiConfig.temperature,
        maxTokens: maxTokens,
        completionMode: CompletionMode.local,
      ),
    );
    debugPrint('[tara-ai] chat ${res.totalTimeMs.round()}ms ${res.tokensPerSecond.toStringAsFixed(1)}tok/s');
    return _clean(res.response);
  }

  @override
  Future<String> readImage(String imagePath, String prompt) async {
    // Full-resolution screenshots blew past 7 GB RAM on the demo phone and got
    // Tara killed; the vision model only needs a small image.
    imagePath = await _downscale(imagePath, AiConfig.visionMaxSide);
    await _useLm(AiConfig.visionModel);
    _lm.reset();
    final res = await _lm.generateCompletion(
      messages: [ChatMessage(role: 'user', content: prompt, images: [imagePath])],
      params: CactusCompletionParams(
        model: AiConfig.visionModel,
        temperature: 0.1,
        maxTokens: 320,
        completionMode: CompletionMode.local,
      ),
    );
    debugPrint('[tara-ai] vision ${res.totalTimeMs.round()}ms');
    return _clean(res.response);
  }

  @override
  Future<String> transcribe(String wavPath) async {
    if (_loaded != AiConfig.sttModel) {
      _lm.unload();
      await _stt.initializeModel(params: CactusInitParams(model: AiConfig.sttModel));
      _loaded = AiConfig.sttModel;
    }
    // Feed raw PCM (parsed from the WAV's data chunk) instead of the file path:
    // the file path decoded only a single word on the demo phone.
    // cactus 1.3.0 pads short clips *after* mel normalisation, so Whisper sees
    // noise for most of its 30 s window and stops after ~1 word. Pad the audio
    // itself with real silence, reset state between clips, cap decoder tokens.
    final pcm = _padTo30s(_wavPcm(await File(wavPath).readAsBytes()));
    _stt.reset();
    final res = await _stt.transcribe(
      audioStream: Stream.value(pcm),
      prompt: AiConfig.whisperPrompt,
      params: CactusTranscriptionParams(maxTokens: 200),
    );
    debugPrint('[tara-ai] stt ${res.totalTimeMs.round()}ms: ${res.text}');
    return res.text.replaceAll(RegExp(r'<\|[^|]*\|>'), '').trim();
  }

  @override
  void release() {
    _lm.unload();
    _stt.unload();
    _loaded = null;
  }

  static Uint8List _padTo30s(Uint8List pcm16) {
    const target = 16000 * 30 * 2; // 30 s of 16 kHz mono s16le
    if (pcm16.length >= target) return Uint8List.sublistView(pcm16, 0, target);
    return Uint8List(target)..setRange(0, pcm16.length, pcm16);
  }

  /// Returns the PCM samples of a 16 kHz mono 16-bit WAV (any header layout).
  static Uint8List _wavPcm(Uint8List b) {
    final d = ByteData.sublistView(b);
    var i = 12;
    while (i + 8 <= b.length) {
      final id = String.fromCharCodes(b.sublist(i, i + 4));
      final size = d.getUint32(i + 4, Endian.little);
      if (id == 'data') return Uint8List.sublistView(b, i + 8, (i + 8 + size).clamp(0, b.length));
      i += 8 + size + (size & 1);
    }
    return Uint8List.sublistView(b, 44);
  }

  static Future<String> _downscale(String path, int maxSide) async {
    final bytes = await File(path).readAsBytes();
    final probe = await ui.instantiateImageCodec(bytes);
    final frame = await probe.getNextFrame();
    final w = frame.image.width, h = frame.image.height;
    frame.image.dispose();
    if (w <= maxSide && h <= maxSide) return path;
    final scale = maxSide / (w > h ? w : h);
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: (w * scale).round(), targetHeight: (h * scale).round());
    final small = (await codec.getNextFrame()).image;
    final png = await small.toByteData(format: ui.ImageByteFormat.png);
    small.dispose();
    final out = File('${(await getTemporaryDirectory()).path}/tara_vision.png');
    await out.writeAsBytes(png!.buffer.asUint8List());
    debugPrint('[tara-ai] downscaled ${w}x$h -> ${(w * scale).round()}x${(h * scale).round()}');
    return out.path;
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').replaceAll(RegExp(r'<\|[^|]*\|>'), '').trim();
}

/// Used when models aren't downloaded (or on the emulator). Every feature
/// still works through the keyword parser and template answers.
class NoAI implements LocalAI {
  @override
  bool get ready => false;
  @override
  Future<void> download({Progress? onProgress}) async {}
  @override
  Future<String> chat(String system, String user, {int maxTokens = 160}) async => '';
  @override
  Future<String> readImage(String imagePath, String prompt) async => '';
  @override
  Future<String> transcribe(String wavPath) async => '';
  @override
  void release() {}
}
