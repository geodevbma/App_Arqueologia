import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/access.dart';
import '../core/api_client.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final apiUrl = TextEditingController();
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final store = ref.read(storeProvider);
    final loadedUser = await store.user();
    apiUrl.text = await store.setting('api_url') ?? ApiClient.defaultBaseUrl;
    if (mounted) setState(() => _user = loadedUser);
  }

  @override
  void dispose() {
    apiUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PremiumHeader(
            icon: Icons.settings_rounded,
            title: 'Configuracao do app',
            subtitle: 'Parametros locais usados no modo offline-first.',
          ),
          const SizedBox(height: 18),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                  controller: apiUrl,
                  decoration: const InputDecoration(labelText: 'URL da API'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(storeProvider)
                        .setSetting('api_url', apiUrl.text.trim());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL salva.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar URL'),
                ),
              ],
            ),
          ),
          if (canManageAccess(_user)) ...[
            const SizedBox(height: 14),
            PremiumCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_rounded),
                title: const Text('Gerenciar acessos'),
                subtitle: const Text(
                  'Cadastre usuarios e defina projetos e formularios liberados.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/users'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          PremiumCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sair do token atual'),
              subtitle: const Text('Os dados offline permanecem no aparelho.'),
              onTap: () async {
                await ref.read(storeProvider).setSetting('token', '');
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}
