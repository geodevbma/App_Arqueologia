import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class FormsScreen extends ConsumerWidget {
  const FormsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(storeProvider).allForms(),
      builder: (context, snapshot) {
        final forms = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Formularios vinculados')),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(storeProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const PremiumHeader(
                  icon: Icons.dynamic_form_rounded,
                  title: 'Campo arqueologico',
                  subtitle:
                      'Selecione um formulario para escolher o projeto e iniciar a coleta.',
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const PremiumSkeleton()
                else if (forms.isEmpty)
                  const EmptyPanel(
                    icon: Icons.assignment_outlined,
                    title: 'Nenhum formulario vinculado',
                    text:
                        'Solicite o vinculo de um formulario e sincronize novamente.',
                  )
                else
                  ...forms.map(
                    (form) => PremiumCard(
                      onTap: () =>
                          context.push('/form-projects', extra: form),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5EF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
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
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
