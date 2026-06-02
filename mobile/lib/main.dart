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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('CREATE TABLE projects(id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE sections(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE work_points(id TEXT PRIMARY KEY, section_id TEXT NOT NULL, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE forms(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, payload TEXT NOT NULL)');
        await db.execute(
          'CREATE TABLE collections(local_uuid TEXT PRIMARY KEY, project_id TEXT NOT NULL, form_id TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, synced_at TEXT, server_uuid TEXT)',
        );
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
      batch.insert(
        'forms',
        {'id': data['id'], 'project_id': data['project_id'], 'payload': jsonEncode(data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> projects() async {
    final rows = await db.query('projects', orderBy: 'payload');
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> formsForProject(String projectId) async {
    final rows = await db.query('forms', where: 'project_id = ?', whereArgs: [projectId]);
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
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
                    onTap: () => context.push('/collect', extra: {'project': project, 'form': form}),
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
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.04),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({super.key, required this.project, required this.form});
  final Map<String, dynamic> project;
  final Map<String, dynamic> form;

  @override
  ConsumerState<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  final description = TextEditingController();
  final otherPoint = TextEditingController();
  final vestigeDetail = TextEditingController();
  final issueDetail = TextEditingController();
  DateTime collectionDate = DateTime.now();
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> points = [];
  String? sectionId;
  String? pointId;
  bool pointOther = false;
  bool vestige = false;
  bool issue = false;
  double? latitude;
  double? longitude;
  double? accuracy;
  double? originalLatitude;
  double? originalLongitude;
  bool coordinateEdited = false;
  String? activityPhoto;
  String? landscapePhoto;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    description.dispose();
    otherPoint.dispose();
    vestigeDetail.dispose();
    issueDetail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadedSections = await ref.read(storeProvider).sectionsForProject(widget.project['id'] as String);
    final loadedPoints = loadedSections.isEmpty ? <Map<String, dynamic>>[] : await ref.read(storeProvider).pointsForSection(loadedSections.first['id'] as String);
    setState(() {
      sections = loadedSections;
      sectionId = loadedSections.isEmpty ? null : loadedSections.first['id'] as String;
      points = loadedPoints;
      loading = false;
    });
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

  Future<void> _captureGps() async {
    setState(() => error = null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => error = 'Permissao de localizacao negada.');
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
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

  Future<void> _photo(String type) async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 74, maxWidth: 1600);
    if (image == null) return;
    setState(() {
      if (type == 'activity_photo') {
        activityPhoto = image.path;
      } else {
        landscapePhoto = image.path;
      }
    });
  }

  String? _validate() {
    if (sectionId == null) return 'Selecione um trecho.';
    if (!pointOther && pointId == null) return 'Selecione obra/ponto.';
    if (pointOther && otherPoint.text.trim().isEmpty) return 'Informe qual ponto em Outro.';
    if (latitude == null || longitude == null) return 'Capture ou edite a coordenada.';
    if (activityPhoto == null) return 'Foto da atividade e obrigatoria.';
    if (landscapePhoto == null) return 'Foto da paisagem e obrigatoria.';
    if (description.text.trim().isEmpty) return 'Descricao da atividade e obrigatoria.';
    if (vestige && vestigeDetail.text.trim().isEmpty) return 'Informe qual vestigio foi identificado.';
    if (issue && issueDetail.text.trim().isEmpty) return 'Informe qual intercorrencia ocorreu.';
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    final user = await ref.read(storeProvider).user();
    final now = DateTime.now().toIso8601String();
    final localUuid = const Uuid().v4();
    final payload = {
      'local_uuid': localUuid,
      'project_id': widget.project['id'],
      'form_id': widget.form['id'],
      'form_version': widget.form['current_version'] ?? 1,
      'section_id': sectionId,
      'work_point_id': pointOther ? null : pointId,
      'work_point_other': pointOther ? otherPoint.text.trim() : null,
      'collection_date': DateFormat('yyyy-MM-dd').format(collectionDate),
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': accuracy,
      'original_latitude': originalLatitude,
      'original_longitude': originalLongitude,
      'coordinate_was_edited': coordinateEdited,
      'status': 'pending_sync',
      'sync_status': 'pending_sync',
      'created_locally_at': now,
      'updated_locally_at': now,
      'answers': [
        {'field_key': 'archaeologist_name', 'answer_value': user?['name'] ?? ''},
        {'field_key': 'activity_description', 'answer_value': description.text.trim()},
        {'field_key': 'vestigio_identificado', 'answer_value': vestige},
        {'field_key': 'qual_vestigio', 'answer_value': vestige ? vestigeDetail.text.trim() : ''},
        {'field_key': 'intercorrencia_identificada', 'answer_value': issue},
        {'field_key': 'qual_intercorrencia', 'answer_value': issue ? issueDetail.text.trim() : ''},
      ],
      'photos': [
        {
          'photo_type': 'activity_photo',
          'file_path': activityPhoto,
          'original_filename': p.basename(activityPhoto!),
          'latitude': latitude,
          'longitude': longitude,
          'taken_at': now,
          'metadata': {'project': widget.project['name'], 'form': widget.form['name']},
        },
        {
          'photo_type': 'landscape_photo',
          'file_path': landscapePhoto,
          'original_filename': p.basename(landscapePhoto!),
          'latitude': latitude,
          'longitude': longitude,
          'taken_at': now,
          'metadata': {'project': widget.project['name'], 'form': widget.form['name']},
        },
      ],
    };
    await ref.read(storeProvider).saveCollection(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coleta salva na caixa de saida.')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nova coleta')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rascunho'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Finalizar coleta'),
              ),
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
          PremiumCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(labelText: 'Trecho'),
                  items: sections.map((section) => DropdownMenuItem(value: section['id'] as String, child: Text(section['name'] as String))).toList(),
                  onChanged: (value) => value == null ? null : _changeSection(value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: pointOther ? 'other' : pointId,
                  decoration: const InputDecoration(labelText: 'Obra/Ponto'),
                  items: [
                    ...points.map((point) => DropdownMenuItem(value: point['id'] as String, child: Text(point['name'] as String))),
                    const DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                  onChanged: (value) => setState(() {
                    pointOther = value == 'other';
                    pointId = pointOther ? null : value;
                  }),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: pointOther
                      ? Padding(
                          key: const ValueKey('other-point'),
                          padding: const EdgeInsets.only(top: 12),
                          child: TextField(controller: otherPoint, decoration: const InputDecoration(labelText: 'Qual?')),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da coleta'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(collectionDate)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: collectionDate);
                    if (selected != null) setState(() => collectionDate = selected);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(icon: Icons.gps_fixed_rounded, title: 'Ponto georreferenciado'),
                const SizedBox(height: 12),
                StatusBanner(
                  icon: latitude == null ? Icons.location_searching_rounded : Icons.my_location_rounded,
                  text: latitude == null ? 'Coordenada ainda nao capturada' : '${latitude!.toStringAsFixed(7)}, ${longitude!.toStringAsFixed(7)} - precisao ${accuracy?.toStringAsFixed(1) ?? '-'} m',
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
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(icon: Icons.camera_alt_rounded, title: 'Fotos obrigatorias'),
                const SizedBox(height: 12),
                PhotoButton(label: 'Foto da atividade', path: activityPhoto, onPressed: () => _photo('activity_photo')),
                const SizedBox(height: 10),
                PhotoButton(label: 'Foto da paisagem', path: landscapePhoto, onPressed: () => _photo('landscape_photo')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              children: [
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Descricao da atividade'), maxLines: 4),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: vestige,
                  onChanged: (value) => setState(() => vestige = value),
                  title: const Text('Foi identificado algum vestigio arqueologico?'),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: vestige ? TextField(key: const ValueKey('vestige'), controller: vestigeDetail, decoration: const InputDecoration(labelText: 'Qual vestigio?')) : const SizedBox.shrink(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: issue,
                  onChanged: (value) => setState(() => issue = value),
                  title: const Text('Houve alguma intercorrencia?'),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: issue ? TextField(key: const ValueKey('issue'), controller: issueDetail, decoration: const InputDecoration(labelText: 'Qual intercorrencia?')) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              FilledButton.icon(
                onPressed: syncing ? null : _sync,
                icon: syncing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded),
                label: const Text('Sincronizar agora'),
              ),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                const EmptyPanel(icon: Icons.done_all_rounded, title: 'Tudo sincronizado', text: 'Nao existem coletas pendentes neste aparelho.')
              else
                ...rows.map((row) => CollectionTile(row: row, pending: true)),
            ],
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
                ...rows.map((row) => CollectionTile(row: row, pending: row['sync_status'] != 'synced')),
            ],
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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    apiUrl.text = await ref.read(storeProvider).setting('api_url') ?? 'http://10.0.2.2:8000';
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
  const CollectionTile({super.key, required this.row, required this.pending});
  final Map<String, dynamic> row;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final answers = (row['answers'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final description = answers.firstWhere(
      (item) => item['field_key'] == 'activity_description',
      orElse: () => {'answer_value': 'Sem descricao'},
    )['answer_value'];
    return PremiumCard(
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
          Chip(label: Text(row['sync_status'] as String? ?? 'pending_sync')),
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
