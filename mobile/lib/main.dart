import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.instance.init();
  runApp(const ProviderScope(child: BrandtApp()));
}

final storeProvider = Provider<LocalStore>((ref) => LocalStore.instance);
final apiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(storeProvider)));

const brandtGreen = Color(0xFF0A7354);
const brandtGreenAccent = Color(0xFF339A51);
const brandtBlue = Color(0xFF0F486E);
const darkForest = Color(0xFF061411);
const softBackground = Color(0xFFF4F8F6);
const borderSoft = Color(0xFFDCE7E3);
const textDark = Color(0xFF10231F);
const textMuted = Color(0xFF64756F);
const collectionWriterRoles = {'admin', 'coordinator', 'archaeologist'};
const systemManagerRoles = {'admin', 'coordinator'};

const roleLabels = <String, String>{
  'admin': 'Administrador',
  'coordinator': 'Coordenador',
  'archaeologist': 'Arqueologo',
  'viewer': 'Visualizador',
};

String roleNameFromUser(Map<String, dynamic>? user) {
  final role = user?['role'];
  if (role is Map) return role['name'] as String? ?? '';
  return '';
}

bool canCollectWithUser(Map<String, dynamic>? user) {
  return collectionWriterRoles.contains(roleNameFromUser(user));
}

bool canManageAccess(Map<String, dynamic>? user) {
  return systemManagerRoles.contains(roleNameFromUser(user));
}

bool canEditLocalCollection(Map<String, dynamic>? user, Map<String, dynamic> row) {
  final role = roleNameFromUser(user);
  if (role == 'admin' || role == 'coordinator') return true;
  if (role != 'archaeologist') return false;
  final ownerId = row['user_id'] as String?;
  return ownerId == null || ownerId == user?['id'];
}

Future<void> openCollectionEditor(BuildContext context, WidgetRef ref, Map<String, dynamic> row) async {
  final store = ref.read(storeProvider);
  final project = await store.projectById(row['project_id'] as String);
  final form = await store.formById(row['form_id'] as String);
  if (!context.mounted) return;
  if (project == null || form == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Projeto ou formulario local nao encontrado.')));
    return;
  }
  context.push('/collect', extra: {'project': project, 'form': form, 'collection': row});
}

