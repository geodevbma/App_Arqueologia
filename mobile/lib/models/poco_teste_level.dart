import 'poco_teste_choices.dart';
import 'poco_teste_photo.dart';

/// One excavation level (item of the XLSForm `nivel1` repeat).
///
/// Visibility of conditional fields depends both on this level's data and on
/// its 1-based position within the list, which is supplied by the caller.
///
/// Photo fields are lists so the user can attach more than one image (from the
/// camera or the gallery) per field.
class PocoTesteLevel {
  PocoTesteLevel({
    String? id,
    this.profundidadeInicial = '',
    this.fotoAberturaPt = const [],
    this.coloracao,
    this.outroColoracao = '',
    this.compactacao,
    this.umidade,
    this.textura,
    this.soloCaracteristica = const [],
    this.outroSoloCaracteristica = '',
    this.materialPresenca,
    this.historico = const [],
    this.outroHistorico = '',
    this.preColonial = const [],
    this.outroPreColonial = '',
    this.fotoMaterial = const [],
    this.fotoSolo = const [],
    this.fotoPeneira = const [],
    this.profundidadeMaterial = '',
    this.justificativa,
    this.outroJustificativa = '',
    this.profundidade = '',
    this.obs = '',
    this.positivo,
    this.fotoFinalizacao = const [],
  }) : id = id ?? _newId();

  /// Stable local id so the UI can key cards and reconcile edits.
  final String id;

  final String profundidadeInicial;
  final List<PocoTestePhoto> fotoAberturaPt;
  final String? coloracao;
  final String outroColoracao;
  final String? compactacao;
  final String? umidade;
  final String? textura;
  final List<String> soloCaracteristica;
  final String outroSoloCaracteristica;
  final String? materialPresenca;
  final List<String> historico;
  final String outroHistorico;
  final List<String> preColonial;
  final String outroPreColonial;
  final List<PocoTestePhoto> fotoMaterial;
  final List<PocoTestePhoto> fotoSolo;
  final List<PocoTestePhoto> fotoPeneira;
  final String profundidadeMaterial;
  final String? justificativa;
  final String outroJustificativa;
  final String profundidade;
  final String obs;
  final String? positivo;
  final List<PocoTestePhoto> fotoFinalizacao;

  static int _seq = 0;
  static String _newId() =>
      'lvl_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // ---- Visibility helpers (relevance) ----

  /// `profundidade_inicial` is shown from level 2 onwards.
  static bool showProfundidadeInicial(int position) => position >= 2;

  /// `foto_pt` (opening photo) is shown only on level 1.
  static bool showFotoAberturaPt(int position) => position == 1;

  bool get showOutroColoracao => coloracao == PocoTesteChoices.outro;

  bool get showOutroSoloCaracteristica =>
      soloCaracteristica.contains(PocoTesteChoices.outro);

  bool get hasMaterial => materialPresenca == PocoTesteChoices.sim;

  bool get showOutroHistorico => historico.contains(PocoTesteChoices.outro);

  bool get showOutroPreColonial => preColonial.contains(PocoTesteChoices.outro);

  bool get showOutroJustificativa => justificativa == PocoTesteChoices.outro;

  /// `profundidade` (final depth) shows whenever a justificativa is chosen.
  bool get showProfundidadeFinal =>
      justificativa != null && justificativa!.isNotEmpty;

  bool get isFinalizacao => PocoTesteChoices.isFinalizacao(justificativa);

  /// `obs` is shown for finalization justificativas (everything but
  /// "alteração de camada").
  bool get showObs => isFinalizacao;

  PocoTesteLevel copyWith({
    String? profundidadeInicial,
    List<PocoTestePhoto>? fotoAberturaPt,
    String? coloracao,
    bool clearColoracao = false,
    String? outroColoracao,
    String? compactacao,
    String? umidade,
    String? textura,
    List<String>? soloCaracteristica,
    String? outroSoloCaracteristica,
    String? materialPresenca,
    List<String>? historico,
    String? outroHistorico,
    List<String>? preColonial,
    String? outroPreColonial,
    List<PocoTestePhoto>? fotoMaterial,
    List<PocoTestePhoto>? fotoSolo,
    List<PocoTestePhoto>? fotoPeneira,
    String? profundidadeMaterial,
    String? justificativa,
    bool clearJustificativa = false,
    String? outroJustificativa,
    String? profundidade,
    String? obs,
    String? positivo,
    bool clearPositivo = false,
    List<PocoTestePhoto>? fotoFinalizacao,
  }) {
    return PocoTesteLevel(
      id: id,
      profundidadeInicial: profundidadeInicial ?? this.profundidadeInicial,
      fotoAberturaPt: fotoAberturaPt ?? this.fotoAberturaPt,
      coloracao: clearColoracao ? null : (coloracao ?? this.coloracao),
      outroColoracao: outroColoracao ?? this.outroColoracao,
      compactacao: compactacao ?? this.compactacao,
      umidade: umidade ?? this.umidade,
      textura: textura ?? this.textura,
      soloCaracteristica: soloCaracteristica ?? this.soloCaracteristica,
      outroSoloCaracteristica:
          outroSoloCaracteristica ?? this.outroSoloCaracteristica,
      materialPresenca: materialPresenca ?? this.materialPresenca,
      historico: historico ?? this.historico,
      outroHistorico: outroHistorico ?? this.outroHistorico,
      preColonial: preColonial ?? this.preColonial,
      outroPreColonial: outroPreColonial ?? this.outroPreColonial,
      fotoMaterial: fotoMaterial ?? this.fotoMaterial,
      fotoSolo: fotoSolo ?? this.fotoSolo,
      fotoPeneira: fotoPeneira ?? this.fotoPeneira,
      profundidadeMaterial: profundidadeMaterial ?? this.profundidadeMaterial,
      justificativa: clearJustificativa
          ? null
          : (justificativa ?? this.justificativa),
      outroJustificativa: outroJustificativa ?? this.outroJustificativa,
      profundidade: profundidade ?? this.profundidade,
      obs: obs ?? this.obs,
      positivo: clearPositivo ? null : (positivo ?? this.positivo),
      fotoFinalizacao: fotoFinalizacao ?? this.fotoFinalizacao,
    );
  }

