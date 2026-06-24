import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  late Database db;

  /// Increments on every write to the `collections` table so the UI can react
  /// to changes (new collection, draft update, marked as synced) immediately.
  final ValueNotifier<int> collectionsRevision = ValueNotifier<int>(0);

  void _bumpCollections() => collectionsRevision.value++;

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'brandt_arqueologia.db');
    db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE projects(id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE sections(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE work_points(id TEXT PRIMARY KEY, section_id TEXT NOT NULL, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE forms(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE collections(local_uuid TEXT PRIMARY KEY, project_id TEXT NOT NULL, form_id TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, synced_at TEXT, server_uuid TEXT)',
        );
      },
    );
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> setting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveBootstrap(Map<String, dynamic> payload) async {
    final batch = db.batch();
    batch.delete('projects');
    batch.delete('sections');
    batch.delete('work_points');
    batch.delete('forms');
    batch.insert('settings', {
      'key': 'user',
      'value': jsonEncode(payload['user']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final project in payload['projects'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(project as Map);
      batch.insert('projects', {
        'id': data['id'],
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final section in payload['sections'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(section as Map);
      batch.insert('sections', {
        'id': data['id'],
        'project_id': data['project_id'],
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final point in payload['work_points'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(point as Map);
      batch.insert('work_points', {
        'id': data['id'],
        'section_id': data['section_id'],
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final form in payload['forms'] as List<dynamic>) {
      final data = Map<String, dynamic>.from(form as Map);
      batch.insert('forms', {
        'id': data['id'],
        'project_id': data['project_id'],
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> projects() async {
    final rows = await db.query('projects', orderBy: 'payload');
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> formsForProject(String projectId) async {
    final rows = await db.query(
      'forms',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> allForms() async {
    final rows = await db.query('forms', orderBy: 'payload');
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<Map<String, dynamic>?> projectById(String projectId) async {
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> formById(String formId) async {
    final rows = await db.query(
      'forms',
      where: 'id = ?',
      whereArgs: [formId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> sectionsForProject(
    String projectId,
  ) async {
    final rows = await db.query(
      'sections',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'payload',
    );
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> pointsForSection(String sectionId) async {
    final rows = await db.query(
      'work_points',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'payload',
    );
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
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
    // Preserve the original device creation timestamp when re-saving an
    // existing collection (e.g. continuing a draft).
    final existing = await db.query(
      'collections',
      columns: ['created_at'],
      where: 'local_uuid = ?',
      whereArgs: [payload['local_uuid']],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? existing.first['created_at'] as String
        : DateTime.now().toIso8601String();
    await db.insert('collections', {
      'local_uuid': payload['local_uuid'],
      'project_id': payload['project_id'],
      'form_id': payload['form_id'],
      'payload': jsonEncode(payload),
      'status': payload['status'] ?? payload['sync_status'],
      'created_at': createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _bumpCollections();
  }

  Future<List<Map<String, dynamic>>> collections({
    bool onlyPending = false,
  }) async {
    // Pending = ready to sync. Drafts are intentionally excluded so that
    // incomplete collections never reach the server.
    final rows = await db.query(
      'collections',
      where: onlyPending ? "status NOT IN ('synced', 'draft')" : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      payload['status_local'] = row['status'];
      payload['server_uuid'] = row['server_uuid'];
      payload['created_at_device'] = row['created_at'];
      payload['synced_at_device'] = row['synced_at'];
      return payload;
    }).toList();
  }

  Future<void> markSynced(String localUuid, String serverUuid) async {
    final rows = await db.query(
      'collections',
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final payload =
        jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
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
    _bumpCollections();
  }
}
