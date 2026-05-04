import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_session.dart';
import '../core/ui/admin_shell.dart';
import '../features/auth/presentation/login_page.dart';
import 'app_theme.dart';

class ConfiguratorAdminApp extends ConsumerStatefulWidget {
  const ConfiguratorAdminApp({super.key});

  @override
  ConsumerState<ConfiguratorAdminApp> createState() => _ConfiguratorAdminAppState();
}

class _ConfiguratorAdminAppState extends ConsumerState<ConfiguratorAdminApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authSessionProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Configurator Admin',
      theme: buildAdminTheme(),
      home: authState.isLoading
          ? const _SplashScreen()
          : authState.isAuthenticated
              ? const AdminShell()
              : const LoginPage(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
