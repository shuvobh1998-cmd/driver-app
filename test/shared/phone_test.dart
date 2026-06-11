import 'package:driver_app/shared/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phone.toE164', () {
    test('prefixes +91 to a 10-digit national number', () {
      expect(Phone.toE164('9876543210'), '+919876543210');
    });
    test('leaves an already-international number unchanged', () {
      expect(Phone.toE164('+919876543210'), '+919876543210');
    });
  });

  group('Phone.toNational', () {
    test('strips +91 from an E.164 number', () {
      expect(Phone.toNational('+919876543210'), '9876543210');
    });
    test('strips a bare 91 country prefix', () {
      expect(Phone.toNational('919876543210'), '9876543210');
    });
    test('passes through a plain 10-digit number', () {
      expect(Phone.toNational('9876543210'), '9876543210');
    });
    test('handles null/empty', () {
      expect(Phone.toNational(null), '');
      expect(Phone.toNational(''), '');
    });
  });
}
