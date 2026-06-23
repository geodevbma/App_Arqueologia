import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'local_store.dart';

final storeProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(storeProvider)),
);
