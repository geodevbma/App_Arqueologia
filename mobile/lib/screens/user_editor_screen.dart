import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/access.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class UserEditorScreen extends ConsumerStatefulWidget {
  const UserEditorScreen({super.key, this.user, required this.projects, required this.forms});
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> forms;

  @override
  ConsumerState<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends ConsumerState<UserEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController password;
  late String role;
  late bool isActive;
  late Set<String> projectIds;
  late Set<String> formIds;
  bool saving = false;
  String? error;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    name = TextEditingController(text: user?['name'] as String? ?? '');
    email = TextEditingController(text: user?['email'] as String? ?? '');
    password = TextEditingController(text: isEditing ? '' : 'Brandt123!');
    role = isEditing ? roleNameFromUser(user) : 'archaeologist';
    if (!roleLabels.containsKey(role)) role = 'archaeologist';
    isActive = user?['is_active'] as bool? ?? true;
    projectIds = ((user?['project_ids'] as List<dynamic>?) ?? []).map((item) => item as String).toSet();
    formIds = ((user?['form_ids'] as List<dynamic>?) ?? []).map((item) => item as String).toSet();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _toggleProject(String projectId, bool checked) {
    setState(() {
      if (checked) {
        projectIds.add(projectId);
      } else {
        projectIds.remove(projectId);
        formIds.removeWhere((formId) {
          final form = widget.forms.firstWhere((item) => item['id'] == formId, orElse: () => const {});
          return form['project_id'] == projectId;
        });
      }
    });
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => error = 'Informe nome e e-mail.');
      return;
    }
    if (!isEditing && password.text.trim().length < 8) {
      setState(() => error = 'Senha inicial precisa de ao menos 8 caracteres.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final payload = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      'role': role,
      'is_active': isActive,
      'project_ids': projectIds.toList(),
      'form_ids': formIds.toList(),
    };
    if (password.text.trim().isNotEmpty) {
      payload['password'] = password.text.trim();
    }
    try {
      final api = ref.read(apiProvider);
      if (isEditing) {
        await api.updateUser(widget.user!['id'] as String, payload);
      } else {
        await api.createUser(payload);
      }
      if (!mounted) return;
      context.pop(true);
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Nao foi possivel salvar: $exception';
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableForms = widget.forms.where((form) {
      final formProjects = (form['project_ids'] as List<dynamic>?)?.cast<String>() ??
          [if (form['project_id'] != null) form['project_id'] as String];
      return formProjects.any(projectIds.contains);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar usuario' : 'Novo usuario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumHeader(
            icon: Icons.badge_rounded,
            title: isEditing ? name.text : 'Novo acesso',
            subtitle: 'Defina perfil e libere projetos e formularios.',
          ),
          const SizedBox(height: 18),
          PremiumCard(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 12),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: InputDecoration(labelText: isEditing ? 'Nova senha (deixe em branco para manter)' : 'Senha inicial'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: roleLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setState(() => role = value ?? role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  title: const Text('Usuario ativo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const SectionTitle(icon: Icons.work_rounded, title: 'Projetos liberados'),
          const SizedBox(height: 8),
          PremiumCard(
            child: widget.projects.isEmpty
                ? const Text('Nenhum projeto disponivel.')
                : Column(
                    children: widget.projects
                        .map(
                          (project) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: projectIds.contains(project['id'] as String),
                            onChanged: (checked) => _toggleProject(project['id'] as String, checked ?? false),
                            title: Text(project['name'] as String? ?? '-'),
                            subtitle: Text(project['code'] as String? ?? project['status'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 6),
          const SectionTitle(icon: Icons.dynamic_form_rounded, title: 'Formularios liberados'),
          const SizedBox(height: 8),
          PremiumCard(
            child: availableForms.isEmpty
                ? const Text('Selecione um projeto para liberar formularios.')
                : Column(
                    children: availableForms
                        .map(
                          (form) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: formIds.contains(form['id'] as String),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                formIds.add(form['id'] as String);
                              } else {
                                formIds.remove(form['id'] as String);
                              }
                            }),
                            title: Text(form['name'] as String? ?? '-'),
                            subtitle: Text('${form['status'] ?? ''}'),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: Text(isEditing ? 'Salvar usuario' : 'Criar usuario'),
          ),
        ],
      ),
    );
  }
}

