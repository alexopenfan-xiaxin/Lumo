import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/update_checker.dart';

void main() {
  test('compares semantic release versions', () {
    expect(compareVersions('1.2.0', '1.1.0'), isPositive);
    expect(compareVersions('1.1.0', '1.1.0'), isZero);
    expect(compareVersions('1.0.9', '1.1.0'), isNegative);
  });

  test('compares release builds after semantic versions match', () {
    expect(isNewerRelease('1.3.0', 38, '1.3.0', 37), isTrue);
    expect(isNewerRelease('1.3.0', 37, '1.3.0', 37), isFalse);
    expect(isNewerRelease('1.2.9', 99, '1.3.0', 1), isFalse);
  });
}