class BrandtApp extends ConsumerWidget {
  const BrandtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/sync', builder: (context, state) => const InitialSyncScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
        GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
        GoRoute(
          path: '/users/editor',
          builder: (context, state) {
            final args = state.extra! as Map<String, dynamic>;
            return UserEditorScreen(
              user: args['user'] as Map<String, dynamic>?,
              projects: (args['projects'] as List<dynamic>).cast<Map<String, dynamic>>(),
              forms: (args['forms'] as List<dynamic>).cast<Map<String, dynamic>>(),
            );
          },
        ),
        GoRoute(
          path: '/forms',
          builder: (context, state) => ProjectFormsScreen(project: state.extra! as Map<String, dynamic>),
        ),
        GoRoute(
          path: '/collect',
          builder: (context, state) {
            final args = state.extra! as Map<String, dynamic>;
            return CollectionFormScreen(
              project: args['project'] as Map<String, dynamic>,
              form: args['form'] as Map<String, dynamic>,
              collection: args['collection'] as Map<String, dynamic>?,
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Arqueologia Brandt',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandtGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: softBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: softBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: textDark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderSoft)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderSoft)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: brandtGreen, width: 1.4)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();
  late Database db;

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'brandt_arqueologia.db');
    db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('CREATE TABLE projects(id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE sections(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE work_points(id TEXT PRIMARY KEY, section_id TEXT NOT NULL, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE forms(id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE form_projects(project_id TEXT NOT NULL, form_id TEXT NOT NULL, PRIMARY KEY(project_id, form_id))');
        await db.execute(
          'CREATE TABLE collections(local_uuid TEXT PRIMARY KEY, project_id TEXT NOT NULL, form_id TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, synced_at TEXT, server_uuid TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Formularios passam a ser muitos-para-muitos com projetos.
          await db.execute('DROP TABLE IF EXISTS forms');
          await db.execute('CREATE TABLE forms(id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
          await db.execute('CREATE TABLE IF NOT EXISTS form_projects(project_id TEXT NOT NULL, form_id TEXT NOT NULL, PRIMARY KEY(project_id, form_id))');
        }
      },
    );
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> setting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveBootstrap(Map<String, dynamic> payload) async {
    final batch = db.batch();
    batch.delete('projects');
    batch.delete('sections');
    batch.delete('work_points');
    batch.delete('forms');
    batch.delete('form_projects');
    batch.insert('settings', {'key': 'user', 'value': jsonEncode(payload['user'])}, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final project in payload['projects'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(project as Map);
      batch.insert('projects', {'id': data['id'], 'payload': jsonEncode(data)}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final section in payload['sections'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(section as Map);
      batch.insert(
        'sections',
        {'id': data['id'], 'project_id': data['project_id'], 'payload': jsonEncode(data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final point in payload['work_points'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(point as Map);
      batch.insert(
        'work_points',
        {'id': data['id'], 'section_id': data['section_id'], 'payload': jsonEncode(data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final form in payload['forms'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(form as Map);
      batch.insert('forms', {'id': data['id'], 'payload': jsonEncode(data)}, conflictAlgorithm: ConflictAlgorithm.replace);
      final projectIds = (data['project_ids'] as List<dynamic>?)?.cast<String>() ??
          [if (data['project_id'] != null) data['project_id'] as String];
      for (final projectId in projectIds) {
        batch.insert(
          'form_projects',
          {'project_id': projectId, 'form_id': data['id']},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> projects() async {
    final rows = await db.query('projects', orderBy: 'payload');
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> formsForProject(String projectId) async {
    final rows = await db.rawQuery(
      'SELECT f.payload AS payload FROM form_projects fp JOIN forms f ON f.id = fp.form_id WHERE fp.project_id = ?',
      [projectId],
    );
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> allForms() async {
    final rows = await db.query('forms', orderBy: 'payload');
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> projectById(String projectId) async {
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [projectId], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> formById(String formId) async {
    final rows = await db.query('forms', where: 'id = ?', whereArgs: [formId], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> sectionsForProject(String projectId) async {
    final rows = await db.query('sections', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'payload');
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> pointsForSection(String sectionId) async {
    final rows = await db.query('work_points', where: 'section_id = ?', whereArgs: [sectionId], orderBy: 'payload');
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<int> projectCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM projects');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> user() async {
    final value = await setting('user');
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> saveCollection(Map<String, dynamic> payload) async {
    await db.insert(
      'collections',
      {
        'local_uuid': payload['local_uuid'],
        'project_id': payload['project_id'],
        'form_id': payload['form_id'],
        'payload': jsonEncode(payload),
        'status': payload['sync_status'],
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> collections({bool onlyPending = false}) async {
    final rows = await db.query(
      'collections',
      where: onlyPending ? 'status != ?' : null,
      whereArgs: onlyPending ? ['synced'] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      payload['status_local'] = row['status'];
      payload['server_uuid'] = row['server_uuid'];
      payload['created_at_device'] = row['created_at'];
      payload['synced_at_device'] = row['synced_at'];
      return payload;
    }).toList();
  }

  Future<void> markSynced(String localUuid, String serverUuid) async {
    final rows = await db.query('collections', where: 'local_uuid = ?', whereArgs: [localUuid], limit: 1);
    if (rows.isEmpty) return;
    final payload = jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    payload['status'] = 'synced';
    payload['sync_status'] = 'synced';
    await db.update(
      'collections',
      {
        'payload': jsonEncode(payload),
        'status': 'synced',
        'server_uuid': serverUuid,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }
}

class ApiClient {
  ApiClient(this.store);
  final LocalStore store;

  Future<Dio> _dio() async {
    final baseUrl = await store.setting('api_url') ?? 'http://10.0.2.2:8000';
    final token = await store.setting('token');
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 24),
        headers: token == null || token.isEmpty ? null : {'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<void> login(String email, String password) async {
    final dio = await _dio();
    final response = await dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password});
    await store.setSetting('token', response.data!['access_token'] as String);
  }

  Future<void> bootstrap() async {
    final dio = await _dio();
    final response = await dio.get<Map<String, dynamic>>('/mobile/bootstrap');
    await store.saveBootstrap(response.data!);
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final dio = await _dio();
    final response = await dio.get<List<dynamic>>('/users');
    return (response.data ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    final dio = await _dio();
    await dio.post<Map<String, dynamic>>('/users', data: payload);
  }

  Future<void> updateUser(String id, Map<String, dynamic> payload) async {
    final dio = await _dio();
    await dio.put<Map<String, dynamic>>('/users/$id', data: payload);
  }

  Future<Map<String, dynamic>> syncPending() async {
    final dio = await _dio();
    final pending = await store.collections(onlyPending: true);
    final response = await dio.post<Map<String, dynamic>>(
      '/mobile/sync',
      data: {'device_id': 'android-${const Uuid().v4()}', 'collections': pending},
    );
    final synced = (response.data?['synced'] as List<dynamic>? ?? []);
    for (final item in synced) {
      final row = Map<String, dynamic>.from(item as Map);
      await store.markSynced(row['local_uuid'] as String, row['server_uuid'] as String);
    }
    return response.data ?? {'synced': [], 'errors': []};
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    await Future<void>.delayed(900.ms);
    final token = await ref.read(storeProvider).setting('token');
    if (!mounted) return;
    context.go(token == null || token.isEmpty ? '/login' : '/sync');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [darkForest, brandtGreen, brandtBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 250,
                height: 88,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 40, offset: const Offset(0, 24))],
                ),
                child: Image.asset('assets/images/brandt-logo.png', fit: BoxFit.contain),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(0.92, 0.92), end: const Offset(1.04, 1.04)),
              const SizedBox(height: 24),
              const Text(
                'Sistema de Acompanhamento Arqueologico',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coleta offline-first em campo',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(text: 'arqueologo@brandt.local');
  final password = TextEditingController(text: 'Campo123!');
  final apiUrl = TextEditingController(text: 'http://10.0.2.2:8000');
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    apiUrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(storeProvider).setSetting('api_url', apiUrl.text.trim());
      await ref.read(apiProvider).login(email.text.trim(), password.text);
      if (mounted) context.go('/sync');
    } on Object catch (exception) {
      setState(() => error = 'Nao foi possivel conectar a API: $exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _offline() async {
    final token = await ref.read(storeProvider).setting('token');
    final count = await ref.read(storeProvider).projectCount();
    if (!mounted) return;
    if (token != null && token.isNotEmpty && count > 0) {
      context.go('/home');
    } else {
      setState(() => error = 'Primeiro acesso precisa de internet para baixar dados.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderSoft),
                  boxShadow: [BoxShadow(color: darkForest.withValues(alpha: 0.08), blurRadius: 28, offset: const Offset(0, 16))],
                ),
                child: Image.asset('assets/images/brandt-logo.png', fit: BoxFit.contain),
              ),
            ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.06),
            const SizedBox(height: 18),
            PremiumHeader(
              icon: Icons.lock_rounded,
              title: 'Login de campo',
              subtitle: 'Entre uma vez com internet para ativar o uso offline.',
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                children: [
                  TextField(controller: apiUrl, decoration: const InputDecoration(labelText: 'URL da API')),
                  const SizedBox(height: 12),
                  TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: password, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: loading ? null : _login,
                    icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
                    label: const Text('Entrar e sincronizar'),
                  ),
                  TextButton.icon(onPressed: loading ? null : _offline, icon: const Icon(Icons.cloud_off_rounded), label: const Text('Entrar offline')),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08),
          ],
        ),
      ),
    );
  }
}

class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  String step = 'Preparando sincronizacao inicial';
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      setState(() => step = 'Baixando projetos, trechos, pontos e formularios');
      await ref.read(apiProvider).bootstrap();
      setState(() => step = 'Dados salvos em SQLite');
      await Future<void>.delayed(450.ms);
      if (mounted) context.go('/home');
    } on Object catch (exception) {
      final count = await ref.read(storeProvider).projectCount();
      if (count > 0 && mounted) {
        context.go('/home');
        return;
      }
      setState(() => error = 'Falha no bootstrap: $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PremiumHeader(icon: Icons.sync_rounded, title: 'Sincronizacao inicial', subtitle: step),
              const SizedBox(height: 28),
              if (error == null)
                const LinearProgressIndicator(minHeight: 8).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms)
              else
                StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
              if (error != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _sync, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ProjectsScreen(),
      const OutboxScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline_rounded), selectedIcon: Icon(Icons.work_rounded), label: 'Projetos'),
          NavigationDestination(icon: Icon(Icons.outbox_outlined), selectedIcon: Icon(Icons.outbox_rounded), label: 'Saida'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historico'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(storeProvider).projects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Projetos vinculados')),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(storeProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const PremiumHeader(
                  icon: Icons.explore_rounded,
                  title: 'Campo arqueologico',
                  subtitle: 'Selecione um projeto baixado para abrir formularios publicados.',
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const PremiumSkeleton()
                else if (projects.isEmpty)
                  const EmptyPanel(icon: Icons.cloud_off_rounded, title: 'Sem dados locais', text: 'Faca login com internet para baixar o bootstrap.')
                else
                  ...projects.map(
                    (project) => ProjectCard(
                      project: project,
                      onTap: () => context.push('/forms', extra: project),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProjectFormsScreen extends ConsumerWidget {
  const ProjectFormsScreen({super.key, required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ref.read(storeProvider).user(),
      builder: (context, userSnapshot) {
        final canCollect = canCollectWithUser(userSnapshot.data);
        return Scaffold(
          appBar: AppBar(title: const Text('Formularios')),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(storeProvider).formsForProject(project['id'] as String),
            builder: (context, snapshot) {
              final forms = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PremiumHeader(icon: Icons.dynamic_form_rounded, title: project['name'] as String, subtitle: 'Formularios publicados para coleta offline.'),
                  const SizedBox(height: 18),
                  if (forms.isEmpty)
                    const EmptyPanel(icon: Icons.assignment_outlined, title: 'Nenhum formulario publicado', text: 'Publique um formulario no web e sincronize novamente.')
                  else
                    ...forms.map(
                      (form) => PremiumCard(
                        onTap: canCollect ? () => context.push('/collect', extra: {'project': project, 'form': form}) : null,
                        child: Row(
                          children: [
                            const CircleAvatar(backgroundColor: Color(0xFFE8F5EF), child: Icon(Icons.assignment_rounded, color: brandtGreen)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(form['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('Versao ${form['current_version']} - ${form['status']}', style: TextStyle(color: Colors.black.withValues(alpha: 0.56))),
                                ],
                              ),
                            ),
                            if (canCollect) const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.04),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({super.key, required this.project, required this.form, this.collection});
  final Map<String, dynamic> project;
  final Map<String, dynamic> form;
  final Map<String, dynamic>? collection;

  @override
  ConsumerState<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  late final List<Map<String, dynamic>> fields;
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {};
  final otherPoint = TextEditingController();

  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> points = [];
  String? sectionId;
  String? pointId;
  bool pointOther = false;
  String? _sectionFieldKey;
  String? _pointFieldKey;

  // Coordenada unica (field_type 'coordinate' -> colunas latitude/longitude).
  double? latitude;
  double? longitude;
  double? accuracy;
  double? originalLatitude;
  double? originalLongitude;
  bool coordinateEdited = false;

  Map<String, dynamic>? _user;
  bool loading = true;
  String? error;
  bool get editing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    otherPoint.dispose();
    super.dispose();
  }

  String? _sourceOf(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is Map && options['source'] != null) return options['source'] as String;
    return null;
  }

  bool _multiplePhotos(Map<String, dynamic> field) {
    final options = field['options'];
    return options is Map && options['multiple'] == true;
  }

  List<Map<String, dynamic>> _choices(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is Map && options['choices'] is List) {
      return (options['choices'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  bool _isWorkPointOther(Map<String, dynamic> field) {
    final cond = field['conditional_logic'];
    return cond is Map && _pointFieldKey != null && cond['field'] == _pointFieldKey && cond['value']?.toString() == 'other';
  }

  Future<void> _load() async {
    fields = (widget.form['fields'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort((a, b) => ((a['order_index'] as int?) ?? 0).compareTo((b['order_index'] as int?) ?? 0));

    for (final field in fields) {
      final source = _sourceOf(field);
      if (source == 'sections') _sectionFieldKey = field['field_key'] as String;
      if (source == 'work_points') _pointFieldKey = field['field_key'] as String;
    }

    _user = await ref.read(storeProvider).user();
    final loadedSections = await ref.read(storeProvider).sectionsForProject(widget.project['id'] as String);
    final savedSectionId = widget.collection?['section_id'] as String?;
    final initialSectionId = savedSectionId ?? (loadedSections.isEmpty ? null : loadedSections.first['id'] as String);
    final loadedPoints =
        initialSectionId == null ? <Map<String, dynamic>>[] : await ref.read(storeProvider).pointsForSection(initialSectionId);

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      if (_sourceOf(field) != null || _isWorkPointOther(field) || type == 'coordinate' || type == 'note') continue;
      switch (type) {
        case 'text':
        case 'textarea':
        case 'number':
          _text[key] = TextEditingController();
          break;
        case 'auto_user':
          _text[key] = TextEditingController(text: (_user?['name'] as String?) ?? '');
          break;
        case 'multiselect':
          _values[key] = <String>[];
          break;
        case 'boolean':
          _values[key] = false;
          break;
        case 'date':
        case 'datetime':
          _values[key] = DateTime.now();
          break;
        case 'photo':
          _values[key] = _multiplePhotos(field) ? <String>[] : null;
          break;
        case 'coordinate_list':
          _values[key] = <Map<String, dynamic>>[];
          break;
        case 'select':
        default:
          _values[key] = null;
      }
    }

    setState(() {
      sections = loadedSections;
      sectionId = initialSectionId;
      points = loadedPoints;
      if (widget.collection != null) _applyExistingCollection(widget.collection!);
      loading = false;
    });
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  dynamic _answerValue(Map<String, dynamic> collection, String key) {
    final answers = (collection['answers'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return answers.firstWhere((item) => item['field_key'] == key, orElse: () => {'answer_value': null})['answer_value'];
  }

  List<String> _photoPaths(Map<String, dynamic> collection, String type) {
    final photos = (collection['photos'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return photos.where((item) => item['photo_type'] == type).map((item) => item['file_path'] as String).toList();
  }

  dynamic _readValue(String key) {
    if (key == _sectionFieldKey) return sectionId;
    if (key == _pointFieldKey) return pointOther ? 'other' : pointId;
    if (_text.containsKey(key)) return _text[key]!.text;
    return _values[key];
  }

  bool _visible(Map<String, dynamic> field) {
    final cond = field['conditional_logic'];
    if (cond is! Map) return true;
    final target = _readValue(cond['field'] as String);
    final op = (cond['operator'] as String?) ?? 'equals';
    final val = cond['value'];
    if (op == 'contains') return target is List && target.contains(val);
    if (val is bool) return _asBool(target) == val;
    if (target is bool) return target.toString() == val.toString();
    return (target?.toString() ?? '') == (val?.toString() ?? '');
  }

  void _applyExistingCollection(Map<String, dynamic> collection) {
    sectionId = collection['section_id'] as String?;
    final workPointOther = collection['work_point_other'] as String?;
    pointOther = workPointOther != null && workPointOther.isNotEmpty;
    pointId = pointOther ? null : collection['work_point_id'] as String?;
    otherPoint.text = workPointOther ?? '';
    latitude = _asDouble(collection['latitude']);
    longitude = _asDouble(collection['longitude']);
    accuracy = _asDouble(collection['gps_accuracy']);
    originalLatitude = _asDouble(collection['original_latitude']);
    originalLongitude = _asDouble(collection['original_longitude']);
    coordinateEdited = _asBool(collection['coordinate_was_edited']);

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      if (_sourceOf(field) != null || _isWorkPointOther(field)) continue;
      final saved = _answerValue(collection, key);
      switch (type) {
        case 'text':
        case 'textarea':
        case 'auto_user':
          if (saved != null) _text[key]?.text = saved.toString();
          break;
        case 'number':
          if (saved != null) _text[key]?.text = saved.toString();
          break;
        case 'multiselect':
          _values[key] = saved is List ? saved.map((item) => item.toString()).toList() : <String>[];
          break;
        case 'boolean':
          _values[key] = _asBool(saved);
          break;
        case 'select':
          _values[key] = saved?.toString();
          break;
        case 'date':
        case 'datetime':
          final fromColumn = collection['collection_date'] as String?;
          final raw = saved?.toString() ?? fromColumn;
          _values[key] = raw == null ? _values[key] : DateTime.tryParse(raw);
          break;
        case 'photo':
          final paths = _photoPaths(collection, key);
          _values[key] = _multiplePhotos(field) ? paths : (paths.isEmpty ? null : paths.first);
          break;
        case 'coordinate_list':
          _values[key] = saved is List ? saved.map((item) => Map<String, dynamic>.from(item as Map)).toList() : <Map<String, dynamic>>[];
          break;
      }
    }
  }

  Future<void> _changeSection(String value) async {
    final loadedPoints = await ref.read(storeProvider).pointsForSection(value);
    setState(() {
      sectionId = value;
      points = loadedPoints;
      pointId = null;
      pointOther = false;
    });
  }

  Future<Position?> _capturePosition() async {
    setState(() => error = null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => error = 'Permissao de localizacao negada.');
      return null;
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _captureGps() async {
    final position = await _capturePosition();
    if (position == null) return;
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      originalLatitude ??= position.latitude;
      originalLongitude ??= position.longitude;
      accuracy = position.accuracy;
    });
  }

  Future<void> _manualCoordinate() async {
    final lat = TextEditingController(text: latitude?.toStringAsFixed(7) ?? '');
    final lng = TextEditingController(text: longitude?.toStringAsFixed(7) ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar coordenada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar coordenada')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        originalLatitude ??= latitude;
        originalLongitude ??= longitude;
        latitude = double.tryParse(lat.text.replaceAll(',', '.'));
        longitude = double.tryParse(lng.text.replaceAll(',', '.'));
        coordinateEdited = true;
      });
    }
  }

  int _utmZone(double longitude) => ((longitude + 180) / 6).floor() + 1;

  Future<void> _addCoordinatePoint(String key, Map<String, dynamic> field) async {
    final position = await _capturePosition();
    if (position == null) return;
    final options = field['options'] is Map ? field['options'] as Map : const {};
    final point = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (options['capture_altitude'] == true) 'altitude': double.parse(position.altitude.toStringAsFixed(2)),
      if (options['compute_utm_zone'] == true) 'zona_utm': _utmZone(position.longitude),
      'ponto': '${(_values[key] as List).length + 1}',
    };
    setState(() => (_values[key] as List).add(point));
  }

  Future<String?> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 74, maxWidth: 1600);
    return image?.path;
  }

  String? _validate() {
    for (final field in fields) {
      if (!(field['is_required'] as bool? ?? false)) continue;
      if (!_visible(field)) continue;
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      final label = field['label'] as String;
      final source = _sourceOf(field);
      if (source == 'projects' || type == 'note' || type == 'auto_user') continue;
      if (source == 'sections') {
        if (sectionId == null) return 'Selecione: $label.';
        continue;
      }
      if (source == 'work_points') {
        if (!pointOther && pointId == null) return 'Selecione: $label.';
        continue;
      }
      if (_isWorkPointOther(field)) {
        if (pointOther && otherPoint.text.trim().isEmpty) return 'Informe: $label.';
        continue;
      }
      switch (type) {
        case 'coordinate':
          if (latitude == null || longitude == null) return 'Capture a coordenada: $label.';
          break;
        case 'coordinate_list':
          if ((_values[key] as List).isEmpty) return 'Adicione ao menos um ponto: $label.';
          break;
        case 'photo':
          final value = _values[key];
          if (value == null || (value is List && value.isEmpty)) return 'Foto obrigatoria: $label.';
          break;
        case 'multiselect':
          if ((_values[key] as List).isEmpty) return 'Selecione ao menos uma opcao: $label.';
          break;
        case 'select':
          if (_values[key] == null) return 'Selecione: $label.';
          break;
        case 'date':
        case 'datetime':
          if (_values[key] == null) return 'Informe a data: $label.';
          break;
        default:
          if ((_text[key]?.text.trim() ?? '').isEmpty) return 'Preencha: $label.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    final user = _user ?? await ref.read(storeProvider).user();
    if (!canCollectWithUser(user)) {
      setState(() => error = 'Perfil sem permissao para enviar coletas.');
      return;
    }
    final now = DateTime.now().toIso8601String();
    final existing = widget.collection;
    final localUuid = existing?['local_uuid'] as String? ?? const Uuid().v4();

    final answers = <Map<String, dynamic>>[];
    final photos = <Map<String, dynamic>>[];
    DateTime? primaryDate;
    double? lat = latitude;
    double? lng = longitude;

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      final source = _sourceOf(field);
      if (source != null || _isWorkPointOther(field) || type == 'note') continue;
      final visible = _visible(field);
      switch (type) {
        case 'text':
        case 'textarea':
        case 'auto_user':
          answers.add({'field_key': key, 'answer_value': visible ? _text[key]!.text.trim() : ''});
          break;
        case 'number':
          answers.add({'field_key': key, 'answer_value': visible ? _asDouble(_text[key]!.text) : null});
          break;
        case 'select':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : null});
          break;
        case 'multiselect':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : <String>[]});
          break;
        case 'boolean':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : false});
          break;
        case 'date':
        case 'datetime':
          final value = _values[key] as DateTime?;
          primaryDate ??= value;
          if (type == 'datetime') answers.add({'field_key': key, 'answer_value': value?.toIso8601String()});
          break;
        case 'coordinate':
          // Mapeado para as colunas latitude/longitude da coleta.
          break;
        case 'coordinate_list':
          final list = (_values[key] as List).cast<Map<String, dynamic>>();
          answers.add({'field_key': key, 'answer_value': list});
          if (list.isNotEmpty) {
            lat ??= _asDouble(list.first['latitude']);
            lng ??= _asDouble(list.first['longitude']);
          }
          break;
        case 'photo':
          final value = _values[key];
          final paths = value is List ? value.cast<String>() : (value == null ? <String>[] : [value as String]);
          for (final path in paths) {
            photos.add({
              'photo_type': key,
              'file_path': path,
              'original_filename': p.basename(path),
              'latitude': lat,
              'longitude': lng,
              'taken_at': now,
              'metadata': {'project': widget.project['name'], 'form': widget.form['name'], 'field': key},
            });
          }
          break;
      }
    }

    final payload = {
      'local_uuid': localUuid,
      'project_id': widget.project['id'],
      'form_id': widget.form['id'],
      'form_version': existing?['form_version'] ?? widget.form['current_version'] ?? 1,
      'user_id': existing?['user_id'] ?? user?['id'],
      'section_id': _sectionFieldKey == null ? null : sectionId,
      'work_point_id': _pointFieldKey == null ? null : (pointOther ? null : pointId),
      'work_point_other': _pointFieldKey == null ? null : (pointOther ? otherPoint.text.trim() : null),
      'collection_date': DateFormat('yyyy-MM-dd').format(primaryDate ?? DateTime.now()),
      'latitude': lat,
      'longitude': lng,
      'gps_accuracy': accuracy,
      'original_latitude': originalLatitude,
      'original_longitude': originalLongitude,
      'coordinate_was_edited': coordinateEdited,
      'status': 'pending_sync',
      'sync_status': 'pending_sync',
      'created_locally_at': existing?['created_locally_at'] ?? existing?['created_at_device'] ?? now,
      'updated_locally_at': now,
      'answers': answers,
      'photos': photos,
    };
    await ref.read(storeProvider).saveCollection(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(editing ? 'Coleta atualizada na caixa de saida.' : 'Coleta salva na caixa de saida.')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visibleFields = fields.where(_visible).where((field) => _sourceOf(field) != 'projects').toList();
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar coleta' : 'Nova coleta')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar rascunho')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_circle_rounded), label: const Text('Finalizar coleta')),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumHeader(icon: Icons.assignment_turned_in_rounded, title: widget.form['name'] as String, subtitle: widget.project['name'] as String),
          const SizedBox(height: 18),
          if (error != null) ...[
            StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
            const SizedBox(height: 12),
          ],
          for (final field in visibleFields) ...[
            _buildField(field),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['field_key'] as String;
    final type = field['field_type'] as String;
    final label = field['label'] as String;
    final required = field['is_required'] as bool? ?? false;
    final source = _sourceOf(field);
    final title = required ? '$label *' : label;

    if (source == 'sections') {
      return PremiumCard(
        child: DropdownButtonFormField<String>(
          initialValue: sectionId,
          decoration: InputDecoration(labelText: title),
          items: sections.map((section) => DropdownMenuItem(value: section['id'] as String, child: Text(section['name'] as String))).toList(),
          onChanged: (value) => value == null ? null : _changeSection(value),
        ),
      );
    }

    if (source == 'work_points') {
      final includeOther = field['options'] is Map && field['options']['include_other'] == true;
      return PremiumCard(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: pointOther ? 'other' : pointId,
              decoration: InputDecoration(labelText: title),
              items: [
                ...points.map((point) => DropdownMenuItem(value: point['id'] as String, child: Text(point['name'] as String))),
                if (includeOther) const DropdownMenuItem(value: 'other', child: Text('Outro')),
              ],
              onChanged: (value) => setState(() {
                pointOther = value == 'other';
                pointId = pointOther ? null : value;
              }),
            ),
          ],
        ),
      );
    }

    if (_isWorkPointOther(field)) {
      return PremiumCard(
        child: TextField(controller: otherPoint, decoration: InputDecoration(labelText: title)),
      );
    }

    switch (type) {
      case 'note':
        return PremiumCard(
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF0A7354)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );
      case 'text':
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title)));
      case 'textarea':
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title), maxLines: 4));
      case 'number':
        return PremiumCard(
          child: TextField(
            controller: _text[key],
            decoration: InputDecoration(labelText: title),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        );
      case 'auto_user':
        return PremiumCard(child: TextField(controller: _text[key], readOnly: true, decoration: InputDecoration(labelText: title)));
      case 'boolean':
        return PremiumCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _values[key] as bool? ?? false,
            onChanged: (value) => setState(() => _values[key] = value),
            title: Text(label),
          ),
        );
      case 'select':
        return PremiumCard(
          child: DropdownButtonFormField<String>(
            initialValue: _values[key] as String?,
            decoration: InputDecoration(labelText: title),
            items: _choices(field)
                .map((choice) => DropdownMenuItem(value: choice['value'] as String, child: Text(choice['label'] as String)))
                .toList(),
            onChanged: (value) => setState(() => _values[key] = value),
          ),
        );
      case 'multiselect':
        final selected = (_values[key] as List).cast<String>();
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.checklist_rounded, title: title),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _choices(field).map((choice) {
                  final value = choice['value'] as String;
                  final isOn = selected.contains(value);
                  return FilterChip(
                    label: Text(choice['label'] as String),
                    selected: isOn,
                    onSelected: (on) => setState(() {
                      if (on) {
                        selected.add(value);
                      } else {
                        selected.remove(value);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      case 'date':
      case 'datetime':
        final value = _values[key] as DateTime?;
        final formatted = value == null
            ? 'Selecionar'
            : (type == 'datetime' ? DateFormat('dd/MM/yyyy HH:mm').format(value) : DateFormat('dd/MM/yyyy').format(value));
        return PremiumCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(formatted),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: value ?? DateTime.now(),
              );
              if (selectedDate == null) return;
              var result = selectedDate;
              if (type == 'datetime') {
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()));
                if (time != null) {
                  result = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, time.hour, time.minute);
                }
              }
              setState(() => _values[key] = result);
            },
          ),
        );
      case 'coordinate':
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.gps_fixed_rounded, title: title),
              const SizedBox(height: 12),
              StatusBanner(
                icon: latitude == null ? Icons.location_searching_rounded : Icons.my_location_rounded,
                text: latitude == null
                    ? 'Coordenada ainda nao capturada'
                    : '${latitude!.toStringAsFixed(7)}, ${longitude!.toStringAsFixed(7)} - precisao ${accuracy?.toStringAsFixed(1) ?? '-'} m',
                tone: latitude == null ? BannerTone.warning : BannerTone.success,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: _captureGps, icon: const Icon(Icons.gps_fixed_rounded), label: const Text('Capturar GPS'))),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(onPressed: _manualCoordinate, icon: const Icon(Icons.edit_location_alt_rounded)),
                ],
              ),
            ],
          ),
        );
      case 'coordinate_list':
        final list = (_values[key] as List).cast<Map<String, dynamic>>();
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.share_location_rounded, title: title),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Nenhum ponto adicionado.'))
              else
                ...list.asMap().entries.map((entry) {
                  final point = entry.value;
                  final zona = point['zona_utm'];
                  final alt = point['altitude'];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(radius: 14, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12))),
                    title: Text('${_asDouble(point['latitude'])?.toStringAsFixed(6)}, ${_asDouble(point['longitude'])?.toStringAsFixed(6)}'),
                    subtitle: Text([if (zona != null) 'Zona $zona', if (alt != null) 'Alt ${alt}m'].join(' - ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => list.removeAt(entry.key)),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _addCoordinatePoint(key, field),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Adicionar ponto (GPS)'),
              ),
            ],
          ),
        );
      case 'photo':
        if (_multiplePhotos(field)) {
          final paths = (_values[key] as List).cast<String>();
          return PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(icon: Icons.collections_rounded, title: title),
                const SizedBox(height: 8),
                ...paths.asMap().entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.photo_rounded, color: Color(0xFF0A7354)),
                        title: Text(p.basename(entry.value), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => setState(() => paths.removeAt(entry.key)),
                        ),
                      ),
                    ),
                FilledButton.icon(
                  onPressed: () async {
                    final path = await _pickPhoto();
                    if (path != null) setState(() => paths.add(path));
                  },
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Adicionar foto'),
                ),
              ],
            ),
          );
        }
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.camera_alt_rounded, title: title),
              const SizedBox(height: 12),
              PhotoButton(
                label: label,
                path: _values[key] as String?,
                onPressed: () async {
                  final path = await _pickPhoto();
                  if (path != null) setState(() => _values[key] = path);
                },
              ),
            ],
          ),
        );
      default:
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title)));
    }
  }
}

