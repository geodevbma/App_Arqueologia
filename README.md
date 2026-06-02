# Sistema de Acompanhamento Arqueologico Brandt

Monorepo com backend FastAPI, frontend React/Vite e aplicativo Flutter Android offline-first para coleta arqueologica em campo.

## Estrutura

- `backend/`: API REST FastAPI, JWT, modelos SQLAlchemy, seed inicial, sincronizacao mobile e exportacoes PDF/Excel/KMZ.
- `frontend/`: SPA React + TypeScript + Vite + Tailwind + Framer Motion, com login, dashboard, usuarios, projetos, form builder, coletas e mapa Leaflet.
- `mobile/`: app Flutter Android com SQLite local, login, bootstrap, coleta offline, GPS, fotos obrigatorias, caixa de saida e sync REST.

## Credenciais seed

- Admin web: `admin@brandt.local` / `Admin123!`
- Coordenador: `coordenador@brandt.local` / `Coord123!`
- Arqueologo app: `arqueologo@brandt.local` / `Campo123!`
- Visualizador: `viewer@brandt.local` / `Viewer123!`

O seed cria o projeto `Projeto de Acompanhamento Arqueologico Ramal Turistico Ouro Preto - Mariana`, os trechos/pontos informados e o `Formulario de Acompanhamento Arqueologico`.

## Backend

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Por padrao, sem `.env`, o backend usa SQLite local para smoke test. Para PostgreSQL, configure:

```env
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/arqueologia_brandt
```

Rotas uteis:

- `GET /health`
- `POST /auth/login`
- `GET /mobile/bootstrap`
- `POST /mobile/sync`
- `GET /exports/collections.xlsx`
- `GET /exports/collections.kmz`
- `GET /collections/{id}/pdf`

## Frontend web

```powershell
cd frontend
npm install
npm run dev
```

O frontend usa `VITE_API_URL` se definido; sem isso usa `http://localhost:8000`.

```env
VITE_API_URL=http://localhost:8000
```

## App Android

```powershell
cd mobile
flutter pub get
flutter run
```

No emulador Android, a URL default da API e `http://10.0.2.2:8000`. Em aparelho fisico, altere a URL na tela de login/ajustes para o IP da maquina rodando o backend.

## Validacoes executadas

```powershell
cd backend
.\.venv\Scripts\python.exe -m compileall app

cd ..\frontend
npm run lint
npm run build

cd ..\mobile
flutter analyze
flutter test
flutter build apk --debug
```

APK debug gerado em `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## Escopo entregue

Implementado no MVP:

- JWT com hash de senha e perfis `admin`, `coordinator`, `archaeologist`, `viewer`.
- Restricao por projeto vinculado.
- CRUD base de usuarios, projetos, trechos, pontos e formularios.
- Form builder web com reordenacao por drag and drop, preview e publicacao.
- Bootstrap mobile para projetos, trechos, pontos e formularios publicados.
- Coleta Android offline em SQLite com fotos obrigatorias, GPS, coordenada editavel e caixa de saida.
- Sincronizacao mobile com regra de prevalencia do dado do celular.
- Consulta web de coletas, detalhe, revisao, mapa e exportacoes.
- Logs de auditoria e sincronizacao.

## Identidade visual Brandt

A camada visual foi refatorada para usar uma identidade institucional baseada na marca Brandt, sem alterar regras de negocio, sincronizacao, formularios, coletas ou exportacoes.

Assets adicionados:

- `frontend/src/assets/brandt-logo.png`
- `mobile/assets/images/brandt-logo.png`
- `mobile/pubspec.yaml` configurado para carregar `assets/images/brandt-logo.png`

Paleta aplicada:

- Brandt Green: `#0A7354`
- Brandt Green Accent: `#339A51`
- Brandt Blue: `#0F486E`
- Dark Forest: `#061411`
- Soft Background: `#F4F8F6`
- Card Background: `#FFFFFF`
- Border Soft: `#DCE7E3`
- Text Dark: `#10231F`
- Text Muted: `#64756F`

Melhorias web:

- Design system Brandt em `frontend/src/index.css`, com tokens de cor, gradientes, sombras, bordas, cards, skeleton e marcadores de mapa.
- Logo Brandt na tela de login e sidebar.
- Login com gradiente institucional, card glass, microinteracoes e loading.
- Dashboard executivo com seis indicadores, status de sincronizacao, coletas recentes, graficos animados e mapa em destaque.
- Usuarios com avatares, badges de perfil/status e painel lateral de criacao.
- Projetos em cards premium com superficies Brandt.
- Form builder em tres areas: biblioteca de campos, canvas drag and drop e painel de propriedades/preview.
- Coletas com tabela premium, badges por status, detalhe em painel e botoes de exportacao.
- Mapa Leaflet com marcadores por status, popup visual e legenda.
- PDF com cabecalho visual usando a logo Brandt quando o asset estiver disponivel.

Melhorias Flutter:

- Splash screen com logo Brandt e gradiente Dark Forest/Brandt Green/Brandt Blue.
- Login com logo, card premium, erro elegante e carregamento animado.
- Tema Material 3 customizado com as cores Brandt.
- Cards, banners, inputs, cabecalhos e bottom navigation alinhados a identidade visual.
- Formulario de coleta com barra inferior fixa para salvar rascunho/finalizar, GPS, fotos e campos condicionais animados.
- Caixa de saida e historico com cards premium, badges e status visual.

Observacao: os assets foram atualizados para seguir a referencia visual enviada da marca `Brandt legacy by strategy`. Caso seja necessario uso pixel perfect da arte oficial, substitua os dois PNGs pelos arquivos originais mantendo os mesmos nomes/caminhos.

Pontos preparados para evolucao:

- Uso de PostGIS com tipos geograficos reais.
- Upload binario das fotos durante sync em lote; hoje o app sincroniza metadados/caminhos e a API tambem oferece endpoint dedicado de upload.
- Testes automatizados de endpoints e fluxos web completos.
