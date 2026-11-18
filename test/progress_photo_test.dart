import 'package:fittrack/services/progress_photo.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> raw(String date, String angle, {String key = 'k'}) => {
      'key': '$key-$date-$angle',
      'date': date,
      'angle': angle,
      'url': 'https://example.com/$key',
      'size': 1234,
    };

void main() {
  test('parses good photos and skips bad ones', () {
    final list = ProgressPhoto.parseList([
      raw('2026-11-16', 'front'),
      {'key': 'x'},
      'junk',
      {...raw('2026-11-16', 'side'), 'url': 'http://insecure.example.com/a'},
      {...raw('2026-11-16', 'top')},
      {...raw('16-11-2026', 'front')},
    ]);
    expect(list, hasLength(1));
    expect(list.first.size, 1234);
    expect(ProgressPhoto.parseList('nope'), isEmpty);
    expect(ProgressPhoto.parseList(null), isEmpty);
  });

  test('groups by date, newest first, angles in front/side/back order', () {
    final photos = ProgressPhoto.parseList([
      raw('2026-11-09', 'back'),
      raw('2026-11-16', 'back'),
      raw('2026-11-16', 'front'),
      raw('2026-11-16', 'side'),
    ]);
    final days = groupByDate(photos);
    expect(days.map((d) => d.date), ['2026-11-16', '2026-11-09']);
    expect(days.first.photos.map((p) => p.angle), ['front', 'side', 'back']);
  });

  test('compare puts the older photo first', () {
    final a = ProgressPhoto.tryFromJson(raw('2026-11-16', 'front'))!;
    final b = ProgressPhoto.tryFromJson(raw('2026-11-09', 'front'))!;
    expect(compareOrder(a, b).map((p) => p.date), ['2026-11-09', '2026-11-16']);
    expect(compareOrder(b, a).map((p) => p.date), ['2026-11-09', '2026-11-16']);
  });

  test('angle labels', () {
    expect(ProgressPhoto.angleLabel('front'), 'Front');
    expect(ProgressPhoto.angleLabel('weird'), 'weird');
  });
}
