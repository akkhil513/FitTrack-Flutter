import 'package:fittrack/services/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses seconds, minutes and ranges', () {
    expect(parseRestSeconds('60s'), 60);
    expect(parseRestSeconds('90 sec'), 90);
    expect(parseRestSeconds('2 min'), 120);
    expect(parseRestSeconds('1-2 min'), 60);
  });

  test('falls back to 60 seconds and caps long rests', () {
    expect(parseRestSeconds(null), 60);
    expect(parseRestSeconds('as needed'), 60);
    expect(parseRestSeconds('30 min'), 600);
  });
}
