import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository(ref));

class SalesRepository {
  final Ref ref;
  final supabase = Supabase.instance.client;

  SalesRepository(this.ref) {
    // Attempt an initial background sync after startup when repository is created
    Future.delayed(const Duration(seconds: 5), () {
      syncPendingSales();
    });
  }

  Future<void> saveTransaction({
    String? productId,
    required String productDescription,
    required double amount,
    required String paymentMethod, // 'cash', 'transfer', 'credit'
    String? customerName,
    required bool isDebt,
  }) async {
    final session = ref.read(sessionProvider);

    if (session == null) {
      throw Exception('Sesión inválida. Vuelva a iniciar sesión.');
    }

    if (session.role == 'read_only') {
      throw Exception(
        'Tu llave actual no tiene permisos para confirmar ventas.',
      );
    }

    try {
      final saleData = {
        'store_id': session.storeId,
        'product_id': productId,
        'product_name_snapshot': productDescription,
        'amount': amount,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'is_debt': isDebt,
        if (session.role != 'admin') 'created_by_key': session.keyId,
        'timestamp': DateTime.now().toIso8601String(), // Needed for local sorting/sync
      };

      await supabase.from('sales').insert(saleData);

      // Si llegó hasta acá, hay conexión, intentamos vaciar la cola offline anterior
      syncPendingSales();

      if (productId != null) {
        try {
          final productData = await supabase.from('products').select('sold_count').eq('id', productId).maybeSingle();
          if (productData != null) {
            final int currentCount = productData['sold_count'] ?? 0;
            await supabase.from('products').update({'sold_count': currentCount + 1}).eq('id', productId);
          }
        } catch (_) {}
      }
    } catch (e) {
      // Offline fallback: Save to SharedPreferences queue
      try {
        final prefs = await SharedPreferences.getInstance();
        final queueString = prefs.getString('offline_sales_queue') ?? '[]';
        final List<dynamic> queue = jsonDecode(queueString);
        
        final localSaleData = {
          'store_id': session.storeId,
          'product_id': productId,
          'product_name_snapshot': productDescription,
          'amount': amount,
          'payment_method': paymentMethod,
          'customer_name': customerName,
          'is_debt': isDebt,
          if (session.role != 'admin') 'created_by_key': session.keyId,
          'timestamp': DateTime.now().toIso8601String(), // Essential for offline capture
        };
        queue.add(localSaleData);
        await prefs.setString('offline_sales_queue', jsonEncode(queue));
      } catch (innerError) {
         throw Exception('Ocurrió un error al guardar la venta: $e');
      }
    }
  }

  Future<void> syncPendingSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = prefs.getString('offline_sales_queue') ?? '[]';
      final List<dynamic> queue = jsonDecode(queueString);

      if (queue.isEmpty) return;

      // Intentamos subir todo en un batch insertando la lista de mapas
      final List<Map<String, dynamic>> typeSafeQueue = queue.map((e) => Map<String, dynamic>.from(e)).toList();
      await supabase.from('sales').insert(typeSafeQueue);

      // Si fue exitoso, limpiamos la cola
      await prefs.setString('offline_sales_queue', '[]');
    } catch (e) {
      // Si falla, se queda en la cola para el próximo intento
      print('Sincronización pendiente fallida: $e');
    }
  }
}
