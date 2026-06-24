import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/poco_teste_form_descriptor.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class FormProjectsScreen extends ConsumerWidget {
  const FormProjectsScreen({super.key, required this.form});

  final Map<String, dynamic> form;

  Future<List<Map<String, dynamic>>> _projectsForForm(WidgetRef ref) async {
    final projects = await ref.read(storeProvider).projects();
    final ids = <String>{
      ...?(form['project_ids'] as List<dynamic>?)?.cast<String>(),
      if (form['project_id'] != null) form['project_id'] as String,
    };
    // Mostra apenas os projetos vinculados ao colaborador (ja filtrados no
    // bootstrap) que tambem estao publicados para este formulario.
    if (ids.isEmpty) return projects;
    return projects
        .where((project) => ids.contains(project['id']))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projetos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _projectsForForm(ref),
        builder: (context, snapshot) {
          final projects = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PremiumHeader(
                icon: Icons.route_rounded,
                title: form['name'] as String,
                subtitle: 'Selecione o projeto para iniciar a coleta offline.',
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const PremiumSkeleton()
              else if (projects.isEmpty)
                const EmptyPanel(
                  icon: Icons.work_off_outlined,
                  title: 'Nenhum projeto disponivel',
                  text:
                      'Este formulario nao esta publicado em nenhum projeto vinculado a voce.',
                )
              else
                ...projects.map(
                  (project) => ProjectCard(
                    project: project,
                    onTap: () => context.push(
                      PocoTesteFormDescriptor.matches(form)
                          ? '/poco-teste'
                          : '/collect',
                      extra: {'project': project, 'form': form},
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
