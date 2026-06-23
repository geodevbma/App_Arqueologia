import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/api_client.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(text: 'arqueologo@brandt.local');
  final password = TextEditingController(text: 'Campo123!');
  final apiUrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadApiUrl();
  }

  Future<void> _loadApiUrl() async {
    final saved = await ref.read(storeProvider).setting('api_url');
    if (!mounted) return;
    setState(
      () => apiUrl.text = (saved == null || saved.trim().isEmpty)
          ? ApiClient.defaultBaseUrl
          : saved.trim(),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    apiUrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Persist the API URL before logging in so a first local access works
      // without editing code (the emulator host is http://10.0.2.2:<port>).
      final url = apiUrl.text.trim();
      if (url.isNotEmpty) {
        await ref.read(storeProvider).setSetting('api_url', url);
      }
      await ref.read(apiProvider).login(email.text.trim(), password.text);
      if (mounted) context.go('/sync');
    } on Object catch (exception) {
      setState(() => error = 'Nao foi possivel conectar a API: $exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _offline() async {
    final token = await ref.read(storeProvider).setting('token');
    final count = await ref.read(storeProvider).projectCount();
    if (!mounted) return;
    if (token != null && token.isNotEmpty && count > 0) {
      context.go('/home');
    } else {
      setState(
        () => error = 'Primeiro acesso precisa de internet para baixar dados.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderSoft),
                  boxShadow: [
                    BoxShadow(
                      color: darkForest.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/brandt-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.06),
            const SizedBox(height: 18),
            const PremiumHeader(
              icon: Icons.lock_rounded,
              title: 'Login de campo',
              subtitle: 'Entre uma vez com internet para ativar o uso offline.',
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                children: [
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 4),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: const Text(
                        'Configuração avançada',
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                      children: [
                        TextField(
                          controller: apiUrl,
                          decoration: const InputDecoration(
                            labelText: 'URL da API',
                            helperText:
                                'Emulador: http://10.0.2.2:8000 · Aparelho: http://IP-da-maquina:8000',
                            helperMaxLines: 2,
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    StatusBanner(
                      icon: Icons.error_outline_rounded,
                      text: error!,
                      tone: BannerTone.error,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: loading ? null : _login,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('Entrar e sincronizar'),
                  ),
                  TextButton.icon(
                    onPressed: loading ? null : _offline,
                    icon: const Icon(Icons.cloud_off_rounded),
                    label: const Text('Entrar offline'),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08),
          ],
        ),
      ),
    );
  }
}
