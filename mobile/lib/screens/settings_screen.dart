import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    apiUrl.text =
        await ref.read(storeProvider).setting('api_url') ??
        ApiClient.defaultBaseUrl;
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
