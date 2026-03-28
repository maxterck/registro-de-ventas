import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'jefe_sales_view.dart'; // import salesListProvider para ahorrar request o re-utilizar la lista

class JefeClientsView extends ConsumerWidget {
  const JefeClientsView({super.key});

  Future<void> _settleClientDebt(BuildContext context, WidgetRef ref, String clientName, List<String> saleIds) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('Saldar Deuda Completa', style: TextStyle(color: Colors.white)),
        content: Text('¿Marcar todas las deudas de "$clientName" como pagadas en efectivo?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SALDAR', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (res == true) {
       try {
          await Supabase.instance.client.from('sales').update({
             'is_debt': false,
             'payment_method': 'cash'
          }).inFilter('id', saleIds);
          
          ref.invalidate(salesListProvider); // Al invalidar sales, se actualizarán las ventas y fiados
          if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deuda saldada correctamente.'), backgroundColor: Colors.green));
          }
       } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
       }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSales = ref.watch(salesListProvider);

    return asyncSales.when(
      data: (allSales) {
         // Agrupar por customer_name las ventas que tengan is_debt = true y no esten voided
         final debtsByClient = <String, List<Map<String, dynamic>>>{};
         for (var s in allSales) {
            if (s['is_debt'] == true && s['is_voided'] != true) {
               final name = s['customer_name'] ?? 'Desconocido';
               debtsByClient.putIfAbsent(name, () => []).add(s);
            }
         }

         if (debtsByClient.isEmpty) {
            return Container(
               color: const Color(0xFF0b0f14),
               child: const Center(
                  child: Text('No hay clientes con deudas activas.', style: TextStyle(color: Colors.white54, fontSize: 16))
               )
            );
         }

         final keys = debtsByClient.keys.toList()..sort();
         final globalDebt = debtsByClient.values.expand((element) => element).fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));

         return Container(
            color: const Color(0xFF0b0f14),
            child: Column(
               children: [
                  Container(
                     padding: const EdgeInsets.all(24),
                     decoration: const BoxDecoration(
                        color: Color(0xFF161b22),
                        border: Border(bottom: BorderSide(color: Colors.white12))
                     ),
                     child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text('TOTAL FIADOS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                                 Text('Por Cobrar', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                           ),
                           Text('\$${globalDebt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ],
                     ),
                  ),
                  Expanded(
                     child: ListView.builder(
                        itemCount: keys.length,
                        itemBuilder: (ctx, i) {
                           final client = keys[i];
                           final sales = debtsByClient[client]!;
                           final totalOwed = sales.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));
                           final saleIds = sales.map((e) => e['id'].toString()).toList();

                           return Container(
                              margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                 color: const Color(0xFF161b22),
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))
                              ),
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                          Row(
                                             children: [
                                                const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.person, color: Colors.white)),
                                                const SizedBox(width: 12),
                                                Text(client, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                             ],
                                          ),
                                          Text('\$${totalOwed.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.w900)),
                                       ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Detalle de tickets pendientes:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    ...sales.map((s) => Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                          Text('• ${s['product_name_snapshot']}', style: const TextStyle(color: Colors.white70)),
                                          Text('\$${s['amount']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                       ]
                                    )).toList(),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                       width: double.infinity,
                                       child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check_circle, color: Colors.white),
                                          label: const Text('SALDAR CUENTA COMPLETA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                             backgroundColor: Colors.green,
                                             padding: const EdgeInsets.symmetric(vertical: 12),
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                          ),
                                          onPressed: () => _settleClientDebt(context, ref, client, saleIds),
                                       ),
                                    )
                                 ],
                              )
                           );
                        }
                     )
                  )
               ]
            ),
         );
      },
      loading: () => Container(color: const Color(0xFF0b0f14), child: const Center(child: CircularProgressIndicator())),
      error: (e, st) => Container(color: const Color(0xFF0b0f14), child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white)))),
    );
  }
}
