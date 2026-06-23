import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class OutboxScreen extends ConsumerStatefulWidget {
  const OutboxScreen({super.key});

  @override
  ConsumerState<OutboxScreen> createState() => _OutboxScreenState();
}

class _OutboxScreenState extends ConsumerState<OutboxScreen> {
  bool syncing = false;
  String? message;

  Future<void> _sync() async {
    setState(() {
      syncing = true;
      message = null;
    });
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.any((item) => item != ConnectivityResult.none)) {
        setState(() => message = 'Sem internet. Coletas continuam pendentes.');
        return;
      }
      final result = await ref.read(apiProvider).syncPending();
      setState(
        () => message =
            'Sincronizadas: ${(result['synced'] as List).length}. Erros: ${(result['errors'] as List).length}.',
      );
    } on Object catch (exception) {
      setState(() => message = 'Erro de sincronizacao: $exception');
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa de saida')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(storeProvider).collections(onlyPending: true),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PremiumHeader(
                icon: Icons.outbox_rounded,
                title: 'Pendencias de envio',
                subtitle:
                    'Quando houver internet, envie as coletas locais para a API.',
              ),
              const SizedBox(height: 16),
              if (message != null) ...[
                StatusBanner(
                  icon: Icons.info_outline_rounded,
                  text: message!,
                  tone: BannerTone.info,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: syncing ? null : _sync,
                icon: syncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: const Text('Sincronizar agora'),
              ),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                const EmptyPanel(
                  icon: Icons.done_all_rounded,
                  title: 'Tudo sincronizado',
                  text: 'Nao existem coletas pendentes neste aparelho.',
                )
              else
                ...rows.map((row) => CollectionTile(row: row, pending: true)),
            ],
          );
        },
      ),
    );
  }
}
