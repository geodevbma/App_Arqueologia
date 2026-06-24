import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider(false));
    final rows = collections.asData?.value ?? const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Historico')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PremiumHeader(
            icon: Icons.history_rounded,
            title: 'Coletas do aparelho',
            subtitle: 'Historico local mantido em SQLite.',
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const EmptyPanel(
              icon: Icons.assignment_outlined,
              title: 'Sem coletas locais',
              text: 'Preencha um formulario para iniciar o historico.',
            )
          else
            ...rows.map(
              (row) => CollectionTile(
                row: row,
                pending: (row['status_local'] ?? row['sync_status']) != 'synced',
              ),
            ),
        ],
      ),
    );
  }
}
