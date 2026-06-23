import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';

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

String initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
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
