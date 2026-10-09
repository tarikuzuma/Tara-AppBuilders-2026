import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tara/ai/offline_stt.dart';

void main() {
  test('voice bias fixes common Whisper mishearings', () {
    expect(applyVoiceBias('Hey Terra, papunta akong L.B.'), 'Hey Tara, papunta akong LB');
    expect(applyVoiceBias('Aabot ba ako by 8 kung mag jeepney?'), 'Aabot ba ako by 8 kung mag jeep?');
    expect(applyVoiceBias('Nan dito na ako'), 'nandito na ako');
    expect(applyVoiceBias('Track my location'), 'Track my location');
  });

  test('wavPcm reads the data chunk and tolerates an unfinished header', () {
    Uint8List wav(int dataSize, int samples) {
      final b = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(Uint8List(4))
        ..add('WAVEfmt '.codeUnits)
        ..add((ByteData(4)..setUint32(0, 16, Endian.little)).buffer.asUint8List())
        ..add(Uint8List(16))
        ..add('data'.codeUnits)
        ..add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List())
        ..add(Uint8List(samples * 2));
      return b.toBytes();
    }

    expect(wavPcm(wav(200, 100)).length, 200);
    expect(wavPcm(wav(0, 100)).length, 200);
  });
}
