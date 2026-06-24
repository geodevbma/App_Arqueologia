import 'package:flutter/material.dart';

import 'app_router.dart';
import 'auto_sync_scope.dart';
import 'theme.dart';

class BrandtApp extends StatelessWidget {
  const BrandtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Arqueologia Brandt',
      debugShowCheckedModeBanner: false,
      routerConfig: createAppRouter(),
      theme: buildBrandtTheme(),
      builder: (context, child) =>
          AutoSyncScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
