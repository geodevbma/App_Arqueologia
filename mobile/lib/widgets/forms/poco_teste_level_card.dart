import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../models/poco_teste_choices.dart';
import '../../models/poco_teste_level.dart';
import '../../models/poco_teste_photo.dart';
import 'brandt_multi_select_field.dart';
import 'brandt_photo_field.dart';
import 'brandt_select_field.dart';
import 'brandt_text_field.dart';

/// Expandable card for one excavation level. It is presentational: every edit
/// produces a new [PocoTesteLevel] via [onChanged]; photo capture is delegated
/// to [capturePhoto].
class PocoTesteLevelCard extends StatelessWidget {
  const PocoTesteLevelCard({
    super.key,
    required this.level,
    required this.position,
    required this.expanded,
    required this.errors,
    required this.onChanged,
    required this.onToggleExpand,
    required this.onRemove,
    required this.capturePhoto,
  });

  final PocoTesteLevel level;
  final int position;
  final bool expanded;

  /// Field-suffix -> message map for this level (prefix `nivel_N_` removed).
  final Map<String, String> errors;
  final ValueChanged<PocoTesteLevel> onChanged;
  final VoidCallback onToggleExpand;

  /// Null when removal is not allowed (single level remaining).
  final VoidCallback? onRemove;

  /// Captures a photo of [type] from [source] and returns its metadata
  /// (or null if canceled).
  final Future<PocoTestePhoto?> Function(String type, ImageSource source)
  capturePhoto;

  /// Appends [source]-captured photo of [type] to [current] via [apply].
  Future<void> _addPhoto(
    String type,
    ImageSource source,
    List<PocoTestePhoto> current,
    PocoTesteLevel Function(List<PocoTestePhoto>) apply,
  ) async {
    final photo = await capturePhoto(type, source);
    if (photo != null) onChanged(apply([...current, photo]));
  }

  String? _err(String field) => errors[field];

