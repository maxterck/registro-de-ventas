import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

final salesListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  
  // Note: we fetch access_keys(employee_name) in JS, flutter supabase supports standard joins:
  final res = await Supabase.instance.client
      .from('sales')
      .select('*, access_keys(employee_name)')
      .eq('store_id', session.storeId)
      .order('timestamp', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

class JefeSalesView extends ConsumerStatefulWidget {
  const JefeSalesView({super.key});

  @override
  ConsumerState<JefeSalesView> createState() => _JefeSalesViewState();
}

class _JefeSalesViewState extends ConsumerState<JefeSalesView> {
  String filter = 'all';

  Future<void> _voidSale(Map<String, dynamic> s) async {
    if (s['is_voided'] == true) return;
    
    // Usamos TextEditingController para el prompt
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('Anular Venta', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('Escribe el motivo de la anulación:', style: TextStyle(color: Colors.white70)),
             const SizedBox(height: 12),
             TextField(
               controller: reasonCtrl,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0b0f14)),
             )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
             onPressed: () {
               if (reasonCtrl.text.trim().isEmpty) return;
               Navigator.pop(ctx, true);
             }, 
             style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
             child: const Text('ANULAR')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('sales').update({
          'is_voided': true,
          'cancel_reason': reasonCtrl.text.trim(),
        }).eq('id', s['id']);
        ref.invalidate(salesListProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _toggleDebt(Map<String, dynamic> s) async {
     if (s['is_voided'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta anulada no se puede modificar'), backgroundColor: Colors.red));
        return;
     }

     final isCurrentlyDebt = s['is_debt'] == true;
     final customerCtrl = TextEditingController();

     bool? confirm;

     if (isCurrentlyDebt) {
        confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161b22),
            title: const Text('¿Pasar a Efectivo?', style: TextStyle(color: Colors.white)),
            content: const Text('Marcar esta deuda como pagada.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar', style: TextStyle(color: Colors.greenAccent))),
            ]
          )
        );
     } else {
        confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161b22),
            title: const Text('¿Pasar a Fiado?', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Text('Ingresa el token/nombre del cliente:', style: TextStyle(color: Colors.white70)),
                 TextField(controller: customerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0b0f14)))
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar', style: TextStyle(color: Colors.orangeAccent))),
            ]
          )
        );
     }

     if (confirm == true) {
        try {
           final finalCustomer = (customerCtrl.text.trim().isEmpty) ? 'Cliente sin registrar' : customerCtrl.text.trim();
           await Supabase.instance.client.from('sales').update({
              'is_debt': !isCurrentlyDebt,
              'payment_method': isCurrentlyDebt ? 'cash' : 'credit',
              if (!isCurrentlyDebt) 'customer_name': finalCustomer,
           }).eq('id', s['id']);
           ref.invalidate(salesListProvider);
        } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSales = ref.watch(salesListProvider);

    return Container(
      color: const Color(0xFF0b0f14),
      child: Column(
        children: [
          Container(
             color: const Color(0xFF161b22),
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _FilterBtn(label: 'Todas', isSelected: filter == 'all', onTap: () => setState(() => filter = 'all'), color: Colors.indigoAccent),
                   _FilterBtn(label: 'Efvo', isSelected: filter == 'cash', onTap: () => setState(() => filter = 'cash'), color: Colors.greenAccent),
                   _FilterBtn(label: 'Transf', isSelected: filter == 'transfer', onTap: () => setState(() => filter = 'transfer'), color: Colors.blueAccent),
                   _FilterBtn(label: 'Fiados', isSelected: filter == 'credit', onTap: () => setState(() => filter = 'credit'), color: Colors.orangeAccent),
                ],
             ),
          ),
          Expanded(
            child: asyncSales.when(
              data: (list) {
                final filtered = filter == 'all' ? list : list.where((s) => s['payment_method'] == filter).toList();
                
                final totalRev = filtered.fold<double>(0, (sum, s) => sum + ((s['is_voided'] == true) ? 0 : (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0)));

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF161b22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.indigo.withOpacity(0.3))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           const Text('Total del Filtro:', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                           Text('\$${totalRev.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                           final s = filtered[i];
                           final isVoid = s['is_voided'] == true;
                           final isDebt = s['is_debt'] == true;
                           final dt = DateTime.parse(s['timestamp']).toLocal();

                           return Container(
                             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                                color: const Color(0xFF161b22), 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: isVoid ? Colors.red.withOpacity(0.2) : Colors.white12)
                             ),
                             foregroundDecoration: isVoid ? BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16)) : null,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(s['product_name_snapshot'], style: TextStyle(color: Colors.white, fontSize: 16, decoration: isVoid ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold))),
                                      Text('\$${s['amount']}', style: TextStyle(color: isDebt ? Colors.orangeAccent : Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                             Text('Cajero: ${s['access_keys']?['employee_name'] ?? '?'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                             Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                             if (isDebt) Text('Cliente: ${s['customer_name']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                             if (isVoid) Text('Motivo: ${s['cancel_reason']}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                          ]
                                       ),
                                       Row(
                                          children: [
                                             IconButton(icon: Icon(isDebt ? Icons.check_circle : Icons.edit, color: isDebt ? Colors.greenAccent : Colors.orangeAccent), onPressed: () => _toggleDebt(s)),
                                             IconButton(icon: const Icon(Icons.delete, color: Colors.white30), onPressed: () => _voidSale(s)),
                                          ],
                                       )
                                     ],
                                  )
                               ],
                             ),
                           );
                        },
                      ),
                    )
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
            ),
          )
        ],
      )
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterBtn({required this.label, required this.isSelected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white12)
         ),
         child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.bold)),
      )
    );
  }
}
