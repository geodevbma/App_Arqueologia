import 'package:go_router/go_router.dart';

import '../screens/collection_detail_screen.dart';
import '../screens/collection_form_screen.dart';
import '../screens/home_shell.dart';
import '../screens/initial_sync_screen.dart';
import '../screens/login_screen.dart';
import '../screens/poco_teste_form_screen.dart';
import '../screens/project_forms_screen.dart';
import '../screens/splash_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const InitialSyncScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/forms',
        builder: (context, state) =>
            ProjectFormsScreen(project: state.extra! as Map<String, dynamic>),
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
      GoRoute(
        path: '/poco-teste',
        builder: (context, state) {
          final args = state.extra! as Map<String, dynamic>;
          return PocoTesteFormScreen(
            project: args['project'] as Map<String, dynamic>,
            form: args['form'] as Map<String, dynamic>,
            existingPayload: args['payload'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/collection-detail',
        builder: (context, state) => CollectionDetailScreen(
          payload: state.extra! as Map<String, dynamic>,
        ),
      ),
    ],
  );
}
