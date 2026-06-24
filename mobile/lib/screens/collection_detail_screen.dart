import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import '../core/poco_teste_form_descriptor.dart';
import '../models/form_choice.dart';
import '../models/poco_teste_choices.dart';
import '../models/poco_teste_photo.dart';
import '../widgets/app_widgets.dart';

/// Read-only detail of a stored collection, with an option to continue editing
/// when it is still a draft. Renders the "Poço teste" payload in a friendly
/// layout and falls back to a generic view for other forms.
class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({super.key, required this.payload});

  final Map<String, dynamic> payload;

  bool get _isPocoTeste =>
      payload['form_code'] == PocoTesteFormDescriptor.formCode;

  String get _status =>
      (payload['status_local'] ?? payload['status'] ?? 'pending_sync')
          .toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe da coleta')),
      bottomNavigationBar: _status == 'draft' && _isPocoTeste
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: () => _continueDraft(context),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Continuar rascunho'),
              ),
            )
          : null,
      body: _isPocoTeste ? _pocoTesteBody(context) : _genericBody(),
    );
  }

  void _continueDraft(BuildContext context) {
    final project = Map<String, dynamic>.from(payload['project'] as Map? ?? {});
    final form = Map<String, dynamic>.from(payload['form'] as Map? ?? {});
    context.go(
      '/poco-teste',
      extra: {
        'project': {
          'id': payload['project_id'] ?? project['id'],
          'name': project['name'],
          'code': project['code'],
        },
        'form': {
          'id': payload['form_id'] ?? form['id'],
          'name': form['title'] ?? PocoTesteFormDescriptor.formTitle,
          'current_version': form['version'],
        },
        'payload': payload,
      },
    );
  }

  Widget _pocoTesteBody(BuildContext context) {
    final header = Map<String, dynamic>.from(
      payload['cabecalho'] as Map? ?? {},
    );
    final surface = Map<String, dynamic>.from(
      payload['superficie'] as Map? ?? {},
    );
    final levels = (payload['niveis'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumHeader(
          icon: Icons.terrain_rounded,
          title: payload['form_title'] as String? ?? 'Poço teste',
          subtitle: (payload['project'] as Map?)?['name'] as String? ?? '-',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Chip(label: Text(_statusLabel(_status))),
            const SizedBox(width: 8),
            if (payload['pit_positive'] == true)
              const Chip(label: Text('Poço positivo')),
          ],
        ),
        const SizedBox(height: 12),
        _card('Cabeçalho', [
          _row('Data', _formatDate(header['data4'] as String?)),
          _row('Município', _orDash(header['municipio'])),
          _row('Sítio', _orDash(header['sitio'])),
          _row('Ponto', _orDash(header['ponto'])),
          _row('Coord. UTM', _orDash(header['coordenadas_utm'])),
          _row('Coordenada', _coord(header['coordenada'])),
          _row('Responsável', _orDash(header['responsavel'])),
        ]),
        _card('Superfície', [
          _row(
            'Cobertura',
            labelsForValues(
              PocoTesteChoices.coberturaVegetacional,
              _list(surface['cobertura_vegetacional']),
            ),
          ),
          _row(
            'Solo',
            labelForValue(PocoTesteChoices.solo, surface['solo'] as String?),
          ),
          _row(
            'Material',
            labelForValue(
              PocoTesteChoices.materialArqueologicoPresenca,
              surface['material_arqueologico_presenca'] as String?,
            ),
          ),
          _row(
            'Histórico',
            labelsForValues(
              PocoTesteChoices.historico,
              _list(surface['historico']),
            ),
          ),
          _row(
            'Pré-colonial',
            labelsForValues(
              PocoTesteChoices.preColonial,
              _list(surface['pre_colonial']),
            ),
          ),
        ]),
        _photoStrip('Fotos da superfície', [
          ...PocoTestePhoto.listFromJson(surface['foto_superficie']),
          ...PocoTestePhoto.listFromJson(surface['foto_material']),
        ]),
        for (final level in levels) _levelCard(level),
      ],
    );
  }

  Widget _levelCard(Map<String, dynamic> level) {
    final position = level['index'];
    return _card('Nível $position', [
      _row(
        'Coloração',
        labelForValue(
          PocoTesteChoices.coloracao,
          level['coloracao'] as String?,
        ),
      ),
      _row(
        'Compactação',
        labelForValue(
          PocoTesteChoices.compactacao,
          level['compactacao'] as String?,
        ),
      ),
      _row(
        'Umidade',
        labelForValue(PocoTesteChoices.umidade, level['umidade'] as String?),
      ),
      _row(
        'Textura',
        labelForValue(PocoTesteChoices.textura, level['textura'] as String?),
      ),
      _row(
        'Características',
        labelsForValues(
          PocoTesteChoices.soloCaracteristica,
          _list(level['solo_caracteristica']),
        ),
      ),
      _row(
        'Justificativa',
        labelForValue(
          PocoTesteChoices.justificativa,
          level['justificativa'] as String?,
        ),
      ),
      _row('Profundidade', _orDash(level['profundidade'])),
      if (level['positivo'] != null)
        _row(
          'Positivo',
          labelForValue(
            PocoTesteChoices.positivo,
            level['positivo'] as String?,
          ),
        ),
      _photoStrip('Fotos', [
        ...PocoTestePhoto.listFromJson(level['foto_abertura_pt']),
        ...PocoTestePhoto.listFromJson(level['foto_material']),
        ...PocoTestePhoto.listFromJson(level['foto_solo']),
        ...PocoTestePhoto.listFromJson(level['foto_peneira']),
        ...PocoTestePhoto.listFromJson(level['foto_finalizacao']),
      ]),
    ]);
  }

  Widget _genericBody() {
    final answers = (payload['answers'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PremiumHeader(
          icon: Icons.assignment_rounded,
          title: 'Coleta',
          subtitle: 'Detalhe da coleta armazenada localmente.',
        ),
        const SizedBox(height: 16),
        _card('Resumo', [
          _row('Data', _orDash(payload['collection_date'])),
          _row('Status', _statusLabel(_status)),
          for (final answer in answers)
            _row(
              answer['field_key']?.toString() ?? '-',
              answer['answer_value']?.toString() ?? '-',
            ),
        ]),
      ],
    );
  }

  // ---- UI helpers ----

  Widget _card(String title, List<Widget> children) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _photoStrip(String title, List<PocoTestePhoto?> photos) {
    final present = photos.whereType<PocoTestePhoto>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: present.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(present[i].localPath),
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => Container(
                    width: 90,
                    height: 90,
                    color: softBackground,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'draft' => 'Rascunho',
    'pending_sync' => 'Pendente',
    'sync_error' => 'Erro',
    'synced' => 'Sincronizada',
    _ => status,
  };

  List<String> _list(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()).toList() : const [];

  String _orDash(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '' : text;
  }

  String _coord(Object? raw) {
    if (raw is! Map) return '';
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }
}
