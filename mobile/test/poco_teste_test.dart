import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/form_choice.dart';
import 'package:mobile/models/poco_teste_choices.dart';
import 'package:mobile/models/poco_teste_form.dart';
import 'package:mobile/models/poco_teste_geo.dart';
import 'package:mobile/models/poco_teste_level.dart';
import 'package:mobile/models/poco_teste_payload_mapper.dart';
import 'package:mobile/models/poco_teste_photo.dart';
import 'package:mobile/models/poco_teste_validator.dart';

PocoTestePhoto _photo(String type) => PocoTestePhoto(
  localPath: '/tmp/$type.jpg',
  originalName: '$type.jpg',
  type: type,
);

PocoTesteHeader _validHeader() => const PocoTesteHeader(
  data4: '2026-06-22T10:00:00.000',
  municipio: 'Belo Horizonte',
  sitio: 'Sítio 1',
  ponto: 'PT-01',
  responsavel: 'Arqueólogo Teste',
  coordenada: GeoPoint(latitude: -19.9, longitude: -43.9, accuracy: 5),
);

PocoTesteLevel _validFinalLevel() => PocoTesteLevel(
  fotoAberturaPt: _photo('foto_abertura_pt'),
  coloracao: 'marrom',
  compactacao: 'media',
  umidade: 'baixa',
  textura: 'argilosa',
  soloCaracteristica: const ['raizes'],
  materialPresenca: PocoTesteChoices.nao,
  fotoSolo: _photo('foto_solo'),
  fotoPeneira: _photo('foto_peneira'),
  justificativa: PocoTesteChoices.atingiu1,
  profundidade: '100',
  positivo: PocoTesteChoices.nao,
  fotoFinalizacao: _photo('foto_finalizacao'),
);

PocoTesteFormState _state({
  PocoTesteHeader? header,
  PocoTesteSurface? surface,
  List<PocoTesteLevel>? levels,
}) => PocoTesteFormState(
  localUuid: 'uuid-1',
  createdAt: '2026-06-22T10:00:00.000',
  header: header ?? _validHeader(),
  surface:
      surface ??
      PocoTesteSurface(
        fotoSuperficie: _photo('foto_superficie'),
        materialPresenca: PocoTesteChoices.nao,
      ),
  levels: levels ?? [_validFinalLevel()],
);

