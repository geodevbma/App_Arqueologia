import '../core/poco_teste_form_descriptor.dart';
import 'poco_teste_form.dart';
import 'poco_teste_geo.dart';
import 'poco_teste_level.dart';
import 'poco_teste_photo.dart';

/// Builds the structured JSON payload stored in the `collections` table and
/// reconstructs a [PocoTesteFormState] from it (for reopening drafts).
///
/// The payload keeps the keys the existing offline-first flow already relies on
/// (`local_uuid`, `project_id`, `form_id`, `status`, `sync_status`) and adds a
/// clear, group-based structure for the "Poço teste" form.
class PocoTestePayloadMapper {
  PocoTestePayloadMapper._();

  static const schemaVersion = 1;

  static Map<String, dynamic> toPayload({
    required PocoTesteFormState state,
    required Map<String, dynamic> project,
    required Map<String, dynamic> form,
  }) {
    final now = DateTime.now().toIso8601String();
    final levelsJson = <Map<String, dynamic>>[];
    for (var i = 0; i < state.levels.length; i++) {
      levelsJson.add(state.levels[i].toJson(i + 1));
    }
    final positivePit = state.levels.any((l) => l.positivo == 'sim');

    return {
      // Keys required by the existing sync / storage flow.
      'local_uuid': state.localUuid,
      'project_id': project['id'],
      'form_id': form['id'],
      'status': state.status,
      'sync_status': state.status,
      // Poço teste metadata.
      'schema_version': schemaVersion,
      'form_code': PocoTesteFormDescriptor.formCode,
      'form_title': PocoTesteFormDescriptor.formTitle,
      'source': 'mobile_native_from_xlsform',
      'created_at': state.createdAt,
      'updated_at': now,
      // Convenience fields used by history/outbox tiles.
      'collection_date': state.header.data4,
      'level_count': state.levels.length,
      'pit_positive': positivePit,
      'project': {
        'id': project['id'],
        'code': project['code'] ?? project['short_code'],
        'name': project['name'],
      },
      'form': {
        'id': form['id'],
        'title': form['name'] ?? PocoTesteFormDescriptor.formTitle,
        'version': form['current_version'],
      },
      'cabecalho': {
        'data4': state.header.data4,
        'projeto': project['name'],
        'municipio': _trim(state.header.municipio),
        'sitio': _trim(state.header.sitio),
        'ponto': _trim(state.header.ponto),
        'coordenadas_utm': _trim(state.header.coordenadasUtm),
        'coordenada': state.header.coordenada.toJson(),
        'responsavel': _trim(state.header.responsavel),
      },
      'superficie': state.surface.toJson(),
      'niveis': levelsJson,
    };
  }

  static PocoTesteFormState fromPayload(Map<String, dynamic> payload) {
    final header = Map<String, dynamic>.from(
      payload['cabecalho'] as Map? ?? {},
    );
    final surface = Map<String, dynamic>.from(
      payload['superficie'] as Map? ?? {},
    );
    final levels = (payload['niveis'] as List? ?? [])
        .map(
          (e) => PocoTesteLevel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return PocoTesteFormState(
      localUuid: payload['local_uuid'] as String,
      createdAt:
          payload['created_at'] as String? ?? DateTime.now().toIso8601String(),
      status: payload['status'] as String? ?? 'draft',
      serverUuid: payload['server_uuid'] as String?,
      header: PocoTesteHeader(
        data4: header['data4'] as String? ?? DateTime.now().toIso8601String(),
        municipio: header['municipio'] as String? ?? '',
        sitio: header['sitio'] as String? ?? '',
        ponto: header['ponto'] as String? ?? '',
        coordenadasUtm: header['coordenadas_utm'] as String? ?? '',
        coordenada: GeoPoint.fromJson(header['coordenada']),
        responsavel: header['responsavel'] as String? ?? '',
      ),
      surface: PocoTesteSurface.fromJson(surface),
      levels: levels.isEmpty ? [PocoTesteLevel()] : levels,
    );
  }

  /// Collects every photo present in the form, tagging level photos with their
  /// 1-based level index. Used by the (future) binary upload step.
  static List<PocoTestePhoto> collectPhotos(PocoTesteFormState state) {
    final photos = <PocoTestePhoto>[];
    void addAll(List<PocoTestePhoto> items, {int? levelIndex}) {
      for (final photo in items) {
        photos.add(
          levelIndex == null ? photo : photo.copyWith(levelIndex: levelIndex),
        );
      }
    }

    addAll(state.surface.fotoSuperficie);
    addAll(state.surface.fotoMaterial);
    for (var i = 0; i < state.levels.length; i++) {
      final level = state.levels[i];
      final idx = i + 1;
      addAll(level.fotoAberturaPt, levelIndex: idx);
      addAll(level.fotoMaterial, levelIndex: idx);
      addAll(level.fotoSolo, levelIndex: idx);
      addAll(level.fotoPeneira, levelIndex: idx);
      addAll(level.fotoFinalizacao, levelIndex: idx);
    }
    return photos;
  }

  static String _trim(String value) => value.trim();
}
