import 'package:fittrack/services/supplement_catalog.dart';
import 'package:fittrack/services/supplement_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog entries are valid times with unique names', () {
    final names = <String>{};
    for (final s in supplementCatalog) {
      expect(s.hour, inInclusiveRange(0, 23), reason: s.name);
      expect(s.minute, inInclusiveRange(0, 59), reason: s.name);
      expect(s.hint, isNotEmpty);
      expect(s.name.length, lessThanOrEqualTo(SupplementReminder.maxLabelLength));
      expect(names.add(s.name.toLowerCase()), isTrue, reason: 'duplicate ${s.name}');
    }
  });

  group('catalogMatch', () {
    test('finds an entry anywhere in the text, ignoring case', () {
      expect(catalogMatch('vitamin d3')?.name, 'Vitamin D3');
      expect(catalogMatch('Omega-3, CREATINE')?.name, 'Omega-3');
    });

    test('returns null when nothing matches', () {
      expect(catalogMatch(''), isNull);
      expect(catalogMatch('Ashwagandha'), isNull);
    });
  });

  group('addSupplementName', () {
    test('starts a list', () {
      expect(addSupplementName('', 'Zinc'), 'Zinc');
      expect(addSupplementName('   ', 'Zinc'), 'Zinc');
    });

    test('appends with a comma', () {
      expect(addSupplementName('Vitamin D3', 'Omega-3'), 'Vitamin D3, Omega-3');
    });

    test('does not repeat a name, whatever the case', () {
      expect(addSupplementName('Vitamin D3, Zinc', 'zinc'), 'Vitamin D3, Zinc');
    });

    test('tidies a trailing comma', () {
      expect(addSupplementName('Zinc,', 'Omega-3'), 'Zinc, Omega-3');
    });

    test('never grows past the length limit', () {
      final long = 'x' * 75;
      expect(addSupplementName(long, 'Vitamin D3'), long);
    });
  });
}
