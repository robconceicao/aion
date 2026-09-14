const appEnvironment = String.fromEnvironment('APP_ENV', defaultValue: 'production');
const testLicenseBypassRequested = bool.fromEnvironment('TEST_LICENSE_BYPASS');
const testLicenseBypass = appEnvironment == 'homologation' && testLicenseBypassRequested;

void validateLicenseBuild() {
  if (testLicenseBypassRequested && appEnvironment != 'homologation') {
    throw StateError('TEST_LICENSE_BYPASS is forbidden in production');
  }
}
