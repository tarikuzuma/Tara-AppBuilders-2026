/// Every model choice lives here so the runtime/model can be swapped in one place.
class AiConfig {
  /// Text model for understanding + explaining (Cactus slug).
  /// Fallback if too slow on the demo phone: 'gemma3-270m'.
  static const textModel = 'qwen3-0.6';

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
