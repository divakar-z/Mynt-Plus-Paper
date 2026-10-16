import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/utils/cas_indicative.dart';

void main() {
  test('casIndicativeDisplay formats a valid price', () {
    expect(casIndicativeDisplay('1316.00'), '₹1316.00');
  });
  test('casIndicativeDisplay is a dash for null/empty/zero', () {
    expect(casIndicativeDisplay(null), '—');
    expect(casIndicativeDisplay(''), '—');
    expect(casIndicativeDisplay('0'), '—');
    expect(casIndicativeDisplay('0.00'), '—');
    expect(casIndicativeDisplay('null'), '—');
  });
}
