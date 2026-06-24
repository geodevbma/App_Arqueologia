import 'poco_teste_choices.dart';
import 'poco_teste_form.dart';
import 'poco_teste_level.dart';

/// A single validation problem, tagged with the section it belongs to so the
/// UI can group and navigate to it.
class ValidationError {
  const ValidationError({
    required this.section,
    required this.field,
    required this.message,
  });

  /// `cabecalho`, `superficie` or `nivel`.
  final String section;
  final String field;
  final String message;

  /// 1-based level index when [section] is `nivel`, otherwise null.
  int? get levelIndex {
    final match = RegExp(r'nivel_(\d+)_').firstMatch(field);
    return match == null ? null : int.parse(match.group(1)!);
  }
}

class ValidationResult {
  const ValidationResult(this.errors);

  final List<ValidationError> errors;

  bool get isValid => errors.isEmpty;

  ValidationError? get first => errors.isEmpty ? null : errors.first;
}

/// Validates a [PocoTesteFormState] for the "Finalizar coleta" action.
///
/// Only currently-relevant (visible) fields are validated; hidden conditional
/// fields never block saving. Drafts skip validation entirely.
class PocoTesteValidator {
  const PocoTesteValidator();

  ValidationResult validateForFinalize(PocoTesteFormState state) {
    final errors = <ValidationError>[];
    _validateHeader(state, errors);
    _validateSurface(state, errors);
    _validateLevels(state, errors);
    return ValidationResult(errors);
  }

  void _validateHeader(PocoTesteFormState state, List<ValidationError> errors) {
    final h = state.header;
    void req(String field, String value, String message) {
      if (value.trim().isEmpty) {
        errors.add(
          ValidationError(section: 'cabecalho', field: field, message: message),
        );
      }
    }

    req('municipio', h.municipio, 'Informe o município.');
    req('sitio', h.sitio, 'Informe o sítio.');
    req('ponto', h.ponto, 'Informe o nome do ponto.');
    req('responsavel', h.responsavel, 'Informe o arqueólogo(a) responsável.');
    if (!h.coordenada.hasValue) {
      errors.add(
        const ValidationError(
          section: 'cabecalho',
          field: 'coordenada',
          message: 'Capture ou informe a coordenada GPS.',
        ),
      );
    }
  }

  void _validateSurface(
    PocoTesteFormState state,
    List<ValidationError> errors,
  ) {
    final s = state.surface;
    void add(String field, String message) => errors.add(
      ValidationError(section: 'superficie', field: field, message: message),
    );

    if (s.fotoSuperficie.isEmpty) {
      add('foto_superficie', 'A foto da superfície é obrigatória.');
    }
    if (s.showOutroCobertura && s.outroCobertura.trim().isEmpty) {
      add('outro_cobertura', 'Descreva a outra cobertura vegetal.');
    }
    if (s.showOutroSolo && s.outroSolo.trim().isEmpty) {
      add('outro_solo', 'Descreva o outro tipo de solo.');
    }
    if (s.materialPresenca == null) {
      add(
        'material_presenca',
        'Informe a presença/ausência de material arqueológico.',
      );
    }
    if (s.hasMaterial) {
      if (s.historico.isEmpty && s.preColonial.isEmpty) {
        add(
          'material',
          'Selecione ao menos uma opção em histórico ou pré-colonial.',
        );
      }
      if (s.fotoMaterial.isEmpty) {
        add('foto_material', 'A foto do material arqueológico é obrigatória.');
      }
      if (s.showOutroHistorico && s.outroHistorico.trim().isEmpty) {
        add('outro_historico', 'Descreva o outro item de histórico.');
      }
      if (s.showOutroPreColonial && s.outroPreColonial.trim().isEmpty) {
        add('outro_pre_colonial', 'Descreva o outro item pré-colonial.');
      }
    }
  }

  void _validateLevels(PocoTesteFormState state, List<ValidationError> errors) {
    if (state.levels.isEmpty) {
      errors.add(
        const ValidationError(
          section: 'nivel',
          field: 'niveis',
          message: 'Adicione ao menos um nível.',
        ),
      );
      return;
    }
    for (var i = 0; i < state.levels.length; i++) {
      final position = i + 1;
      final level = state.levels[i];
      final prefix = 'nivel_${position}_';
      void add(String field, String message) => errors.add(
        ValidationError(
          section: 'nivel',
          field: '$prefix$field',
          message: 'Nível $position: $message',
        ),
      );

      if (PocoTesteLevel.showFotoAberturaPt(position) &&
          level.fotoAberturaPt.isEmpty) {
        add('foto_abertura_pt', 'foto de abertura do PT é obrigatória.');
      }
      if (level.coloracao == null) {
        add('coloracao', 'informe a coloração.');
      } else if (level.showOutroColoracao &&
          level.outroColoracao.trim().isEmpty) {
        add('outro_coloracao', 'descreva a outra coloração.');
      }
      if (level.compactacao == null) {
        add('compactacao', 'informe a compactação.');
      }
      if (level.umidade == null) add('umidade', 'informe a umidade.');
      if (level.textura == null) add('textura', 'informe a textura.');
      if (level.soloCaracteristica.isEmpty) {
        add('solo_caracteristica', 'informe as características do solo.');
      } else if (level.showOutroSoloCaracteristica &&
          level.outroSoloCaracteristica.trim().isEmpty) {
        add('outro_solo_caracteristica', 'descreva a outra característica.');
      }
      if (level.materialPresenca == null) {
        add('material_presenca', 'informe a presença de material.');
      }
      if (level.fotoSolo.isEmpty) {
        add('foto_solo', 'a foto do solo é obrigatória.');
      }
      if (level.fotoPeneira.isEmpty) {
        add('foto_peneira', 'a foto da peneira é obrigatória.');
      }
      if (level.hasMaterial) {
        if (level.fotoMaterial.isEmpty) {
          add('foto_material', 'a foto do material é obrigatória.');
        }
        if (level.profundidadeMaterial.trim().isEmpty) {
          add('profundidade_material', 'informe a profundidade do vestígio.');
        }
        if (level.historico.isEmpty && level.preColonial.isEmpty) {
          add('material', 'selecione histórico ou pré-colonial.');
        }
        if (level.showOutroHistorico && level.outroHistorico.trim().isEmpty) {
          add('outro_historico', 'descreva o outro item de histórico.');
        }
        if (level.showOutroPreColonial &&
            level.outroPreColonial.trim().isEmpty) {
          add('outro_pre_colonial', 'descreva o outro item pré-colonial.');
        }
      }
      if (level.justificativa == null) {
        add('justificativa', 'informe a justificativa.');
      } else {
        if (level.showOutroJustificativa &&
            level.outroJustificativa.trim().isEmpty) {
          add('outro_justificativa', 'descreva a outra justificativa.');
        }
        if (level.showProfundidadeFinal && level.profundidade.trim().isEmpty) {
          add('profundidade', 'informe a profundidade final.');
        }
        if (level.isFinalizacao) {
          if (level.positivo == null) {
            add('positivo', 'informe se o poço foi positivo.');
          }
          if (level.fotoFinalizacao.isEmpty) {
            add('foto_finalizacao', 'a foto de finalização é obrigatória.');
          }
        }
      }
    }
  }

  /// Soft warning (not a blocking error): the last level still says
  /// "alteração de camada", so another level is probably missing.
  bool lastLevelSuggestsAnother(PocoTesteFormState state) {
    if (state.levels.isEmpty) return false;
    return state.levels.last.justificativa ==
        PocoTesteChoices.alteracaoDeCamada;
  }
}
