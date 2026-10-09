import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';

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
    await _useLm(AiConfig.visionModel);
    _lm.reset();
    final res = await _lm.generateCompletion(
      messages: [ChatMessage(role: 'user', content: prompt, images: [imagePath])],
      params: CactusCompletionParams(
        model: AiConfig.visionModel,
        temperature: 0.1,
        maxTokens: 200,
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
    final res = await _stt.transcribe(audioFilePath: wavPath, prompt: AiConfig.whisperPrompt);
    debugPrint('[tara-ai] stt ${res.totalTimeMs.round()}ms: ${res.text}');
    return res.text.replaceAll(RegExp(r'<\|[^|]*\|>'), '').trim();
  }

  @override
  void release() {
    _lm.unload();
    _stt.unload();
    _loaded = null;
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
