import 'package:flutter_test/flutter_test.dart';
import '../lib/src/core/license_build.dart';
void main() {
  test('only explicit homologation build may bypass', () {
    if (testLicenseBypassRequested && appEnvironment != 'homologation') {
      expect(validateLicenseBuild, throwsStateError);
      expect(testLicenseBypass, isFalse);
    } else {
      expect(validateLicenseBuild, returnsNormally);
      expect(testLicenseBypass, appEnvironment == 'homologation' && testLicenseBypassRequested);
    }
  });
}
