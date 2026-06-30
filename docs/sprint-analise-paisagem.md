# Sprints — Formulário "Análise de paisagem"

Origem: XLSForm do ArcGIS Survey123 (`Análise de paisagem.xlsx`). Este documento descreve
a implementação do formulário no sistema web (controle de quem usa) e no aplicativo Flutter.

## Diagnóstico

O sistema já possui um **motor de formulários dinâmico** completo. O formulário
"Estrutura Historica" (`backend/app/services/seed.py`) é o molde: usa `multiselect`,
lógica condicional, fotos múltiplas e `auto_user`, tudo renderizado nativamente pelo
`mobile/lib/screens/collection_form_screen.dart`. **Não é necessária tela nova no app.**

O **controle de quem usa o formulário já existe**: na tela de Usuários do web há os
checkboxes "Formulários vinculados" (`frontend/src/App.tsx`), que gravam em `UserForm`,
e o backend bloqueia acesso via `ensure_form_access` (`backend/app/api/routes.py`).

### Mapeamento dos campos (Survey123 → tipo interno)

| Campo (planilha) | Tipo interno | Obrigatório | Observação |
|---|---|---|---|
| `projeto` (select_one) | `select` `{source:"projects"}` | Sim | Projeto do sistema; escolhido na tela anterior, mostra só os vinculados ao usuário |
| `localizacao` (geopoint) | `coordinate` | **Sim** | |
| `ponto`, `n_ficha`, `municipio` | `text` | Não | |
| `estado` (select_one) | `select` | Não | 26 UFs |
| `DESCRIÇÃO DA ÁREA` (note) | `note` | Não | |
| `solo`, `aspectos_*` | `textarea` | Não | hints embutidos no label |
| `vestigio_arqueologico` (select_one) | `select` | Não | presença/ausência |
| `presenca` / `ausencia` | `textarea` | Não | condicional ao select acima |
| `potencial_arqueologico`, `contexto_historico` | `multiselect` | Não | 6 e 5 opções |
| `descricao_alto_nivel`, `descricao_medio_nivel` | `textarea` | Não | |
| `porcao_norte/sul/leste/oeste`, `superficie` | `photo` `{multiple:true}` | Não | 5 campos |
| `obs_extras` | `textarea` | Não | |
| `responsavel` | `auto_user` | **Sim** | Arqueólogo(a) |
| `dta_hora` (dateTime, now()) | `datetime` `{auto:"now"}` | **Sim** | Data |

> **Obrigatoriedade fiel à planilha:** o Survey123 só marca `localizacao`, `responsavel`
> e `dta_hora` como `required`. Os demais ficam opcionais. Ajustar caso o cliente exija.

> **Decisão do campo `projeto`:** usa o Project do sistema (`source:"projects"`, `field_key=project_id`),
> não a lista de códigos da planilha. O projeto é escolhido na tela anterior do app
> (`form_projects_screen`), que já lista apenas os projetos vinculados ao usuário; o campo
> não é re-renderizado no formulário e o `project_id` vem do fluxo.

---

## Sprint 0 — Decisões e preparação (0,5 dia) — ✅ resolvido

- [x] Campo `projeto`: `source:"projects"` (projeto do sistema, vinculado por usuário) — não usa a lista de códigos da planilha.
- [x] Obrigatoriedade: fiel à planilha (`localizacao`, `responsavel`, `dta_hora`) + `project_id` (garantido pelo fluxo).
- [x] Publicação no único projeto existente ("Ramal Turístico Ouro Preto - Mariana") para testes.

## Sprint 1 — Backend: definição e seed (1–1,5 dia) — ✅ implementado

- [x] Constantes de choices: `PAISAGEM_PROJETO_CHOICES`, `PAISAGEM_ESTADO_CHOICES`,
      `PAISAGEM_VESTIGIO_CHOICES`, `PAISAGEM_POTENCIAL_CHOICES`,
      `PAISAGEM_CONTEXTO_HISTORICO_CHOICES`.
- [x] Lista `ANALISE_PAISAGEM_FIELDS` (27 campos, lógica condicional incluída).
- [x] `ANALISE_PAISAGEM_FORM_NAME = "Análise de paisagem"` + chamada `_seed_form(...)`.
- [x] Validado: seed cria o form publicado, 27 campos, versão publicada e vínculos de usuário.

**Deploy do Sprint 1:** rodar o seed na base alvo (ele é idempotente — cria o form se não
existir e faz backfill do vínculo projeto↔formulário). Em bases já existentes os usuários
**não** são revinculados automaticamente (por design): a atribuição é feita no web (Sprint 2).

## Sprint 2 — Web: controle de uso e revisão (0,5–1 dia)

Sem código novo esperado — validar o fluxo existente:

- [ ] Atribuir/desatribuir o formulário a usuários nos checkboxes "Formulários vinculados".
- [ ] Vincular o formulário ao(s) projeto(s) (`ProjectForm`).
- [ ] Confirmar que o Form Builder exibe e permite editar os campos (selects, multiselect, fotos).
- [ ] (Opcional) Edição da lógica condicional pela UI — hoje só vem do seed.

## Sprint 3 — Mobile: validação no app (0,5–1 dia)

Sem código novo esperado — o renderizador genérico cobre todos os tipos.

- [ ] Bootstrap: o formulário publicado e vinculado aparece em "Formulários vinculados".
- [ ] Coleta offline: condicionais presença/ausência, 5 blocos de foto múltipla com marca
      d'água, GPS, datetime automático, envio e sync.
- [ ] Conferir `validate_required_collection_fields` aceita a coleta.
- [ ] Confirmar que o campo `projeto` não aparece duplicado no formulário (vem do fluxo).

## Sprint 4 — Exportações e QA fim-a-fim (0,5–1 dia)

- [ ] Validar exportações XLSX/KMZ/PDF de uma coleta deste formulário.
- [ ] Smoke test completo: coleta no app → sync → consulta no web → exportar.
- [ ] Validações do README: `compileall`, `npm run build`, `flutter analyze/test`.

---

**Esforço total estimado:** ~3 a 4,5 dias. O grosso (Sprint 1) já está implementado;
web e mobile são majoritariamente validação de fluxos existentes.
