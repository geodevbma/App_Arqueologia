import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/poco_teste_form_descriptor.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class ProjectFormsScreen extends ConsumerWidget {
  const ProjectFormsScreen({super.key, required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formularios')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref
            .read(storeProvider)
            .formsForProject(project['id'] as String),
        builder: (context, snapshot) {
          final forms = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PremiumHeader(
                icon: Icons.dynamic_form_rounded,
                title: project['name'] as String,
                subtitle: 'Formularios publicados para coleta offline.',
              ),
              const SizedBox(height: 18),
              if (forms.isEmpty)
                const EmptyPanel(
                  icon: Icons.assignment_outlined,
                  title: 'Nenhum formulario publicado',
                  text: 'Publique um formulario no web e sincronize novamente.',
                )
              else
                ...forms.map(
                  (form) => PremiumCard(
                    onTap: () => context.push(
                      PocoTesteFormDescriptor.matches(form)
                          ? '/poco-teste'
                          : '/collect',
                      extra: {'project': project, 'form': form},
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5EF),
                          child: Icon(
                            Icons.assignment_rounded,
                            color: brandtGreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                form['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Versao ${form['current_version']} - ${form['status']}',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.56),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.04),
                ),
            ],
          );
        },
      ),
    );
  }
}
