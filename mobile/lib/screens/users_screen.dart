import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/access.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> forms = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final store = ref.read(storeProvider);
      final loadedProjects = await store.projects();
      final loadedForms = await store.allForms();
      final loadedUsers = await ref.read(apiProvider).listUsers();
      if (!mounted) return;
      setState(() {
        projects = loadedProjects;
        forms = loadedForms;
        users = loadedUsers;
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Precisa de internet para gerenciar acessos: $exception';
        loading = false;
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? user]) async {
    final saved = await context.push<bool>(
      '/users/editor',
      extra: {'user': user, 'projects': projects, 'forms': forms},
    );
    if (saved == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar acessos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Novo usuario'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PremiumHeader(
              icon: Icons.manage_accounts_rounded,
              title: 'Usuarios e permissoes',
              subtitle: 'Cadastre quem acessa e libere projetos e formularios.',
            ),
            const SizedBox(height: 18),
            if (loading)
              const PremiumSkeleton()
            else if (error != null)
              StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error)
            else if (users.isEmpty)
              const EmptyPanel(icon: Icons.group_off_rounded, title: 'Nenhum usuario', text: 'Toque em "Novo usuario" para cadastrar o primeiro acesso.')
            else
              ...users.map(
                (user) => PremiumCard(
                  onTap: () => _openEditor(user),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE8F5EF),
                        child: Text(
                          initialsFromName(user['name'] as String? ?? '?'),
                          style: const TextStyle(color: brandtGreen, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(user['email'] as String? ?? '-', style: TextStyle(color: Colors.black.withValues(alpha: 0.56))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(roleLabels[roleNameFromUser(user)] ?? roleNameFromUser(user)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${(user['project_ids'] as List<dynamic>? ?? []).length} projetos'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${(user['form_ids'] as List<dynamic>? ?? []).length} forms'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        (user['is_active'] as bool? ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: (user['is_active'] as bool? ?? true) ? brandtGreen : const Color(0xFF9D3D35),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

