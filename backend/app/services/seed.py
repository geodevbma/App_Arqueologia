from datetime import date

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.entities import (
    Form,
    FormField,
    FormVersion,
    Project,
    ProjectForm,
    ProjectUser,
    Role,
    Section,
    User,
    UserForm,
    WorkPoint,
)


PROJECT_NAME = "Projeto de Acompanhamento Arqueologico Ramal Turistico Ouro Preto - Mariana"
FORM_NAME = "Formulario de Acompanhamento Arqueologico"
POCO_TESTE_FORM_NAME = "Poço teste"
ESTRUTURA_FORM_NAME = "Estrutura Historica"
ANALISE_PAISAGEM_FORM_NAME = "Análise de paisagem"

SECTIONS = {
    "Trecho 01": ["000+800", "001+850", "002+300", "003+925", "006+800"],
    "Trecho 02": ["008+615", "009+225", "010+300", "012+255", "012+465", "015+450+60", "015+855"],
    "Trecho 03": ["016+145", "016+900"],
}

INITIAL_FIELDS = [
    {
        "label": "Projeto",
        "field_key": "project_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 1,
        "options": {"source": "projects"},
    },
    {
        "label": "Trecho",
        "field_key": "section_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 2,
        "options": {"source": "sections", "depends_on": "project_id"},
    },
    {
        "label": "Obra/Ponto",
        "field_key": "work_point_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 3,
        "options": {"source": "work_points", "depends_on": "section_id", "include_other": True},
    },
    {
        "label": "Outro - Qual?",
        "field_key": "work_point_other",
        "field_type": "text",
        "is_required": True,
        "order_index": 4,
        "conditional_logic": {"field": "work_point_id", "operator": "equals", "value": "other"},
    },
    {"label": "Data", "field_key": "collection_date", "field_type": "date", "is_required": True, "order_index": 5},
    {
        "label": "Nome do Arqueologo",
        "field_key": "archaeologist_name",
        "field_type": "auto_user",
        "is_required": True,
        "order_index": 6,
    },
    {
        "label": "Ponto georreferenciado",
        "field_key": "coordinates",
        "field_type": "coordinate",
        "is_required": True,
        "order_index": 7,
    },
    {
        "label": "Foto da atividade",
        "field_key": "activity_photo",
        "field_type": "photo",
        "is_required": True,
        "order_index": 8,
    },
    {
        "label": "Foto da paisagem",
        "field_key": "landscape_photo",
        "field_type": "photo",
        "is_required": True,
        "order_index": 9,
    },
    {
        "label": "Descricao da atividade",
        "field_key": "activity_description",
        "field_type": "textarea",
        "is_required": True,
        "order_index": 10,
    },
    {
        "label": "Foi identificado algum vestigio arqueologico?",
        "field_key": "vestigio_identificado",
        "field_type": "boolean",
        "is_required": True,
        "order_index": 11,
    },
    {
        "label": "Qual vestigio?",
        "field_key": "qual_vestigio",
        "field_type": "text",
        "is_required": True,
        "order_index": 12,
        "conditional_logic": {"field": "vestigio_identificado", "operator": "equals", "value": True},
    },
    {
        "label": "Houve alguma intercorrencia durante as atividades?",
        "field_key": "intercorrencia_identificada",
        "field_type": "boolean",
        "is_required": True,
        "order_index": 13,
    },
    {
        "label": "Qual intercorrencia?",
        "field_key": "qual_intercorrencia",
        "field_type": "text",
        "is_required": True,
        "order_index": 14,
        "conditional_logic": {"field": "intercorrencia_identificada", "operator": "equals", "value": True},
    },
]


TIPO_ESTRUTURA_CHOICES = [
    {"value": "cata", "label": "Cata de Mineracao"},
    {"value": "galeria", "label": "Galeria"},
    {"value": "canais_de_aducao", "label": "Canais de Aducao"},
    {"value": "amontado", "label": "Amontado de Pedras"},
    {"value": "muro_de_arrimo", "label": "Muro de Arrimo"},
    {"value": "edificacao", "label": "Edificacao"},
    {"value": "mundeu", "label": "Mundeu"},
    {"value": "moinho", "label": "Roda de Moinho"},
    {"value": "valo_divisa", "label": "Valo de Divisa"},
    {"value": "bacia", "label": "Bacia de Contencao"},
    {"value": "outro", "label": "Outro"},
]