class OutboxScreen extends ConsumerStatefulWidget {
  const OutboxScreen({super.key});

  @override
  ConsumerState<OutboxScreen> createState() => _OutboxScreenState();
}

class _OutboxScreenState extends ConsumerState<OutboxScreen> {
  bool syncing = false;
  String? message;

  Future<void> _sync() async {
    setState(() {
      syncing = true;
      message = null;
    });
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.any((item) => item != ConnectivityResult.none)) {
        setState(() => message = 'Sem internet. Coletas continuam pendentes.');
        return;
      }
      final result = await ref.read(apiProvider).syncPending();
      setState(() => message = 'Sincronizadas: ${(result['synced'] as List).length}. Erros: ${(result['errors'] as List).length}.');
    } on Object catch (exception) {
      setState(() => message = 'Erro de sincronizacao: $exception');
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa de saida')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(storeProvider).user(),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          final canSync = canCollectWithUser(user);
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(storeProvider).collections(onlyPending: true),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PremiumHeader(icon: Icons.outbox_rounded, title: 'Pendencias de envio', subtitle: 'Quando houver internet, envie as coletas locais para a API.'),
                  const SizedBox(height: 16),
                  if (message != null) ...[
                    StatusBanner(icon: Icons.info_outline_rounded, text: message!, tone: BannerTone.info),
                    const SizedBox(height: 12),
                  ],
                  if (canSync) ...[
                    FilledButton.icon(
                      onPressed: syncing ? null : _sync,
                      icon: syncing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded),
                      label: const Text('Sincronizar agora'),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (rows.isEmpty)
                    const EmptyPanel(icon: Icons.done_all_rounded, title: 'Tudo sincronizado', text: 'Nao existem coletas pendentes neste aparelho.')
                  else
                    ...rows.map(
                      (row) => CollectionTile(
                        row: row,
                        pending: true,
                        onTap: canEditLocalCollection(user, row) ? () => openCollectionEditor(context, ref, row) : null,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historico')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(storeProvider).user(),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(storeProvider).collections(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const PremiumHeader(icon: Icons.history_rounded, title: 'Coletas do aparelho', subtitle: 'Historico local mantido em SQLite.'),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const EmptyPanel(icon: Icons.assignment_outlined, title: 'Sem coletas locais', text: 'Preencha um formulario para iniciar o historico.')
                  else
                    ...rows.map(
                      (row) => CollectionTile(
                        row: row,
                        pending: row['sync_status'] != 'synced',
                        onTap: canEditLocalCollection(user, row) ? () => openCollectionEditor(context, ref, row) : null,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final apiUrl = TextEditingController();
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final url = await ref.read(storeProvider).setting('api_url') ?? 'http://10.0.2.2:8000';
    final user = await ref.read(storeProvider).user();
    if (!mounted) return;
    setState(() {
      apiUrl.text = url;
      me = user;
    });
  }

  @override
  void dispose() {
    apiUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PremiumHeader(icon: Icons.settings_rounded, title: 'Configuracao do app', subtitle: 'Parametros locais usados no modo offline-first.'),
          const SizedBox(height: 18),
          PremiumCard(
            child: Column(
              children: [
                TextField(controller: apiUrl, decoration: const InputDecoration(labelText: 'URL da API')),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(storeProvider).setSetting('api_url', apiUrl.text.trim());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL salva.')));
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar URL'),
                ),
              ],
            ),
          ),
          if (canManageAccess(me)) ...[
            const SizedBox(height: 14),
            PremiumCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5EF), child: Icon(Icons.manage_accounts_rounded, color: brandtGreen)),
                title: const Text('Gerenciar acessos'),
                subtitle: const Text('Cadastre usuarios e libere projetos e formularios.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/users'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          PremiumCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sair do token atual'),
              subtitle: const Text('Os dados offline permanecem no aparelho.'),
              onTap: () async {
                await ref.read(storeProvider).setSetting('token', '');
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> forms = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final store = ref.read(storeProvider);
      final loadedProjects = await store.projects();
      final loadedForms = await store.allForms();
      final loadedUsers = await ref.read(apiProvider).listUsers();
      if (!mounted) return;
      setState(() {
        projects = loadedProjects;
        forms = loadedForms;
        users = loadedUsers;
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Precisa de internet para gerenciar acessos: $exception';
        loading = false;
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? user]) async {
    final saved = await context.push<bool>(
      '/users/editor',
      extra: {'user': user, 'projects': projects, 'forms': forms},
    );
    if (saved == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar acessos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Novo usuario'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PremiumHeader(
              icon: Icons.manage_accounts_rounded,
              title: 'Usuarios e permissoes',
              subtitle: 'Cadastre quem acessa e libere projetos e formularios.',
            ),
            const SizedBox(height: 18),
            if (loading)
              const PremiumSkeleton()
            else if (error != null)
              StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error)
            else if (users.isEmpty)
              const EmptyPanel(icon: Icons.group_off_rounded, title: 'Nenhum usuario', text: 'Toque em "Novo usuario" para cadastrar o primeiro acesso.')
            else
              ...users.map(
                (user) => PremiumCard(
                  onTap: () => _openEditor(user),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE8F5EF),
                        child: Text(
                          _initials(user['name'] as String? ?? '?'),
                          style: const TextStyle(color: brandtGreen, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(user['email'] as String? ?? '-', style: TextStyle(color: Colors.black.withValues(alpha: 0.56))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(roleLabels[roleNameFromUser(user)] ?? roleNameFromUser(user)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${(user['project_ids'] as List<dynamic>? ?? []).length} projetos'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${(user['form_ids'] as List<dynamic>? ?? []).length} forms'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        (user['is_active'] as bool? ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: (user['is_active'] as bool? ?? true) ? brandtGreen : const Color(0xFF9D3D35),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

class UserEditorScreen extends ConsumerStatefulWidget {
  const UserEditorScreen({super.key, this.user, required this.projects, required this.forms});
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> forms;

  @override
  ConsumerState<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends ConsumerState<UserEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController password;
  late String role;
  late bool isActive;
  late Set<String> projectIds;
  late Set<String> formIds;
  bool saving = false;
  String? error;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    name = TextEditingController(text: user?['name'] as String? ?? '');
    email = TextEditingController(text: user?['email'] as String? ?? '');
    password = TextEditingController(text: isEditing ? '' : 'Brandt123!');
    role = isEditing ? roleNameFromUser(user) : 'archaeologist';
    if (!roleLabels.containsKey(role)) role = 'archaeologist';
    isActive = user?['is_active'] as bool? ?? true;
    projectIds = ((user?['project_ids'] as List<dynamic>?) ?? []).map((item) => item as String).toSet();
    formIds = ((user?['form_ids'] as List<dynamic>?) ?? []).map((item) => item as String).toSet();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _toggleProject(String projectId, bool checked) {
    setState(() {
      if (checked) {
        projectIds.add(projectId);
      } else {
        projectIds.remove(projectId);
        formIds.removeWhere((formId) {
          final form = widget.forms.firstWhere((item) => item['id'] == formId, orElse: () => const {});
          return form['project_id'] == projectId;
        });
      }
    });
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => error = 'Informe nome e e-mail.');
      return;
    }
    if (!isEditing && password.text.trim().length < 8) {
      setState(() => error = 'Senha inicial precisa de ao menos 8 caracteres.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final payload = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      'role': role,
      'is_active': isActive,
      'project_ids': projectIds.toList(),
      'form_ids': formIds.toList(),
    };
    if (password.text.trim().isNotEmpty) {
      payload['password'] = password.text.trim();
    }
    try {
      final api = ref.read(apiProvider);
      if (isEditing) {
        await api.updateUser(widget.user!['id'] as String, payload);
      } else {
        await api.createUser(payload);
      }
      if (!mounted) return;
      context.pop(true);
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Nao foi possivel salvar: $exception';
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableForms = widget.forms.where((form) {
      final formProjects = (form['project_ids'] as List<dynamic>?)?.cast<String>() ??
          [if (form['project_id'] != null) form['project_id'] as String];
      return formProjects.any(projectIds.contains);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar usuario' : 'Novo usuario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumHeader(
            icon: Icons.badge_rounded,
            title: isEditing ? name.text : 'Novo acesso',
            subtitle: 'Defina perfil e libere projetos e formularios.',
          ),
          const SizedBox(height: 18),
          PremiumCard(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 12),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: InputDecoration(labelText: isEditing ? 'Nova senha (deixe em branco para manter)' : 'Senha inicial'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: roleLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setState(() => role = value ?? role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  title: const Text('Usuario ativo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const SectionTitle(icon: Icons.work_rounded, title: 'Projetos liberados'),
          const SizedBox(height: 8),
          PremiumCard(
            child: widget.projects.isEmpty
                ? const Text('Nenhum projeto disponivel.')
                : Column(
                    children: widget.projects
                        .map(
                          (project) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: projectIds.contains(project['id'] as String),
                            onChanged: (checked) => _toggleProject(project['id'] as String, checked ?? false),
                            title: Text(project['name'] as String? ?? '-'),
                            subtitle: Text(project['code'] as String? ?? project['status'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 6),
          const SectionTitle(icon: Icons.dynamic_form_rounded, title: 'Formularios liberados'),
          const SizedBox(height: 8),
          PremiumCard(
            child: availableForms.isEmpty
                ? const Text('Selecione um projeto para liberar formularios.')
                : Column(
                    children: availableForms
                        .map(
                          (form) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: formIds.contains(form['id'] as String),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                formIds.add(form['id'] as String);
                              } else {
                                formIds.remove(form['id'] as String);
                              }
                            }),
                            title: Text(form['name'] as String? ?? '-'),
                            subtitle: Text('${form['status'] ?? ''}'),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: Text(isEditing ? 'Salvar usuario' : 'Criar usuario'),
          ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});
  final Map<String, dynamic> project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: const Color(0xFFE8F5EF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.route_rounded, color: brandtGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project['name'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text(project['description'] as String? ?? 'Projeto ativo', maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05);
  }
}

class CollectionTile extends StatelessWidget {
  const CollectionTile({super.key, required this.row, required this.pending, this.onTap});
  final Map<String, dynamic> row;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final answers = (row['answers'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final description = answers.firstWhere(
      (item) => item['field_key'] == 'activity_description',
      orElse: () => {'answer_value': 'Sem descricao'},
    )['answer_value'];
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: pending ? const Color(0xFFFFE8CC) : const Color(0xFFE8F5EF),
            child: Icon(pending ? Icons.sync_problem_rounded : Icons.done_all_rounded, color: pending ? const Color(0xFF946200) : brandtGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['collection_date'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('$description', maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(label: Text(row['sync_status'] as String? ?? 'pending_sync')),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, color: brandtGreen),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.04);
  }
}

class PremiumHeader extends StatelessWidget {
  const PremiumHeader({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [darkForest, brandtGreen, brandtBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: darkForest.withValues(alpha: 0.18), blurRadius: 34, offset: const Offset(0, 18))],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.16), foregroundColor: Colors.white, child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.74))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderSoft),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: brandtGreen),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class PhotoButton extends StatelessWidget {
  const PhotoButton({super.key, required this.label, required this.path, required this.onPressed});
  final String label;
  final String? path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(path == null ? Icons.camera_alt_rounded : Icons.check_circle_rounded),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(path == null ? label : '$label capturada'),
      ),
    );
  }
}

enum BannerTone { success, warning, error, info }

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.icon, required this.text, required this.tone});
  final IconData icon;
  final String text;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      BannerTone.success => brandtGreen,
      BannerTone.warning => const Color(0xFFD8A23F),
      BannerTone.error => const Color(0xFF9D3D35),
      BannerTone.info => brandtBlue,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        children: [
          Icon(icon, size: 42, color: brandtGreen),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class PremiumSkeleton extends StatelessWidget {
  const PremiumSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1100.ms),
      ),
    );
  }
}
