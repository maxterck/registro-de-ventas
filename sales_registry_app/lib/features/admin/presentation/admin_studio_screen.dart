import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'admin_catalog_view.dart';
import 'product_form_view.dart';

import 'jefe_keys_view.dart';
import 'jefe_sales_view.dart';
import 'jefe_clients_view.dart';

class AdminStudioScreen extends ConsumerStatefulWidget {
  const AdminStudioScreen({super.key});

  @override
  ConsumerState<AdminStudioScreen> createState() => _AdminStudioScreenState();
}

class _AdminStudioScreenState extends ConsumerState<AdminStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session == null || session.role != 'admin') {
       return const Scaffold(body: Center(child: Text('Acceso Denegado.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0d1117), // Theme background from web PC
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.store, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('SalesSync: Modo Jefe', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF161b22), // Dark slate/indigo matching PC
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale, color: Colors.greenAccent),
            tooltip: 'Ir a Caja',

            onPressed: () {
               context.go('/');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(sessionProvider.notifier).state = null;
              context.go('/login');
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: Colors.blueGrey.shade400,
          indicatorColor: Colors.indigoAccent,

          indicatorWeight: 4,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.vpn_key), text: 'Accesos'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Ventas'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Catálogo'),
            Tab(icon: Icon(Icons.people), text: 'Fiados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const JefeKeysView(),
          const JefeSalesView(),
          const AdminCatalogView(),
          const JefeClientsView(),
        ],
      ),
    );
  }
}