MORFOLOGIA_CHOICES = [
    {"value": "linear", "label": "Linear"},
    {"value": "circular", "label": "Circular"},
    {"value": "irregular", "label": "Irregular"},
    {"value": "retangular", "label": "Retangular"},
    {"value": "quadrangular", "label": "Quadrangular"},
    {"value": "outros", "label": "Outros"},
]

MATERIAL_LIGANTE_CHOICES = [
    {"value": "presente", "label": "Presente (Descrever)"},
    {"value": "ausente", "label": "Ausente"},
]

# Modelo "Estrutura Historica" (origem: XLSForm Survey123 1SAMA030.xlsx).
# Mapeamento: o campo "projeto" da planilha usa o Projeto do sistema (selecionado no app);
# coordenadas UTM repetiveis -> coordinate_list; campos calculados (altitude/zona UTM)
# sao derivados no app; "responsavel" -> auto_user; "Data" -> datetime automatico.
ESTRUTURA_FIELDS = [
    {
        "label": "Data",
        "field_key": "dat2",
        "field_type": "datetime",
        "is_required": True,
        "order_index": 1,
        "options": {"auto": "now"},
    },
    {"label": "Sitio", "field_key": "sitio", "field_type": "text", "is_required": True, "order_index": 2},
    {"label": "Nome da Estrutura", "field_key": "nome_estrutura", "field_type": "text", "is_required": True, "order_index": 3},
    {"label": "Municipio", "field_key": "municipio", "field_type": "text", "is_required": True, "order_index": 4},
    {
        "label": "Tipo de Estrutura",
        "field_key": "tipo_estrutura",
        "field_type": "multiselect",
        "is_required": True,
        "order_index": 5,
        "options": {"choices": TIPO_ESTRUTURA_CHOICES},
    },
    {
        "label": "Qual?",
        "field_key": "outro_estrutura",
        "field_type": "text",
        "is_required": True,
        "order_index": 6,
        "conditional_logic": {"field": "tipo_estrutura", "operator": "contains", "value": "outro"},
    },
    {"label": "Acesso ao sitio/estrutura", "field_key": "acesso", "field_type": "textarea", "is_required": False, "order_index": 7},
    {"label": "Data estimada da estrutura", "field_key": "data_estrutura", "field_type": "text", "is_required": False, "order_index": 8},
    {
        "label": "Sistema Construtivo (Tipos e Tecnicas)",
        "field_key": "sistema_construtivo",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 9,
    },
    {
        "label": "Material Ligante",
        "field_key": "material_ligante",
        "field_type": "select",
        "is_required": True,
        "order_index": 10,
        "options": {"choices": MATERIAL_LIGANTE_CHOICES},
    },
    {
        "label": "Descrever material ligante presente",
        "field_key": "material_ligante_descrever",
        "field_type": "textarea",
        "is_required": True,
        "order_index": 11,
        "conditional_logic": {"field": "material_ligante", "operator": "equals", "value": "presente"},
    },
    {"label": "Implantacao na Paisagem", "field_key": "implantacao", "field_type": "textarea", "is_required": False, "order_index": 12},
    {
        "label": "UTM's de Delimitacao",
        "field_key": "coordenada",
        "field_type": "coordinate_list",
        "is_required": True,
        "order_index": 13,
        "options": {"compute_utm_zone": True, "capture_altitude": True},
    },
    {"label": "Orientacao (se linear)", "field_key": "orientacao", "field_type": "text", "is_required": False, "order_index": 14},
    {
        "label": "Morfologia",
        "field_key": "morfologia",
        "field_type": "select",
        "is_required": True,
        "order_index": 15,
        "options": {"choices": MORFOLOGIA_CHOICES},
    },
    {
        "label": "Quais?",
        "field_key": "outro_morfologia",
        "field_type": "text",
        "is_required": True,
        "order_index": 16,
        "conditional_logic": {"field": "morfologia", "operator": "equals", "value": "outros"},
    },
    {
        "label": "Estado de Conservacao do Sistema Estrutural",
        "field_key": "conservacao_estrutural",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 17,
    },
    {
        "label": "Estado de Conservacao dos Materiais",
        "field_key": "conservacao_materiais",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 18,
    },
    {"label": "Agentes Degradadores", "field_key": "agentes", "field_type": "textarea", "is_required": False, "order_index": 19},
    {"label": "Dimensoes da Estrutura", "field_key": "dimensoes", "field_type": "note", "is_required": False, "order_index": 20},
    {"label": "Comprimento (m)", "field_key": "comprimento", "field_type": "number", "is_required": False, "order_index": 21},
    {"label": "Largura (m)", "field_key": "largura", "field_type": "number", "is_required": False, "order_index": 22},
    {"label": "Espessura (m)", "field_key": "espessura", "field_type": "number", "is_required": False, "order_index": 23},
    {"label": "Profundidade (m)", "field_key": "profundidade", "field_type": "number", "is_required": False, "order_index": 24},
    {"label": "Altura (m)", "field_key": "altura", "field_type": "number", "is_required": False, "order_index": 25},
    {"label": "Caracterizacoes", "field_key": "caracterizacoes", "field_type": "textarea", "is_required": False, "order_index": 26},
    {
        "label": "Insercao na Paisagem",
        "field_key": "insercao",
        "field_type": "photo",
        "is_required": True,
        "order_index": 27,
        "options": {"multiple": True},
    },
    {
        "label": "Fotos da Estrutura",
        "field_key": "fotos",
        "field_type": "photo",
        "is_required": True,
        "order_index": 28,
        "options": {"multiple": True},
    },
    {
        "label": "Detalhes da Estrutura",
        "field_key": "detalhes",
        "field_type": "photo",
        "is_required": True,
        "order_index": 29,
        "options": {"multiple": True},
    },
    {"label": "Arqueologo(a)", "field_key": "responsavel", "field_type": "auto_user", "is_required": True, "order_index": 30},
]