  /// Structured payload for one level. [position] is the 1-based index.
  Map<String, dynamic> toJson(int position) {
    return {
      'index': position,
      'nivel': 'Nível $position',
      'profundidade_inicial':
          PocoTesteLevel.showProfundidadeInicial(position) &&
              profundidadeInicial.trim().isNotEmpty
          ? profundidadeInicial.trim()
          : null,
      'foto_abertura_pt': _photosJson(fotoAberturaPt),
      'coloracao': coloracao,
      'outro_coloracao': showOutroColoracao
          ? _nullIfEmpty(outroColoracao)
          : null,
      'compactacao': compactacao,
      'umidade': umidade,
      'textura': textura,
      'solo_caracteristica': soloCaracteristica,
      'outro_solo_caracteristica': showOutroSoloCaracteristica
          ? _nullIfEmpty(outroSoloCaracteristica)
          : null,
      'material_arqueologico_presenca': materialPresenca,
      'historico': hasMaterial ? historico : <String>[],
      'outro_historico': hasMaterial && showOutroHistorico
          ? _nullIfEmpty(outroHistorico)
          : null,
      'pre_colonial': hasMaterial ? preColonial : <String>[],
      'outro_pre_colonial': hasMaterial && showOutroPreColonial
          ? _nullIfEmpty(outroPreColonial)
          : null,
      'foto_material': hasMaterial ? _photosJson(fotoMaterial) : <dynamic>[],
      'foto_solo': _photosJson(fotoSolo),
      'foto_peneira': _photosJson(fotoPeneira),
      'profundidade_material': hasMaterial
          ? _nullIfEmpty(profundidadeMaterial)
          : null,
      'justificativa': justificativa,
      'outro_justificativa': showOutroJustificativa
          ? _nullIfEmpty(outroJustificativa)
          : null,
      'profundidade': showProfundidadeFinal ? _nullIfEmpty(profundidade) : null,
      'obs': showObs ? _nullIfEmpty(obs) : null,
      'positivo': isFinalizacao ? positivo : null,
      'foto_finalizacao': isFinalizacao
          ? _photosJson(fotoFinalizacao)
          : <dynamic>[],
    };
  }

  static PocoTesteLevel fromJson(Map<String, dynamic> json) {
    return PocoTesteLevel(
      profundidadeInicial: json['profundidade_inicial'] as String? ?? '',
      fotoAberturaPt: PocoTestePhoto.listFromJson(json['foto_abertura_pt']),
      coloracao: json['coloracao'] as String?,
      outroColoracao: json['outro_coloracao'] as String? ?? '',
      compactacao: json['compactacao'] as String?,
      umidade: json['umidade'] as String?,
      textura: json['textura'] as String?,
      soloCaracteristica: _stringList(json['solo_caracteristica']),
      outroSoloCaracteristica:
          json['outro_solo_caracteristica'] as String? ?? '',
      materialPresenca: json['material_arqueologico_presenca'] as String?,
      historico: _stringList(json['historico']),
      outroHistorico: json['outro_historico'] as String? ?? '',
      preColonial: _stringList(json['pre_colonial']),
      outroPreColonial: json['outro_pre_colonial'] as String? ?? '',
      fotoMaterial: PocoTestePhoto.listFromJson(json['foto_material']),
      fotoSolo: PocoTestePhoto.listFromJson(json['foto_solo']),
      fotoPeneira: PocoTestePhoto.listFromJson(json['foto_peneira']),
      profundidadeMaterial: json['profundidade_material'] as String? ?? '',
      justificativa: json['justificativa'] as String?,
      outroJustificativa: json['outro_justificativa'] as String? ?? '',
      profundidade: json['profundidade'] as String? ?? '',
      obs: json['obs'] as String? ?? '',
      positivo: json['positivo'] as String?,
      fotoFinalizacao: PocoTestePhoto.listFromJson(json['foto_finalizacao']),
    );
  }

  static List<Map<String, dynamic>> _photosJson(List<PocoTestePhoto> photos) =>
      photos.map((photo) => photo.toJson()).toList();

  static List<String> _stringList(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
