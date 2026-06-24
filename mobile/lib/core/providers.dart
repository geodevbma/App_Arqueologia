import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'local_store.dart';

final storeProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(storeProvider)),
);

/// Reactive list of collections. Emits the current rows immediately and again
/// on every change to the `collections` table (save, draft update, sync), so
/// the Saída and Histórico screens always show up-to-date status.
///
/// The boolean family argument is `onlyPending` (true for the outbox).
final collectionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, bool>((
      ref,
      onlyPending,
    ) async* {
      final store = ref.watch(storeProvider);
      final revision = store.collectionsRevision;

      yield await store.collections(onlyPending: onlyPending);

      final controller = StreamController<void>();
      void listener() => controller.add(null);
      revision.addListener(listener);
      ref.onDispose(() {
        revision.removeListener(listener);
        controller.close();
      });

      await for (final _ in controller.stream) {
        yield await store.collections(onlyPending: onlyPending);
      }
    });