# Modelo "Análise de paisagem" (origem: XLSForm Survey123 "Análise de paisagem.xlsx").
# Mapeamento dos tipos do Survey123 para o motor de formulario dinamico do sistema:
#   geopoint -> coordinate | text -> text/textarea | select_one -> select |
#   select_multiple -> multiselect | image (multiline) -> photo {multiple: True} |
#   dateTime now() -> datetime {auto: "now"} | "responsavel" -> auto_user.
# Obrigatoriedade fiel a planilha: apenas localizacao, responsavel e dta_hora sao
# marcados como required no Survey123. As relevancias (relevant) viram conditional_logic.
PAISAGEM_ESTADO_CHOICES = [
    {"value": "Acre", "label": "Acre"},
    {"value": "Alagoas", "label": "Alagoas"},
    {"value": "Amapá", "label": "Amapá"},
    {"value": "Amazonas", "label": "Amazonas"},
    {"value": "Bahia", "label": "Bahia"},
    {"value": "Ceará", "label": "Ceará"},
    {"value": "Espírito Santo", "label": "Espírito Santo"},
    {"value": "Goiás", "label": "Goiás"},
    {"value": "Maranhão", "label": "Maranhão"},
    {"value": "Mato Grosso", "label": "Mato Grosso"},
    {"value": "Mato Grosso do Sul", "label": "Mato Grosso do Sul"},
    {"value": "Minas Gerais", "label": "Minas Gerais"},
    {"value": "Pará", "label": "Pará"},
    {"value": "Paraíba", "label": "Paraíba"},
    {"value": "Paraná", "label": "Paraná"},
    {"value": "Pernambuco", "label": "Pernambuco"},
    {"value": "Piauí", "label": "Piauí"},
    {"value": "Rio de Janeiro", "label": "Rio de Janeiro"},
    {"value": "Rio Grande do Norte", "label": "Rio Grande do Norte"},
    {"value": "Rio Grande do Sul", "label": "Rio Grande do Sul"},
    {"value": "Rondônia", "label": "Rondônia"},
    {"value": "Roraima", "label": "Roraima"},
    {"value": "Santa Catarina", "label": "Santa Catarina"},
    {"value": "São Paulo", "label": "São Paulo"},
    {"value": "Sergipe", "label": "Sergipe"},
    {"value": "Tocantins", "label": "Tocantins"},
]

