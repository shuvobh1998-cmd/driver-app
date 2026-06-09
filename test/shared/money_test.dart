import 'package:driver_app/shared/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPaise', () {
    test('formats paise to rupees with two decimals', () {
      expect(formatPaise(123450), '₹1,234.50');
    });

    test('rounds to the paise', () {
      expect(formatPaise(99), '₹0.99');
      expect(formatPaise(0), '₹0.00');
    });

    test('omits decimals when asked', () {
      expect(formatPaise(50000, showDecimals: false), '₹500');
    });
  });
}
