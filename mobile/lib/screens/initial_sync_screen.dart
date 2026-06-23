import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  String step = 'Preparando sincronizacao inicial';
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      setState(() => step = 'Baixando projetos, trechos, pontos e formularios');
      await ref.read(apiProvider).bootstrap();
      setState(() => step = 'Dados salvos em SQLite');
      await Future<void>.delayed(450.ms);
      if (mounted) context.go('/home');
    } on Object catch (exception) {
      final count = await ref.read(storeProvider).projectCount();
      if (count > 0 && mounted) {
        context.go('/home');
        return;
      }
      setState(() => error = 'Falha no bootstrap: $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PremiumHeader(
                icon: Icons.sync_rounded,
                title: 'Sincronizacao inicial',
                subtitle: step,
              ),
              const SizedBox(height: 28),
              if (error == null)
                const LinearProgressIndicator(minHeight: 8)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms)
              else
                StatusBanner(
                  icon: Icons.error_outline_rounded,
                  text: error!,
                  tone: BannerTone.error,
                ),
              if (error != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sync,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
