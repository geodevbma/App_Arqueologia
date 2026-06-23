import 'poco_teste_choices.dart';
import 'poco_teste_geo.dart';
import 'poco_teste_level.dart';
import 'poco_teste_photo.dart';

/// Cabeçalho (header) section state.
class PocoTesteHeader {
  const PocoTesteHeader({
    required this.data4,
    this.municipio = '',
    this.sitio = '',
    this.ponto = '',
    this.coordenadasUtm = '',
    this.coordenada = const GeoPoint(),
    this.responsavel = '',
  });

  /// ISO-8601 date/time, auto filled with now() and shown read-only.
  final String data4;
  final String municipio;
  final String sitio;
  final String ponto;
  final String coordenadasUtm;
  final GeoPoint coordenada;
  final String responsavel;

  PocoTesteHeader copyWith({
    String? data4,
    String? municipio,
    String? sitio,
    String? ponto,
    String? coordenadasUtm,
    GeoPoint? coordenada,
    String? responsavel,
  }) {
    return PocoTesteHeader(
      data4: data4 ?? this.data4,
      municipio: municipio ?? this.municipio,
      sitio: sitio ?? this.sitio,
      ponto: ponto ?? this.ponto,
      coordenadasUtm: coordenadasUtm ?? this.coordenadasUtm,
      coordenada: coordenada ?? this.coordenada,
      responsavel: responsavel ?? this.responsavel,
    );
  }
}

/// Superfície (surface) section state.
class PocoTesteSurface {
  const PocoTesteSurface({
    this.fotoSuperficie,
    this.coberturaVegetacional = const [],
    this.outroCobertura = '',
    this.solo,
    this.outroSolo = '',
    this.materialPresenca,
    this.historico = const [],
    this.outroHistorico = '',
    this.preColonial = const [],
    this.outroPreColonial = '',
    this.fotoMaterial,
  });

  final PocoTestePhoto? fotoSuperficie;
  final List<String> coberturaVegetacional;
  final String outroCobertura;
  final String? solo;
  final String outroSolo;
  final String? materialPresenca;
  final List<String> historico;
  final String outroHistorico;
  final List<String> preColonial;
  final String outroPreColonial;
  final PocoTestePhoto? fotoMaterial;

  bool get showOutroCobertura =>
      coberturaVegetacional.contains(PocoTesteChoices.outro);

  bool get showOutroSolo => solo == PocoTesteChoices.outro;

  bool get hasMaterial => materialPresenca == PocoTesteChoices.sim;

  bool get showOutroHistorico => historico.contains(PocoTesteChoices.outro);

  bool get showOutroPreColonial => preColonial.contains(PocoTesteChoices.outro);

  PocoTesteSurface copyWith({
    PocoTestePhoto? fotoSuperficie,
    bool clearFotoSuperficie = false,
    List<String>? coberturaVegetacional,
    String? outroCobertura,
    String? solo,
    bool clearSolo = false,
    String? outroSolo,
    String? materialPresenca,
    List<String>? historico,
    String? outroHistorico,
    List<String>? preColonial,
    String? outroPreColonial,
    PocoTestePhoto? fotoMaterial,
    bool clearFotoMaterial = false,
  }) {
    return PocoTesteSurface(
      fotoSuperficie: clearFotoSuperficie
          ? null
          : (fotoSuperficie ?? this.fotoSuperficie),
      coberturaVegetacional:
          coberturaVegetacional ?? this.coberturaVegetacional,
      outroCobertura: outroCobertura ?? this.outroCobertura,
      solo: clearSolo ? null : (solo ?? this.solo),
      outroSolo: outroSolo ?? this.outroSolo,
      materialPresenca: materialPresenca ?? this.materialPresenca,
      historico: historico ?? this.historico,
      outroHistorico: outroHistorico ?? this.outroHistorico,
      preColonial: preColonial ?? this.preColonial,
      outroPreColonial: outroPreColonial ?? this.outroPreColonial,
      fotoMaterial: clearFotoMaterial
          ? null
          : (fotoMaterial ?? this.fotoMaterial),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foto_superficie': fotoSuperficie?.toJson(),
      'cobertura_vegetacional': coberturaVegetacional,
      'outro_cobertura_vegetacional': showOutroCobertura
          ? _nullIfEmpty(outroCobertura)
          : null,
      'solo': solo,
      'outro_solo': showOutroSolo ? _nullIfEmpty(outroSolo) : null,
      'material_arqueologico_presenca': materialPresenca,
      'historico': hasMaterial ? historico : <String>[],
      'outro_historico': hasMaterial && showOutroHistorico
          ? _nullIfEmpty(outroHistorico)
          : null,
      'pre_colonial': hasMaterial ? preColonial : <String>[],
      'outro_pre_colonial': hasMaterial && showOutroPreColonial
          ? _nullIfEmpty(outroPreColonial)
          : null,
      'foto_material': hasMaterial ? fotoMaterial?.toJson() : null,
    };
  }

  static PocoTesteSurface fromJson(Map<String, dynamic> json) {
    return PocoTesteSurface(
      fotoSuperficie: PocoTestePhoto.fromJson(json['foto_superficie']),
      coberturaVegetacional: _stringList(json['cobertura_vegetacional']),
      outroCobertura: json['outro_cobertura_vegetacional'] as String? ?? '',
      solo: json['solo'] as String?,
      outroSolo: json['outro_solo'] as String? ?? '',
      materialPresenca: json['material_arqueologico_presenca'] as String?,
      historico: _stringList(json['historico']),
      outroHistorico: json['outro_historico'] as String? ?? '',
      preColonial: _stringList(json['pre_colonial']),
      outroPreColonial: json['outro_pre_colonial'] as String? ?? '',
      fotoMaterial: PocoTestePhoto.fromJson(json['foto_material']),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

/// The whole "Poço teste" working state.
class PocoTesteFormState {
  PocoTesteFormState({
    required this.localUuid,
    required this.createdAt,
    required this.header,
    required this.surface,
    required this.levels,
    this.status = 'draft',
    this.serverUuid,
  });

  final String localUuid;
  final String createdAt;
  final PocoTesteHeader header;
  final PocoTesteSurface surface;
  final List<PocoTesteLevel> levels;

  /// `draft`, `pending_sync`, `sync_error` or `synced`.
  final String status;
  final String? serverUuid;

  PocoTesteFormState copyWith({
    PocoTesteHeader? header,
    PocoTesteSurface? surface,
    List<PocoTesteLevel>? levels,
    String? status,
    String? serverUuid,
  }) {
    return PocoTesteFormState(
      localUuid: localUuid,
      createdAt: createdAt,
      header: header ?? this.header,
      surface: surface ?? this.surface,
      levels: levels ?? this.levels,
      status: status ?? this.status,
      serverUuid: serverUuid ?? this.serverUuid,
    );
  }

  /// Index (1-based) of the [level] within [levels].
  int positionOf(PocoTesteLevel level) => levels.indexOf(level) + 1;
}
