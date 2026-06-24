import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Coordinates automatic synchronization of pending collections.
///
/// A single in-flight run is guaranteed (concurrent triggers are ignored), and
/// every failure is swallowed so background attempts never surface as crashes.
/// On success, [ApiClient.syncPending] marks collections as synced, which bumps
/// the store revision and refreshes the UI automatically.
class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  bool _running = false;

  /// Attempts to sync now. Returns true when a sync actually ran to completion.
  Future<bool> trigger() async {
    if (_running) return false;
    _running = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((c) => c != ConnectivityResult.none);
      if (!online) return false;

      final store = _ref.read(storeProvider);
      final token = await store.setting('token');
      if (token == null || token.isEmpty) return false;

      final pending = await store.collections(onlyPending: true);
      if (pending.isEmpty) return false;

      await _ref.read(apiProvider).syncPending();
      return true;
    } on Object {
      return false;
    } finally {
      _running = false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