void main() {
  const validator = PocoTesteValidator();

  group('normalizeChoiceValue', () {
    test('normalizes não variants to nao', () {
      expect(normalizeChoiceValue('Não'), 'nao');
      expect(normalizeChoiceValue('não'), 'nao');
      expect(normalizeChoiceValue('nao '), 'nao');
    });

    test('normalizes Outro variants to outro', () {
      expect(normalizeChoiceValue('Outro'), 'outro');
      expect(normalizeChoiceValue('outro'), 'outro');
      expect(normalizeChoiceValue('Outro '), 'outro');
    });

    test('normalizes accented multi-word values', () {
      expect(normalizeChoiceValue('Saturação_Hídrica'), 'saturacao_hidrica');
      expect(
        normalizeChoiceValue('Intransponível rocha'),
        'intransponivel_rocha',
      );
    });
  });

  group('applySoloCaracteristicaRule', () {
    test('selecting Ausente clears the other options', () {
      final result = PocoTesteChoices.applySoloCaracteristicaRule([
        'raizes',
        'rochas',
      ], PocoTesteChoices.ausente);
      expect(result, [PocoTesteChoices.ausente]);
    });

    test('selecting another option removes Ausente', () {
      final result = PocoTesteChoices.applySoloCaracteristicaRule([
        PocoTesteChoices.ausente,
      ], 'raizes');
      expect(result, ['raizes']);
    });

    test('deselecting just removes the value', () {
      final result = PocoTesteChoices.applySoloCaracteristicaRule([
        'raizes',
        'rochas',
      ], 'rochas');
      expect(result, ['raizes']);
    });
  });

  group('PocoTesteValidator', () {
    test('a fully filled finalization passes', () {
      expect(validator.validateForFinalize(_state()).isValid, isTrue);
    });

    test('no levels fails', () {
      final result = validator.validateForFinalize(_state(levels: []));
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'niveis'), isTrue);
    });

    test('level 1 without opening photo fails', () {
      final result = validator.validateForFinalize(
        _state(
          levels: [_validFinalLevel().copyWith(clearFotoAberturaPt: true)],
        ),
      );
      expect(
        result.errors.any((e) => e.field == 'nivel_1_foto_abertura_pt'),
        isTrue,
      );
    });

    test('cobertura "outro" without description fails', () {
      final result = validator.validateForFinalize(
        _state(
          surface: PocoTesteSurface(
            fotoSuperficie: _photo('foto_superficie'),
            materialPresenca: PocoTesteChoices.nao,
            coberturaVegetacional: const [PocoTesteChoices.outro],
          ),
        ),
      );
      expect(result.errors.any((e) => e.field == 'outro_cobertura'), isTrue);
    });

    test('solo "outro" without description fails', () {
      final result = validator.validateForFinalize(
        _state(
          surface: PocoTesteSurface(
            fotoSuperficie: _photo('foto_superficie'),
            materialPresenca: PocoTesteChoices.nao,
            solo: PocoTesteChoices.outro,
          ),
        ),
      );
      expect(result.errors.any((e) => e.field == 'outro_solo'), isTrue);
    });

    test('surface material yes without foto_material fails', () {
      final result = validator.validateForFinalize(
        _state(
          surface: PocoTesteSurface(
            fotoSuperficie: _photo('foto_superficie'),
            materialPresenca: PocoTesteChoices.sim,
            historico: const ['vidro'],
          ),
        ),
      );
      expect(result.errors.any((e) => e.field == 'foto_material'), isTrue);
    });

    test('level material yes without profundidade_material fails', () {
      final level = _validFinalLevel().copyWith(
        materialPresenca: PocoTesteChoices.sim,
        historico: const ['vidro'],
        fotoMaterial: _photo('foto_material'),
      );
      final result = validator.validateForFinalize(_state(levels: [level]));
      expect(
        result.errors.any((e) => e.field == 'nivel_1_profundidade_material'),
        isTrue,
      );
    });

    test('justificativa "outro" without description fails', () {
      final level = _validFinalLevel().copyWith(
        justificativa: PocoTesteChoices.outro,
      );
      final result = validator.validateForFinalize(_state(levels: [level]));
      expect(
        result.errors.any((e) => e.field == 'nivel_1_outro_justificativa'),
        isTrue,
      );
    });

    test('finalization without foto_finalizacao fails', () {
      final level = _validFinalLevel().copyWith(clearFotoFinalizacao: true);
      final result = validator.validateForFinalize(_state(levels: [level]));
      expect(
        result.errors.any((e) => e.field == 'nivel_1_foto_finalizacao'),
        isTrue,
      );
    });

    test('last level with alteração de camada suggests another level', () {
      final level = _validFinalLevel().copyWith(
        justificativa: PocoTesteChoices.alteracaoDeCamada,
      );
      expect(
        validator.lastLevelSuggestsAnother(_state(levels: [level])),
        isTrue,
      );
    });
  });

  group('PocoTestePayloadMapper', () {
    final project = {'id': 'p1', 'name': 'Projeto X', 'code': 'PX'};
    final form = {'id': 'f1', 'name': 'Poço teste', 'current_version': 2};

    test(
      'serializes surface and multiple levels with differentiated photos',
      () {
        final state = _state(
          levels: [
            _validFinalLevel(),
            _validFinalLevel().copyWith(profundidadeInicial: '100'),
          ],
        );
        final payload = PocoTestePayloadMapper.toPayload(
          state: state,
          project: project,
          form: form,
        );

        expect(payload['form_code'], 'poco_teste');
        expect(payload['project_id'], 'p1');
        expect(payload['form_id'], 'f1');
        expect((payload['niveis'] as List).length, 2);

        final surface = payload['superficie'] as Map;
        expect((surface['foto_superficie'] as Map)['type'], 'foto_superficie');

        final level1 = (payload['niveis'] as List).first as Map;
        expect(level1['index'], 1);
        expect((level1['foto_solo'] as Map)['type'], 'foto_solo');
        // Surface and level photos must not collide.
        expect(surface['foto_material'], isNull);
      },
    );

    test('omits hidden conditional fields from payload', () {
      final state = _state(
        surface: PocoTesteSurface(
          fotoSuperficie: _photo('foto_superficie'),
          materialPresenca: PocoTesteChoices.nao,
          // historico set but material is "nao" -> must be cleared.
          historico: const ['vidro'],
        ),
      );
      final payload = PocoTestePayloadMapper.toPayload(
        state: state,
        project: project,
        form: form,
      );
      expect((payload['superficie'] as Map)['historico'], isEmpty);
    });

    test('round-trips through fromPayload', () {
      final state = _state();
      final payload = PocoTestePayloadMapper.toPayload(
        state: state,
        project: project,
        form: form,
      );
      final restored = PocoTestePayloadMapper.fromPayload(
        Map<String, dynamic>.from(payload),
      );
      expect(restored.header.municipio, 'Belo Horizonte');
      expect(restored.header.coordenada.latitude, -19.9);
      expect(restored.levels.length, 1);
      expect(restored.levels.first.justificativa, PocoTesteChoices.atingiu1);
    });

    test('collectPhotos tags level photos with their index', () {
      final state = _state();
      final photos = PocoTestePayloadMapper.collectPhotos(state);
      final levelPhotos = photos.where((p) => p.levelIndex == 1).toList();
      expect(levelPhotos, isNotEmpty);
      expect(photos.any((p) => p.type == 'foto_superficie'), isTrue);
    });
  });
}