PAISAGEM_VESTIGIO_CHOICES = [
    {"value": "presenca", "label": "Presença"},
    {"value": "ausencia", "label": "Ausência"},
]

PAISAGEM_POTENCIAL_CHOICES = [
    {"value": "azidas", "label": "Jazidas líticas (seixos, cristais, blocos)"},
    {"value": "argila", "label": "Argila"},
    {"value": "relevo_suave", "label": "Relevo suave"},
    {"value": "compartimento_da_paisagem", "label": "Compartimento da paisagem"},
    {"value": "curso_de_agua", "label": "Proximidade de curso de água"},
    {"value": "afloramento", "label": "Presença de afloramento rochoso com abrigo ou gruta"},
]

PAISAGEM_CONTEXTO_HISTORICO_CHOICES = [
    {"value": "pomar", "label": "Pomar"},
    {"value": "pitaia", "label": "Pitaia, espada de São Jorge, etc."},
    {"value": "clareira", "label": "Clareira"},
    {"value": "sedimento", "label": "Sedimento revolvido"},
    {"value": "setor", "label": "Setor escavado"},
]

ANALISE_PAISAGEM_FIELDS = [
    {
        # O projeto e selecionado na tela anterior do app (form_projects_screen),
        # que ja lista apenas os projetos vinculados ao usuario. Com source=projects
        # o campo nao e re-renderizado no formulario e o project_id vem do fluxo.
        "label": "Projeto",
        "field_key": "project_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 1,
        "options": {"source": "projects"},
    },
    {
        "label": "Localização",
        "field_key": "localizacao",
        "field_type": "coordinate",
        "is_required": True,
        "order_index": 2,
    },
    {"label": "Ponto de controle", "field_key": "ponto", "field_type": "text", "is_required": False, "order_index": 3},
    {"label": "Número da Ficha", "field_key": "n_ficha", "field_type": "text", "is_required": False, "order_index": 4},
    {
        "label": "Estado",
        "field_key": "estado",
        "field_type": "select",
        "is_required": False,
        "order_index": 5,
        "options": {"choices": PAISAGEM_ESTADO_CHOICES},
    },
    {"label": "Município", "field_key": "municipio", "field_type": "text", "is_required": False, "order_index": 6},
    {"label": "DESCRIÇÃO DA ÁREA", "field_key": "descricao_area", "field_type": "note", "is_required": False, "order_index": 7},
    {
        "label": "Uso e ocupação do solo (utilização atual do terreno)",
        "field_key": "solo",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 8,
    },
    {
        "label": "Aspectos geológicos (tipo de rocha, presença/ausência de afloramentos, blocos, seixos, tamanho)",
        "field_key": "aspectos_geologicos",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 9,
    },
    {
        "label": "Aspectos do relevo (Unidades do Relevo: serra, planalto, planície / Compartimento: topo, alta, média, baixa vertente, vale)",
        "field_key": "aspectos_relevo",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 10,
    },
    {
        "label": "Aspectos Hidrográficos (presença/ausência de curso de água, porte, distância relativa)",
        "field_key": "aspectos_hidrograficos",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 11,
    },
    {
        "label": "Aspectos Vegetacionais (tipo, porte, secundária, primária, densa, esparsa)",
        "field_key": "aspectos_vegetacionais",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 12,
    },
    {
        "label": "Vestígios arqueológicos",
        "field_key": "vestigio_arqueologico",
        "field_type": "select",
        "is_required": False,
        "order_index": 13,
        "options": {"choices": PAISAGEM_VESTIGIO_CHOICES},
    },
    {
        "label": "Presença de vestígios arqueológicos? Descreva-os.",
        "field_key": "presenca",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 14,
        "conditional_logic": {"field": "vestigio_arqueologico", "operator": "equals", "value": "presenca"},
    },
    {
        "label": "Ausência de vestígios arqueológicos? Descreva-os.",
        "field_key": "ausencia",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 15,
        "conditional_logic": {"field": "vestigio_arqueologico", "operator": "equals", "value": "ausencia"},
    },
    {
        "label": "Qual o potencial arqueológico para o contexto Pré-Colonial? Descreva.",
        "field_key": "potencial_arqueologico",
        "field_type": "multiselect",
        "is_required": False,
        "order_index": 16,
        "options": {"choices": PAISAGEM_POTENCIAL_CHOICES},
    },
    {
        "label": "Descrição (critérios para classificar em alto, médio e baixo potencial Pré-Colonial)",
        "field_key": "descricao_alto_nivel",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 17,
    },
    {
        "label": "Qual o potencial arqueológico para o contexto Histórico?",
        "field_key": "contexto_historico",
        "field_type": "multiselect",
        "is_required": False,
        "order_index": 18,
        "options": {"choices": PAISAGEM_CONTEXTO_HISTORICO_CHOICES},
    },
    {
        "label": "Descrição (critérios para classificar em alto, médio e baixo potencial Histórico)",
        "field_key": "descricao_medio_nivel",
        "field_type": "textarea",
        "is_required": False,
        "order_index": 19,
    },
    {
        "label": "Foto porção norte",
        "field_key": "porcao_norte",
        "field_type": "photo",
        "is_required": False,
        "order_index": 20,
        "options": {"multiple": True},
    },
    {
        "label": "Foto porção sul",
        "field_key": "porcao_sul",
        "field_type": "photo",
        "is_required": False,
        "order_index": 21,
        "options": {"multiple": True},
    },
    {
        "label": "Foto porção leste",
        "field_key": "porcao_leste",
        "field_type": "photo",
        "is_required": False,
        "order_index": 22,
        "options": {"multiple": True},
    },
    {
        "label": "Foto porção oeste",
        "field_key": "porcao_oeste",
        "field_type": "photo",
        "is_required": False,
        "order_index": 23,
        "options": {"multiple": True},
    },
    {
        "label": "Foto superfície",
        "field_key": "superficie",
        "field_type": "photo",
        "is_required": False,
        "order_index": 24,
        "options": {"multiple": True},
    },
    {"label": "Observações extras", "field_key": "obs_extras", "field_type": "textarea", "is_required": False, "order_index": 25},
    {
        "label": "Arqueólogo(a)",
        "field_key": "responsavel",
        "field_type": "auto_user",
        "is_required": True,
        "order_index": 26,
    },
    {
        "label": "Data",
        "field_key": "dta_hora",
        "field_type": "datetime",
        "is_required": True,
        "order_index": 27,
        "options": {"auto": "now"},
    },
]


