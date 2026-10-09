/// Every model choice lives here so the runtime/model can be swapped in one place.
class AiConfig {
  /// Text model for understanding Taglish (Cactus slug). Measured on the demo
  /// phone: gemma3-270m ≈ 3 s per request with clean JSON; qwen3-0.6 ≈ 9–18 s.
  static const textModel = 'gemma3-270m';

  /// Let the LLM rewrite code-computed answers in the persona's voice.
  /// Off: at 270M it mostly echoed the question (rejected by the guard) and
  /// added ~4 s. Persona answers come from checked templates instead.
  static const explainWithAi = false;

  /// Speech-to-text (Whisper). Fallback: 'whisper-tiny'.
  static const sttModel = 'whisper-base';

  /// Vision model for Grab screenshots.
  static const visionModel = 'lfm2-vl-450m';
  static const visionEnabled = true;

  static const contextSize = 2048;
  static const temperature = 0.2;

  /// Qwen3 "thinking" is slow on a phone; switch it off.
  static const textUserSuffix = textModel == 'qwen3-0.6' ? ' /no_think' : '';

  /// Whisper decoder prompt. English mode keeps Taglish words as spoken.
  static const whisperPrompt = '<|startoftranscript|><|en|><|transcribe|><|notimestamps|>';
}
