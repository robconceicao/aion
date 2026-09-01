import 'package:flutter/material.dart';
import '../../../core/tadeu_license_service.dart';
import '../../../core/theme.dart';

class TadeuLicenseScreen extends StatefulWidget {
  const TadeuLicenseScreen({super.key});

  @override
  State<TadeuLicenseScreen> createState() => _TadeuLicenseScreenState();
}

class _TadeuLicenseScreenState extends State<TadeuLicenseScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tryExistingLicense();
  }

  Future<void> _tryExistingLicense() async {
    if (!TadeuLicenseService.isConfigured) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    try {
      await TadeuLicenseService.restoreSession();
      await TadeuLicenseService.fetchLicense();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
      return;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Informe o e-mail e a senha usados na Tadeu Apps.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await TadeuLicenseService.signIn(email, password);
      await TadeuLicenseService.fetchLicense();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      setState(() {
        _message = text.contains('TADEU_LICENSE_DENIED')
            ? 'Sua conta Tadeu Apps não possui uma assinatura ativa do AION. Ative o plano Gratuito, Pro ou Premium na loja.'
            : 'Não foi possível validar a licença. Confira os dados e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AionTheme.darkVoid,
        body: Center(child: CircularProgressIndicator(color: AionTheme.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TADEU APPS',
                    style: TextStyle(color: AionTheme.gold, letterSpacing: 4, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ativar licença do AION',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use a conta da Tadeu Apps em que você ativou o plano Gratuito, Pro ou Premium.',
                    style: TextStyle(color: AionTheme.silver, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'E-mail Tadeu Apps'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Senha Tadeu Apps'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, style: const TextStyle(color: AionTheme.crimson)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AionTheme.gold,
                      foregroundColor: AionTheme.darkVoid,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('VALIDAR LICENÇA'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Após uma validação online, a licença pode ser reutilizada por até 24 horas sem conexão.',
                    style: TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
