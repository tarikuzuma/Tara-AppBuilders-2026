import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../config/ai_config.dart';
import 'local_ai.dart' show Progress;

/// Fully offline speech-to-text with sherpa-onnx (k2-fsa) running Whisper
/// tiny (int8 ONNX). The model (~104 MB) downloads once, the first time the
/// mic is used; after that audio never leaves the phone and no network is
/// needed (works in airplane mode).
class OfflineStt {
  OfflineStt._();
  static final OfflineStt I = OfflineStt._();

  Directory? _dir;
  bool _ready = false;

  Future<Directory> _modelDir() async =>
      _dir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/models/${AiConfig.sherpaModelDir}');

  /// True when every model file is on disk (checked once, then cached).
  Future<bool> isReady() async {
    if (_ready) return true;
    final d = await _modelDir();
    _ready = AiConfig.sherpaFiles.every((f) {
      final file = File('${d.path}/$f');
      return file.existsSync() && file.lengthSync() > 0;
    });
    return _ready;
  }

  Future<void>? _downloading;
  Progress? _onProgress;

  /// Downloads the missing model files. [onProgress] gets 0..1 over all bytes.
  /// A second call while downloading joins the running download.
  Future<void> download({Progress? onProgress}) {
    _onProgress = onProgress;
    return _downloading ??= _download().whenComplete(() => _downloading = null);
  }

  Future<void> _download() async {
    final d = await _modelDir();
    await d.create(recursive: true);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      // Sizes first so the progress bar covers the whole download.
      final sizes = <String, int>{};
      for (final f in AiConfig.sherpaFiles) {
        if (File('${d.path}/$f').existsSync()) continue;
        sizes[f] = AiConfig.sherpaFileSizes[f] ?? 0;
      }
      final total = sizes.values.fold<int>(0, (a, b) => a + b);
      var done = 0;
      for (final f in sizes.keys) {
        final res = await _get(client, Uri.parse('${AiConfig.sherpaBaseUrl}/$f'));
        if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode} for $f');
        final tmp = File('${d.path}/$f.part');
        final sink = tmp.openWrite();
        var got = 0;
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) _onProgress?.call(((done + got) / total).clamp(0, 1).toDouble(), f);
        }
        await sink.close();
        if (res.contentLength > 0 && got != res.contentLength) {
          await tmp.delete();
          throw HttpException('Incomplete download for $f ($got/${res.contentLength})');
        }
        await tmp.rename('${d.path}/$f');
        done += sizes[f]!;
      }
    } finally {
      client.close(force: true);
    }
    _ready = false;
    if (!await isReady()) throw StateError('Voice model files missing after download');
    debugPrint('[tara-voice] sherpa model ready in ${d.path}');
  }

  /// GET with manual redirects (Hugging Face answers with relative Locations).
  static Future<HttpClientResponse> _get(HttpClient client, Uri uri) async {
    for (var hop = 0; hop < 8; hop++) {
      final req = await client.getUrl(uri);
      req.followRedirects = false;
      final res = await req.close();
      if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        await res.drain<void>();
        if (loc == null) throw const HttpException('Redirect without location');
        uri = uri.resolve(loc);
        continue;
      }
      return res;
    }
    throw const HttpException('Too many redirects');
  }

  /// Transcribes a 16 kHz mono 16-bit WAV. Runs in a background isolate so
  /// the UI keeps animating while Whisper decodes.
  Future<String> transcribe(String wavPath) async {
    final d = await _modelDir();
    final sw = Stopwatch()..start();
    final raw = await Isolate.run(() => decodeWav(d.path, wavPath));
    final text = applyVoiceBias(raw);
    debugPrint('[tara-voice] sherpa ${sw.elapsedMilliseconds}ms raw="$raw" -> "$text"');
    return text;
  }

  /// Decodes one WAV with the model in [dir] (sync; call off the UI isolate).
  @visibleForTesting
  static String decodeWav(String dir, String wavPath, {String language = AiConfig.sherpaLanguage}) {
    sherpa.initBindings();
    final pcm = wavPcm(File(wavPath).readAsBytesSync());
    final n = pcm.length ~/ 2;
    if (n < 1600) return ''; // < 0.1 s
    final bd = ByteData.sublistView(pcm);
    final samples = Float32List(n);
    for (var i = 0; i < n; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    final p = AiConfig.sherpaPrefix;
    final rec = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: '$dir/$p-encoder.int8.onnx',
          decoder: '$dir/$p-decoder.int8.onnx',
          language: language,
          task: 'transcribe',
        ),
        tokens: '$dir/$p-tokens.txt',
        numThreads: 4,
        debug: false,
      ),
    ));
    final stream = rec.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      rec.decode(stream);
      return rec.getResult(stream).text.trim();
    } finally {
      stream.free();
      rec.free();
    }
  }
}

/// Returns the PCM samples of a 16 kHz mono 16-bit WAV (any header layout).
/// Tolerates a 0 / oversized data length (header not finalised).
Uint8List wavPcm(Uint8List b) {
  if (b.length < 44) return Uint8List(0);
  final d = ByteData.sublistView(b);
  var i = 12;
  while (i + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(i, i + 4));
    final size = d.getUint32(i + 4, Endian.little);
    if (id == 'data') {
      final end = (size == 0 || i + 8 + size > b.length) ? b.length : i + 8 + size;
      return Uint8List.sublistView(b, i + 8, end);
    }
    i += 8 + size + (size & 1);
  }
  return Uint8List.sublistView(b, 44);
}

/// Whisper has no hotword support, so nudge common mishearings of the words
/// Tara listens for (place names, modes, Taglish phrases) back into shape.
String applyVoiceBias(String s) {
  var t = s.trim();
  for (final (re, to) in _bias) {
    t = t.replaceAll(re, to);
  }
  return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

final _bias = <(RegExp, String)>[
  (RegExp(r'\b(?:hey|hi|hay),?\s+(?:terra|tarah|tera|tara|sara|dara)\b', caseSensitive: false), 'Hey Tara'),
  (RegExp(r'\bL\.?\s?B\.?(?=\W|$)'), 'LB'),
  (RegExp(r'\b(?:el\s?bee|elbee|el\s?bi)\b', caseSensitive: false), 'LB'),
  (RegExp(r'\b(?:jeepney|jip|jeeb)\b', caseSensitive: false), 'jeep'),
  (RegExp(r'\b(?:grab car|grub)\b', caseSensitive: false), 'Grab'),
  (RegExp(r'\bum?u\s?ulan\b', caseSensitive: false), 'umuulan'),
  (RegExp(r'\bnan\s?dito\s?na\s?ako\b', caseSensitive: false), 'nandito na ako'),
  (RegExp(r'\bpa\s?punta\b', caseSensitive: false), 'papunta'),
  (RegExp(r'\bpa\s?uwi\b', caseSensitive: false), 'pauwi'),
  (RegExp(r'\bover\s?-?\s?charge\b', caseSensitive: false), 'overcharge'),
];
