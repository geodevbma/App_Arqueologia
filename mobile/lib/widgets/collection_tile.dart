import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import 'premium_card.dart';

class CollectionTile extends StatelessWidget {
  const CollectionTile({super.key, required this.row, required this.pending});

  final Map<String, dynamic> row;
  final bool pending;

  String get _status =>
      (row['status_local'] ?? row['sync_status'] ?? 'pending_sync').toString();

  bool get _isPocoTeste => row['form_code'] == 'poco_teste';

  @override
  Widget build(BuildContext context) {
    final isDraft = _status == 'draft';
    return PremiumCard(
      onTap: () => context.push('/collection-detail', extra: row),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _avatarColor(),
            child: Icon(_avatarIcon(), color: _iconColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(_subtitle(), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (_isPocoTeste && row['pit_positive'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Poço positivo',
                      style: TextStyle(
                        color: brandtGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Chip(label: Text(_statusLabel())),
          if (isDraft) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.04);
  }

  String _title() {
    if (_isPocoTeste) {
      final header = Map<String, dynamic>.from(row['cabecalho'] as Map? ?? {});
      final parsed = DateTime.tryParse(
        (header['data4'] ?? row['collection_date'] ?? '').toString(),
      );
      final date = parsed != null
          ? DateFormat('dd/MM/yyyy').format(parsed)
          : (row['collection_date']?.toString() ?? '-');
      final ponto = (header['ponto'] ?? '').toString();
      return ponto.isEmpty ? 'Poço teste · $date' : 'Poço teste · $ponto';
    }
    return row['collection_date'] as String? ?? '-';
  }

  String _subtitle() {
    if (_isPocoTeste) {
      final header = Map<String, dynamic>.from(row['cabecalho'] as Map? ?? {});
      final project = (row['project'] as Map?)?['name']?.toString() ?? '';
      final municipio = (header['municipio'] ?? '').toString();
      final sitio = (header['sitio'] ?? '').toString();
      final levels =
          row['level_count'] ?? (row['niveis'] as List?)?.length ?? 0;
      final parts = <String>[
        if (project.isNotEmpty) project,
        if (municipio.isNotEmpty) municipio,
        if (sitio.isNotEmpty) 'Sítio: $sitio',
        '$levels nível(is)',
      ];
      return parts.join(' · ');
    }
    final answers = (row['answers'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return answers
        .firstWhere(
          (item) => item['field_key'] == 'activity_description',
          orElse: () => {'answer_value': 'Sem descrição'},
        )['answer_value']
        .toString();
  }

  String _statusLabel() => switch (_status) {
    'draft' => 'Rascunho',
    'pending_sync' => 'Pendente',
    'sync_error' => 'Erro',
    'synced' => 'Sincronizada',
    _ => _status,
  };

  Color _avatarColor() {
    if (_status == 'synced') return const Color(0xFFE8F5EF);
    if (_status == 'draft') return const Color(0xFFE7EEF5);
    return const Color(0xFFFFE8CC);
  }

  Color _iconColor() {
    if (_status == 'synced') return brandtGreen;
    if (_status == 'draft') return brandtBlue;
    return const Color(0xFF946200);
  }

  IconData _avatarIcon() {
    if (_status == 'synced') return Icons.done_all_rounded;
    if (_status == 'draft') return Icons.edit_note_rounded;
    return Icons.sync_problem_rounded;
  }
}