def _seed_form(db: Session, project: Project, name: str, description: str, fields: list[dict]) -> Form:
    form = db.query(Form).filter_by(name=name).first()
    if not form:
        form = Form(
            project_id=project.id,
            name=name,
            description=description,
            status="published",
            current_version=1,
        )
        db.add(form)
        db.flush()
        for field in fields:
            db.add(FormField(form_id=form.id, version=1, **field))
        db.add(
            FormVersion(
                form_id=form.id,
                version=1,
                status="published",
                schema_snapshot={"name": name, "fields": fields},
            )
        )
    # Backfill do vinculo projeto<->formulario (fonte de verdade do M2M).
    if not db.query(ProjectForm).filter_by(project_id=project.id, form_id=form.id).first():
        db.add(ProjectForm(project_id=project.id, form_id=form.id))
    return form


def seed_initial_data(db: Session) -> None:
    role_descriptions = {
        "admin": "Administrador com acesso completo ao sistema web e ao app.",
        "coordinator": "Coordenador com gestao do sistema, exceto formularios, e acesso completo ao app.",
        "archaeologist": "Arqueologo com leitura no sistema e coleta/edicao dos proprios registros no app.",
        "viewer": "Visualizador com acesso apenas de consulta.",
    }
    roles: dict[str, Role] = {}
    for name, description in role_descriptions.items():
        role = db.query(Role).filter_by(name=name).first()
        if not role:
            role = Role(name=name, description=description)
            db.add(role)
            db.flush()
        roles[name] = role

    project = db.query(Project).filter_by(name=PROJECT_NAME).first()
    if not project:
        project = Project(
            name=PROJECT_NAME,
            code="OPM-001",
            description="Acompanhamento arqueologico do Ramal Turistico Ouro Preto - Mariana.",
            status="active",
            start_date=date.today(),
        )
        db.add(project)
        db.flush()

    for section_index, (section_name, points) in enumerate(SECTIONS.items(), start=1):
        section = db.query(Section).filter_by(project_id=project.id, name=section_name).first()
        if not section:
            section = Section(project_id=project.id, name=section_name, order_index=section_index)
            db.add(section)
            db.flush()
        for point_index, point_name in enumerate(points, start=1):
            exists = db.query(WorkPoint).filter_by(section_id=section.id, name=point_name).first()
            if not exists:
                db.add(WorkPoint(section_id=section.id, name=point_name, order_index=point_index, is_active=True))

    users = [
        ("Administrador Brandt", "admin@brandt.local", "Admin123!", "admin"),
        ("Coordenador Arqueologia", "coordenador@brandt.local", "Coord123!", "coordinator"),
        ("Arqueologa de Campo", "arqueologo@brandt.local", "Campo123!", "archaeologist"),
        ("Visualizador Brandt", "viewer@brandt.local", "Viewer123!", "viewer"),
    ]
    new_users: list[User] = []
    for name, email, password, role_name in users:
        user = db.query(User).filter_by(email=email).first()
        if not user:
            user = User(name=name, email=email, password_hash=hash_password(password), role_id=roles[role_name].id)
            db.add(user)
            db.flush()
            new_users.append(user)
        linked = db.query(ProjectUser).filter_by(project_id=project.id, user_id=user.id).first()
        if not linked:
            db.add(ProjectUser(project_id=project.id, user_id=user.id))

    db.flush()
    forms = [
        _seed_form(
            db,
            project,
            FORM_NAME,
            "Ficha principal para acompanhamento arqueologico em campo.",
            INITIAL_FIELDS,
        ),
        _seed_form(
            db,
            project,
            ESTRUTURA_FORM_NAME,
            "Ficha de registro de estruturas historicas (catas, galerias, muros, etc.).",
            ESTRUTURA_FIELDS,
        ),
        _seed_form(
            db,
            project,
            ANALISE_PAISAGEM_FORM_NAME,
            "Ficha de analise de paisagem (caracterizacao ambiental e potencial arqueologico).",
            ANALISE_PAISAGEM_FIELDS,
        ),
    ]

    # "Poço teste" form. The mobile app renders this form natively (it does not
    # rely on these backend field definitions), so it is published with an empty
    # field set. The record exists so it can be linked to users, returned by the
    # bootstrap and used for synchronization.
    poco_form = db.query(Form).filter_by(project_id=project.id, name=POCO_TESTE_FORM_NAME).first()
    if not poco_form:
        poco_form = Form(
            project_id=project.id,
            name=POCO_TESTE_FORM_NAME,
            description="Ficha de poço teste (sondagem) preenchida nativamente no aplicativo mobile.",
            status="published",
            current_version=1,
        )
        db.add(poco_form)
        db.flush()
        db.add(
            FormVersion(
                form_id=poco_form.id,
                version=1,
                status="published",
                schema_snapshot={"name": POCO_TESTE_FORM_NAME, "native": True, "fields": []},
            )
        )
    # Backfill do vinculo projeto<->formulario para o Poço teste (fonte de verdade do M2M).
    if not db.query(ProjectForm).filter_by(project_id=project.id, form_id=poco_form.id).first():
        db.add(ProjectForm(project_id=project.id, form_id=poco_form.id))
    forms.append(poco_form)

    # Vinculos iniciais sao aplicados somente quando o usuario seed e criado.
    # Reinicializacoes nao podem restaurar permissoes removidas pelo administrador.
    for user in new_users:
        for form in forms:
            linked_form = db.query(UserForm).filter_by(user_id=user.id, form_id=form.id).first()
            if not linked_form:
                db.add(UserForm(user_id=user.id, form_id=form.id))

    db.commit()
