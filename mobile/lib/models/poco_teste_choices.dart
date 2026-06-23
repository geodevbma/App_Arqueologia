import 'form_choice.dart';

/// Centralized option lists for the "Poço teste" form.
///
/// Values are normalized stable identifiers (see [normalizeChoiceValue]) and
/// labels keep the proper, accented Portuguese spelling for display. Some
/// labels were corrected from the original XLSForm typos (e.g. "Oganossolos"
/// -> "Organossolos", "Supercifie" -> "Superfície").
class PocoTesteChoices {
  PocoTesteChoices._();

  // Special / shared stable values used by relevance + UX rules.
  static const outro = 'outro';
  static const sim = 'sim';
  static const nao = 'nao';
  static const ausente = 'ausente';

  // Justificativa values that mean the test pit is being finalized.
  static const alteracaoDeCamada = 'alteracao_de_camada';
  static const atingiu1 = 'atingiu_1_m_de_profundidade';
  static const saturacaoHidrica = 'saturacao_hidrica';
  static const intransponivelRocha = 'intransponivel_rocha';

  /// Justificativas that indicate the pit is being closed (finalized).
  static const finalizacaoJustificativas = <String>{
    atingiu1,
    saturacaoHidrica,
    intransponivelRocha,
    outro,
  };

  static const coberturaVegetacional = <FormChoice>[
    FormChoice('graminea', 'Gramínea'),
    FormChoice('serrapilheira', 'Serrapilheira'),
    FormChoice('afloramento_rochoso', 'Afloramento rochoso'),
    FormChoice('solo_exposto', 'Solo exposto'),
    FormChoice(outro, 'Outro'),
  ];

  static const solo = <FormChoice>[
    FormChoice('argissolos', 'Argissolos'),
    FormChoice('cambissolos', 'Cambissolos'),
    FormChoice('chernossolos', 'Chernossolos'),
    FormChoice('espodossolos', 'Espodossolos'),
    FormChoice('gleissolos', 'Gleissolos'),
    FormChoice('latossolos', 'Latossolos'),
    FormChoice('luvissolos', 'Luvissolos'),
    FormChoice('neossolos', 'Neossolos'),
    FormChoice('nitossolos', 'Nitossolos'),
    FormChoice('organossolos', 'Organossolos'),
    FormChoice('planossolos', 'Planossolos'),
    FormChoice('plintossolos', 'Plintossolos'),
    FormChoice('vertissolos', 'Vertissolos'),
    FormChoice(outro, 'Outro'),
  ];

  static const materialArqueologicoPresenca = <FormChoice>[
    FormChoice(sim, 'Sim'),
    FormChoice(nao, 'Não'),
  ];

  static const historico = <FormChoice>[
    FormChoice('vidro', 'Vidro'),
    FormChoice('louca', 'Louça'),
    FormChoice('faianca', 'Faiança'),
    FormChoice('metal', 'Metal'),
    FormChoice(
      'estruturas_edificadas',
      'Estruturas edificadas (muros, fornalhas, bases de habitação, etc)',
    ),
    FormChoice(
      'estruturas_temporarias',
      'Estruturas temporárias (ritualísticas, esteios de madeira, moinhos, etc)',
    ),
    FormChoice(outro, 'Outro'),
  ];

  static const preColonial = <FormChoice>[
    FormChoice('litico', 'Lítico'),
    FormChoice('ceramica', 'Cerâmica'),
    FormChoice('malacologicos', 'Malacológicos'),
    FormChoice('tpi', 'Terra Preta Indígena (TPI)'),
    FormChoice(outro, 'Outro'),
  ];

  static const justificativa = <FormChoice>[
    FormChoice(alteracaoDeCamada, 'Alteração de camada'),
    FormChoice(atingiu1, 'Atingiu 1 m de profundidade'),
    FormChoice(saturacaoHidrica, 'Saturação Hídrica'),
    FormChoice(intransponivelRocha, 'Intransponível rocha'),
    FormChoice(outro, 'Outro'),
  ];

  static const coloracao = <FormChoice>[
    FormChoice('vermelho', 'Vermelho'),
    FormChoice('amarelo', 'Amarelo'),
    FormChoice('marrom', 'Marrom'),
    FormChoice('vermelho_amarelo', 'Vermelho-Amarelo'),
    FormChoice('cinza', 'Cinza'),
    FormChoice('preto', 'Preto'),
    FormChoice('esbranquicado', 'Esbranquiçado'),
    FormChoice(outro, 'Outro'),
  ];

  static const compactacao = <FormChoice>[
    FormChoice('alta', 'Alta'),
    FormChoice('media', 'Média'),
    FormChoice('baixa', 'Baixa'),
  ];

  static const umidade = <FormChoice>[
    FormChoice('alta', 'Alta'),
    FormChoice('media', 'Média'),
    FormChoice('baixa', 'Baixa'),
  ];

  static const textura = <FormChoice>[
    FormChoice('arenosa', 'Arenosa'),
    FormChoice('siltosa', 'Siltosa'),
    FormChoice('argilosa', 'Argilosa'),
  ];

  static const soloCaracteristica = <FormChoice>[
    FormChoice('raizes', 'Raízes'),
    FormChoice('radiculas', 'Radículas'),
    FormChoice('rochas', 'Rochas'),
    FormChoice('plastico', 'Plástico'),
    FormChoice('materia_organica', 'Matéria orgânica'),
    FormChoice('bioperturbadores', 'Bioperturbadores'),
    FormChoice('carvao', 'Carvão'),
    FormChoice('cinzas', 'Cinzas'),
    FormChoice(ausente, 'Ausente'),
    FormChoice(outro, 'Outro'),
  ];

  static const positivo = <FormChoice>[
    FormChoice(sim, 'Sim'),
    FormChoice(nao, 'Não'),
  ];

  /// Returns true when the [justificativa] value closes the test pit.
  static bool isFinalizacao(String? justificativa) =>
      justificativa != null &&
      finalizacaoJustificativas.contains(justificativa);

  /// Applies the "Ausente" exclusivity rule for `solo_caracteristica`:
  /// selecting "Ausente" clears everything else; selecting anything else
  /// removes "Ausente". [toggled] is the value the user just tapped.
  static List<String> applySoloCaracteristicaRule(
    List<String> current,
    String toggled,
  ) {
    final selected = List<String>.from(current);
    final isSelecting = !selected.contains(toggled);
    if (isSelecting) {
      selected.add(toggled);
    } else {
      selected.remove(toggled);
    }
    if (!isSelecting) return selected;
    if (toggled == ausente) {
      return [ausente];
    }
    selected.remove(ausente);
    return selected;
  }
}
