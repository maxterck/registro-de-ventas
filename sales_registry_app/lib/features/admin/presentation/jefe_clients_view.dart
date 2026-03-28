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
             Navigator.pop(context); // cerrar bottom sheet si está abierto
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deuda saldada correctamente.'), backgroundColor: Colors.green));
          }
       } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
       }
    }
  }

  void _showClientDetails(BuildContext context, WidgetRef ref, String client, List<Map<String, dynamic>> sales, bool canSettle) {
     final totalOwed = sales.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));
     final saleIds = sales.map((e) => e['id'].toString()).toList();

     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
           height: MediaQuery.of(context).size.height * 0.7,
           decoration: const BoxDecoration(
              color: Color(0xFF0d1117),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
           ),
           child: Column(
              children: [
                 Container(
                    width: 50, height: 6,
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))
                 ),
                 Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                       crossAxisAlignment: CrossAxisAlignment.center,
                       children: [
                          const CircleAvatar(radius: 20, backgroundColor: Colors.orangeAccent, child: Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 16),
                          Expanded(
                             child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(client, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                   Text('${sales.length} consumos pendientes', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                             )
                          ),
                          Text('\$${totalOwed.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                       ],
                    )
                 ),
                 const Divider(color: Colors.white12, height: 32),
                 Expanded(
                    child: ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 24),
                       itemCount: sales.length,
                       itemBuilder: (ctx, i) {
                          final s = sales[i];
                          final date = DateTime.tryParse(s['timestamp'].toString());
                          final dateStr = date != null ? '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : '';
                          return Container(
                             margin: const EdgeInsets.only(bottom: 12),
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(color: const Color(0xFF161b22), borderRadius: BorderRadius.circular(16)),
                             child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                   Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Text(s['product_name_snapshot'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                         const SizedBox(height: 4),
                                         Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                      ],
                                   ),
                                   Text('\$${s['amount']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                ]
                             )
                          );
                       }
                    )
                 ),
                 if (canSettle)
                    Padding(
                       padding: const EdgeInsets.all(24),
                       child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                             icon: const Icon(Icons.scale, color: Colors.white),
                             label: const Text('COMPENSAR Y SALDAR TODO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16, color: Colors.white)),
                             style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                             ),
                             onPressed: () => _settleClientDebt(context, ref, client, saleIds),
                          ),
                       ),
                    )
                 else
                    const Padding(
                       padding: EdgeInsets.all(24),
                       child: Text('Solo los perfiles con Permisos de Deuda (Balanza) pueden compensar cuentas.', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
                    )
              ],
           )
        )
     );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSales = ref.watch(salesListProvider);
    final session = ref.watch(sessionProvider);
    final canSettle = session?.canSettleDebts ?? false;

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
                     child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 2,
                           crossAxisSpacing: 16,
                           mainAxisSpacing: 16,
                           childAspectRatio: 0.85,
                        ),
                        itemCount: keys.length,
                        itemBuilder: (ctx, i) {
                           final client = keys[i];
                           final sales = debtsByClient[client]!;
                           final totalOwed = sales.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));

                           return GestureDetector(
                              onTap: () => _showClientDetails(context, ref, client, sales, canSettle),
                              child: Container(
                                 decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                       colors: [Color(0xFF1c2128), Color(0xFF161b22)],
                                       begin: Alignment.topLeft, end: Alignment.bottomRight
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.15))
                                 ),
                                 padding: const EdgeInsets.all(16),
                                 child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                       const CircleAvatar(
                                          radius: 26,
                                          backgroundColor: Colors.orangeAccent,
                                          child: Icon(Icons.person, color: Colors.white, size: 30),
                                       ),
                                       const SizedBox(height: 12),
                                       Text(
                                          client, 
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                       ),
                                       const SizedBox(height: 8),
                                       Text(
                                          '\$${totalOwed.toStringAsFixed(2)}', 
                                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.w900)
                                       ),
                                       const Spacer(),
                                       Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                             color: canSettle ? Colors.green.withOpacity(0.15) : Colors.white10,
                                             borderRadius: BorderRadius.circular(12)
                                          ),
                                          child: Row(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                                Icon(canSettle ? Icons.scale : Icons.remove_red_eye, color: canSettle ? Colors.greenAccent : Colors.white54, size: 16),
                                                const SizedBox(width: 6),
                                                Text(canSettle ? 'Saldar' : 'Ver Detalle', style: TextStyle(color: canSettle ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                                             ],
                                          )
                                       )
                                    ],
                                 )
                              ),
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
