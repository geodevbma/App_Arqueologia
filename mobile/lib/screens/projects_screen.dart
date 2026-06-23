import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(storeProvider).projects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Projetos vinculados')),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(storeProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const PremiumHeader(
                  icon: Icons.explore_rounded,
                  title: 'Campo arqueologico',
                  subtitle:
                      'Selecione um projeto baixado para abrir formularios publicados.',
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const PremiumSkeleton()
                else if (projects.isEmpty)
                  const EmptyPanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'Sem dados locais',
                    text: 'Faca login com internet para baixar o bootstrap.',
                  )
                else
                  ...projects.map(
                    (project) => ProjectCard(
                      project: project,
                      onTap: () => context.push('/forms', extra: project),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
