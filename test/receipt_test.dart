import 'package:flutter_test/flutter_test.dart';
import 'package:tara/ai/receipt.dart';

void main() {
  test('parses a typical ride receipt', () {
    final r = parseReceipt('Ride receipt\nDate\n10 Oct 2026, 7:11 AM\nPickup\nHome, Cubao, Quezon City\n'
        'Drop-off\nKatipunan Ave (School)\nTrip time\n31 min\nDistance\n6.8 km\nTotal paid ₱248.00');
    expect(r.fare, 248);
    expect(r.pickup, 'Home, Cubao, Quezon City');
    expect(r.dropoff, 'Katipunan Ave (School)');
    expect(r.minutes, 31);
  });
  test('falls back to largest peso amount', () {
    expect(parseReceipt('Base fare P40\nPHP 236.00 charged').fare, 236);
  });
  test('empty text', () {
    expect(parseReceipt('').isEmpty, true);
  });
  test('strips "location:" labels from OCR', () {
    final r = parseReceipt('Pickup location: Home, Cubao\nDrop-off location: Katipunan Ave (School)\nTotal: ₱248.00');
    expect(r.pickup, 'Home, Cubao');
    expect(r.dropoff, 'Katipunan Ave (School)');
    expect(r.fare, 248);
  });
}
