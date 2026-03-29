import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/shift_gate_screen.dart';
import 'features/sales/presentation/pos_screen.dart';
import 'features/admin/presentation/admin_studio_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase con las credenciales reales
  await Supabase.initialize(
    url: 'https://lrqpnayulfowowomjmbi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxycXBuYXl1bGZvd293b21qbWJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2NTg5ODgsImV4cCI6MjA5MDIzNDk4OH0.EY_HMa0tgtdLQdz_PxXGyIDs1oEA4EJ3buXVFeE2Vdw',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const POSScreen(),
      ),
      GoRoute(
        path: '/admin_studio',
        builder: (context, state) => const AdminStudioScreen(),
      ),
      GoRoute(
        path: '/shift_gate',
        builder: (context, state) => const ShiftGateScreen(),
      ),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Sales POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
