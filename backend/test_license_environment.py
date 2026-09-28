import unittest, os, importlib, asyncio
from unittest.mock import patch

class LicenseEnvironmentTest(unittest.TestCase):
    def load(self, env):
        with patch.dict(os.environ, env, clear=True):
            from app.services import tadeu_metering
            return importlib.reload(tadeu_metering)
    def test_default_production_requires_commercial_token(self):
        module=self.load({'TADEU_LICENSE_ENFORCED':'false'})
        with self.assertRaises(module.HTTPException) as raised:
            asyncio.run(module.check_tadeu_quota(token=None,feature='test'))
        self.assertEqual(raised.exception.status_code,403)
    def test_homologation_never_calls_metering_with_or_without_old_token(self):
        module=self.load({'APP_ENV':'homologation','TEST_LICENSE_BYPASS':'true'})
        with patch.object(module.httpx,'AsyncClient',side_effect=AssertionError('Network call forbidden')):
            for token in [None,'old-commercial-token']:
                self.assertIsNone(asyncio.run(module.check_tadeu_quota(token=token,feature='test')))
                self.assertIsNone(asyncio.run(module.consume_tadeu_usage(token=token,feature='test')))
    def test_production_cannot_request_exemption(self):
        with self.assertRaises(RuntimeError):
            self.load({'APP_ENV':'production','TEST_LICENSE_BYPASS':'true'})

if __name__=='__main__': unittest.main()
