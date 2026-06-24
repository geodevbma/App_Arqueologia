import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync_service.dart';

/// Drives automatic synchronization for the whole app. It triggers a sync:
/// - once shortly after startup;
/// - whenever connectivity is (re)gained;
/// - whenever the app returns to the foreground.
///
/// All attempts are best-effort and de-duplicated inside [SyncService].
class AutoSyncScope extends ConsumerStatefulWidget {
  const AutoSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSyncScope> createState() => _AutoSyncScopeState();
}

class _AutoSyncScopeState extends ConsumerState<AutoSyncScope>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((c) => c != ConnectivityResult.none);
      if (online) _sync();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    unawaited(ref.read(syncServiceProvider).trigger());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
