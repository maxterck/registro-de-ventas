import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository(ref));

class SalesRepository {
  final Ref ref;
  final supabase = Supabase.instance.client;

  SalesRepository(this.ref);

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
      await supabase.from('sales').insert({
        'store_id': session.storeId,
        'product_id': productId,
        'product_name_snapshot': productDescription,
        'amount': amount,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'is_debt': isDebt,
        if (session.role != 'admin') 'created_by_key': session.keyId,
        // El timestamp lo gestiona la BD automáticamente con el DEFAULT NOW()
      });
    } catch (e) {
      throw Exception('Ocurrió un error al guardar la venta: $e');
    }
  }
}