  bool get _hasErrors => errors.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _hasErrors
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.6)
              : borderSoft,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggleExpand,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE8F5EF),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: brandtGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
              'Nível $position',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: _hasErrors
                ? Text(
                    '${errors.length} campo(s) pendente(s)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : Text(level.isFinalizacao ? 'Finaliza o poço' : 'Em aberto'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remover nível',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onRemove,
                  ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _body(context),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final widgets = <Widget>[];
    void gap() => widgets.add(const SizedBox(height: 14));

    if (PocoTesteLevel.showProfundidadeInicial(position)) {
      widgets.add(
        BrandtTextField(
          label: 'Qual a profundidade do nível anterior? (cm)',
          hint: 'A profundidade final do nível anterior é o início deste nível',
          initialValue: level.profundidadeInicial,
          decimal: true,
          onChanged: (v) => onChanged(level.copyWith(profundidadeInicial: v)),
        ),
      );
      gap();
    }

    if (PocoTesteLevel.showFotoAberturaPt(position)) {
      widgets.add(
        BrandtPhotoField(
          label: 'Foto de abertura do PT',
          photos: level.fotoAberturaPt,
          errorText: _err('foto_abertura_pt'),
          onAdd: (source) => _addPhoto(
            'foto_abertura_pt',
            source,
            level.fotoAberturaPt,
            (list) => level.copyWith(fotoAberturaPt: list),
          ),
          onRemove: (i) => onChanged(
            level.copyWith(fotoAberturaPt: [...level.fotoAberturaPt]..removeAt(i)),
          ),
        ),
      );
      gap();
    }

    widgets.add(
      BrandtSelectField(
        label: 'Coloração',
        choices: PocoTesteChoices.coloracao,
        value: level.coloracao,
        errorText: _err('coloracao'),
        onChanged: (v) => onChanged(level.copyWith(coloracao: v)),
      ),
    );
    if (level.showOutroColoracao) {
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Outro (coloração)',
          initialValue: level.outroColoracao,
          errorText: _err('outro_coloracao'),
          onChanged: (v) => onChanged(level.copyWith(outroColoracao: v)),
        ),
      );
    }
    gap();

    widgets.add(
      BrandtSelectField(
        label: 'Compactação',
        choices: PocoTesteChoices.compactacao,
        value: level.compactacao,
        errorText: _err('compactacao'),
        onChanged: (v) => onChanged(level.copyWith(compactacao: v)),
      ),
    );
    gap();
    widgets.add(
      BrandtSelectField(
        label: 'Umidade',
        choices: PocoTesteChoices.umidade,
        value: level.umidade,
        errorText: _err('umidade'),
        onChanged: (v) => onChanged(level.copyWith(umidade: v)),
      ),
    );
    gap();
    widgets.add(
      BrandtSelectField(
        label: 'Textura',
        choices: PocoTesteChoices.textura,
        value: level.textura,
        errorText: _err('textura'),
        onChanged: (v) => onChanged(level.copyWith(textura: v)),
      ),
    );
    gap();

    widgets.add(
      BrandtMultiSelectField(
        label: 'Características do Solo (há presença de:)',
        choices: PocoTesteChoices.soloCaracteristica,
        selected: level.soloCaracteristica,
        errorText: _err('solo_caracteristica'),
        onToggle: (value) {
          final next = PocoTesteChoices.applySoloCaracteristicaRule(
            level.soloCaracteristica,
            value,
          );
          onChanged(level.copyWith(soloCaracteristica: next));
        },
      ),
    );
    if (level.showOutroSoloCaracteristica) {
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Outro (especificar)',
          initialValue: level.outroSoloCaracteristica,
          errorText: _err('outro_solo_caracteristica'),
          onChanged: (v) =>
              onChanged(level.copyWith(outroSoloCaracteristica: v)),
        ),
      );
    }
    gap();

    widgets.add(
      BrandtSelectField(
        label: 'Presença/Ausência de material/estrutura arqueológico',
        choices: PocoTesteChoices.materialArqueologicoPresenca,
        value: level.materialPresenca,
        errorText: _err('material_presenca'),
        onChanged: (v) => onChanged(level.copyWith(materialPresenca: v)),
      ),
    );

    if (level.hasMaterial) {
      gap();
      widgets.add(
        BrandtMultiSelectField(
          label: 'Histórico',
          choices: PocoTesteChoices.historico,
          selected: level.historico,
          errorText: _err('material'),
          onToggle: (value) => onChanged(
            level.copyWith(historico: _toggle(level.historico, value)),
          ),
        ),
      );
      if (level.showOutroHistorico) {
        gap();
        widgets.add(
          BrandtTextField(
            label: 'Histórico - outros',
            initialValue: level.outroHistorico,
            errorText: _err('outro_historico'),
            onChanged: (v) => onChanged(level.copyWith(outroHistorico: v)),
          ),
        );
      }
      gap();
      widgets.add(
        BrandtMultiSelectField(
          label: 'Pré-colonial',
          choices: PocoTesteChoices.preColonial,
          selected: level.preColonial,
          onToggle: (value) => onChanged(
            level.copyWith(preColonial: _toggle(level.preColonial, value)),
          ),
        ),
      );
      if (level.showOutroPreColonial) {
        gap();
        widgets.add(
          BrandtTextField(
            label: 'Pré-colonial - outros',
            initialValue: level.outroPreColonial,
            errorText: _err('outro_pre_colonial'),
            onChanged: (v) => onChanged(level.copyWith(outroPreColonial: v)),
          ),
        );
      }
      gap();
      widgets.add(
        BrandtPhotoField(
          label: 'Foto do material/estrutura arqueológico',
          photos: level.fotoMaterial,
          errorText: _err('foto_material'),
          onAdd: (source) => _addPhoto(
            'foto_material_nivel',
            source,
            level.fotoMaterial,
            (list) => level.copyWith(fotoMaterial: list),
          ),
          onRemove: (i) => onChanged(
            level.copyWith(fotoMaterial: [...level.fotoMaterial]..removeAt(i)),
          ),
        ),
      );
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Profundidade do vestígio arqueológico (cm)',
          initialValue: level.profundidadeMaterial,
          decimal: true,
          errorText: _err('profundidade_material'),
          onChanged: (v) => onChanged(level.copyWith(profundidadeMaterial: v)),
        ),
      );
    }
    gap();

    widgets.add(
      BrandtPhotoField(
        label: 'Foto do solo',
        photos: level.fotoSolo,
        errorText: _err('foto_solo'),
        onAdd: (source) => _addPhoto(
          'foto_solo',
          source,
          level.fotoSolo,
          (list) => level.copyWith(fotoSolo: list),
        ),
        onRemove: (i) =>
            onChanged(level.copyWith(fotoSolo: [...level.fotoSolo]..removeAt(i))),
      ),
    );
    gap();
    widgets.add(
      BrandtPhotoField(
        label: 'Foto da peneira',
        photos: level.fotoPeneira,
        errorText: _err('foto_peneira'),
        onAdd: (source) => _addPhoto(
          'foto_peneira',
          source,
          level.fotoPeneira,
          (list) => level.copyWith(fotoPeneira: list),
        ),
        onRemove: (i) => onChanged(
          level.copyWith(fotoPeneira: [...level.fotoPeneira]..removeAt(i)),
        ),
      ),
    );
    gap();

    widgets.add(
      BrandtSelectField(
        label: 'Justificativa',
        choices: PocoTesteChoices.justificativa,
        value: level.justificativa,
        errorText: _err('justificativa'),
        onChanged: (v) => onChanged(level.copyWith(justificativa: v)),
      ),
    );
    if (level.showOutroJustificativa) {
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Justificativa - outros',
          initialValue: level.outroJustificativa,
          errorText: _err('outro_justificativa'),
          onChanged: (v) => onChanged(level.copyWith(outroJustificativa: v)),
        ),
      );
    }
    if (level.showProfundidadeFinal) {
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Profundidade (cm)',
          hint: 'Profundidade final deste nível',
          initialValue: level.profundidade,
          decimal: true,
          errorText: _err('profundidade'),
          onChanged: (v) => onChanged(level.copyWith(profundidade: v)),
        ),
      );
    }
    if (level.showObs) {
      gap();
      widgets.add(
        BrandtTextField(
          label: 'Observação',
          initialValue: level.obs,
          maxLines: 3,
          onChanged: (v) => onChanged(level.copyWith(obs: v)),
        ),
      );
    }
    if (level.isFinalizacao) {
      gap();
      widgets.add(
        BrandtSelectField(
          label: 'Este Poço Teste foi positivo para vestígios/estrutura?',
          choices: PocoTesteChoices.positivo,
          value: level.positivo,
          errorText: _err('positivo'),
          onChanged: (v) => onChanged(level.copyWith(positivo: v)),
        ),
      );
      gap();
      widgets.add(
        BrandtPhotoField(
          label: 'Foto de finalização (com escala e trena)',
          photos: level.fotoFinalizacao,
          errorText: _err('foto_finalizacao'),
          onAdd: (source) => _addPhoto(
            'foto_finalizacao',
            source,
            level.fotoFinalizacao,
            (list) => level.copyWith(fotoFinalizacao: list),
          ),
          onRemove: (i) => onChanged(
            level.copyWith(
              fotoFinalizacao: [...level.fotoFinalizacao]..removeAt(i),
            ),
          ),
        ),
      );
    }

    if (level.justificativa == PocoTesteChoices.alteracaoDeCamada) {
      gap();
      widgets.add(const _LevelHintBanner());
    }

    return widgets;
  }

  List<String> _toggle(List<String> current, String value) {
    final next = List<String>.from(current);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }
}

class _LevelHintBanner extends StatelessWidget {
  const _LevelHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandtBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: brandtBlue, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alteração de camada indica que provavelmente há um próximo nível.',
              style: TextStyle(color: brandtBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
