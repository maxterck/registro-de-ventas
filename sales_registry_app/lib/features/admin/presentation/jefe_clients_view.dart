import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'jefe_sales_view.dart'; // import salesListProvider para ahorrar request o re-utilizar la lista

final clientsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final res = await Supabase.instance.client
      .from('clients')
      .select('*')
      .eq('store_id', session.storeId)
      .order('created_at', ascending: false);
  return res;
});

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
     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
           Set<String> selectedIds = sales.map((s) => s['id'].toString()).toSet();
           return StatefulBuilder(
              builder: (context, setState) {
                 final currentTotal = sales.where((s) => selectedIds.contains(s['id'].toString()))
                                           .fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));
                 
                 return Container(
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
                                            Text('${selectedIds.length} consumos seleccionados', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                         ],
                                      )
                                   ),
                                   Text('\$${currentTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.w900)),
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
                                   final id = s['id'].toString();
                                   final date = DateTime.tryParse(s['timestamp'].toString());
                                   final dateStr = date != null ? '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : '';
                                   final isSelected = selectedIds.contains(id);
                                   
                                   return GestureDetector(
                                      onTap: () {
                                         setState(() {
                                            if (isSelected) selectedIds.remove(id); else selectedIds.add(id);
                                         });
                                      },
                                      child: Container(
                                         margin: const EdgeInsets.only(bottom: 12),
                                         padding: const EdgeInsets.all(16),
                                         decoration: BoxDecoration(color: isSelected ? const Color(0xFF162030) : const Color(0xFF161b22), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? Colors.orangeAccent.withOpacity(0.5) : Colors.transparent)),
                                         child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                               Expanded(
                                                  child: Column(
                                                     crossAxisAlignment: CrossAxisAlignment.start,
                                                     children: [
                                                        Text(s['product_name_snapshot'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 4),
                                                        Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                                     ],
                                                  )
                                               ),
                                               Text('\$${s['amount']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                               const SizedBox(width: 12),
                                               Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.orangeAccent : Colors.white24)
                                            ]
                                         )
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
                                      label: Text('SALDAR SELECCIONADOS (${selectedIds.length})', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                         backgroundColor: selectedIds.isEmpty ? Colors.grey : Colors.green.shade600,
                                         padding: const EdgeInsets.symmetric(vertical: 16),
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                         elevation: 0,
                                      ),
                                      onPressed: selectedIds.isEmpty ? null : () => _settleClientDebt(context, ref, client, selectedIds.toList()),
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
                 );
              }
           );
        }
     );
  }

  void _showCreateClientDialog(BuildContext context, WidgetRef ref) {
     final session = ref.read(sessionProvider);
     if (session == null) return;
     
     final ctrl = TextEditingController();
     bool isSaving = false;

     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) {
            return AlertDialog(
               backgroundColor: const Color(0xFF161b22),
               title: const Text('Nuevo Token de Persona', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     const Text('Este token permitirá venderle "Fiado" desde la caja registrarla y asociar sus deudas aquí.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                     const SizedBox(height: 16),
                     TextField(
                        controller: ctrl,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                           hintText: 'Nombre y Apellido (Alias)',
                           hintStyle: const TextStyle(color: Colors.white38),
                           filled: true,
                           fillColor: const Color(0xFF0b0f14),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                     )
                  ],
               ),
               actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                  isSaving 
                     ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)))
                     : TextButton(
                        onPressed: () async {
                           final alias = ctrl.text.trim();
                           if (alias.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingresa un nombre'), backgroundColor: Colors.redAccent));
                              return;
                           }
                           setState(() => isSaving = true);
                           try {
                              const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                              final rnd = Random();
                              final s = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
                              final token = 'CLI-$s';

                              await Supabase.instance.client.from('clients').insert({
                                 'store_id': session.storeId,
                                 'token': token,
                                 'alias_names': [alias]
                              });
                              ref.invalidate(clientsProvider);
                              
                              if (ctx.mounted) {
                                 Navigator.pop(ctx);
                                 ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Usuario creado. Su token es: $token', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
                              }
                           } catch (e) {
                              if (ctx.mounted) {
                                 ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                 setState(() => isSaving = false);
                              }
                           }
                        },
                        child: const Text('CREAR TOKEN', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))
                     )
               ],
            );
         }
       )
     );
  }

  Widget _buildClientCard(BuildContext context, WidgetRef ref, Map<String, dynamic> clientData, List<Map<String, dynamic>> allMySales, bool canSettle) {
    final token = clientData['token'].toString();
    final aliasNamesList = (clientData['alias_names'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    final activeDebts = allMySales.where((s) => s['is_debt'] == true).toList();
    final totalOwed = activeDebts.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));
    final totalPaid = allMySales.where((s) => s['is_debt'] == false).fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));

    final isAllPaid = totalOwed <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAllPaid ? Colors.greenAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1.5)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isAllPaid ? const Color(0xFF0f291e) : const Color(0xFF3b1219),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))
            ),
            child: Text(
              isAllPaid ? 'TODO PAGADO (VERDE)' : 'CON DEUDA (ROJO)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isAllPaid ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2
              )
            )
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token Block
                const Text('TOKEN CLIENTE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0b0f14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12)
                  ),
                  child: Text(token, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                
                const SizedBox(height: 16),
                
                // Aliases Block
                if (aliasNamesList.isNotEmpty) ...[
                  const Text('FAMILIAS / NOMBRES', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: aliasNamesList.map((alias) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1f242c),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12)
                      ),
                      child: Text(alias, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ] else const SizedBox(height: 8),
                
                // Debe / Pagado Block
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0b0f14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12)
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time, color: Colors.orangeAccent, size: 12),
                                SizedBox(width: 4),
                                Text('DEBE', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ]
                            ),
                            const SizedBox(height: 8),
                            Text('\$${totalOwed.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        )
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0b0f14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12)
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 12),
                                SizedBox(width: 4),
                                Text('PAGADO', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ]
                            ),
                            const SizedBox(height: 8),
                            Text('\$${totalPaid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        )
                      )
                    )
                  ]
                ),
                
                const SizedBox(height: 16),
                
                // Botón accionar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1f2937),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Gestionar Consumos', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (activeDebts.isNotEmpty) {
                        _showClientDetails(context, ref, '$token - ${aliasNamesList.join(", ")}', activeDebts, canSettle);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay deudas activas para gestionar.'), backgroundColor: Colors.green));
                      }
                    },
                  )
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildOrphanCard(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> orphanSales, bool canSettle) {
    final totalOwed = orphanSales.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));

    return GestureDetector(
      onTap: () => _showClientDetails(context, ref, 'Fiados Antiguos / Sin Token', orphanSales, canSettle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF161b22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3))
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fiados Sueltos u Otros', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('Consumos sin Token vinculado', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  '\$${totalOwed.toStringAsFixed(2)}', 
                  style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w900)
                ),
              ],
            ),
          ],
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSales = ref.watch(salesListProvider);
    final asyncClients = ref.watch(clientsProvider);
    final session = ref.watch(sessionProvider);
    final canSettle = session?.canSettleDebts ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0f14),
      floatingActionButton: canSettle ? FloatingActionButton.extended(
         backgroundColor: Colors.orangeAccent,
         icon: const Icon(Icons.person_add, color: Colors.black),
         label: const Text('CREAR CLIENTE / TOKEN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
         onPressed: () => _showCreateClientDialog(context, ref),
      ) : null,
      body: asyncSales.when(
      data: (allSales) {
        return asyncClients.when(
          data: (allClients) {
             final debtSales = allSales.where((s) => s['is_debt'] == true && s['is_voided'] != true).toList();
             
             final clientDebts = <Map<String, dynamic>, List<Map<String, dynamic>>>{};
             final mappedSaleIds = <String>{};
             
             for (var c in allClients) {
                final token = c['token'].toString();
                final aliases = (c['alias_names'] as List?)?.map((e) => e.toString()).toList() ?? [];
                
                final mySales = debtSales.where((s) {
                   final name = s['customer_name']?.toString() ?? '';
                   return name == token || aliases.contains(name);
                }).toList();
                
                clientDebts[c] = mySales;
                mappedSaleIds.addAll(mySales.map((s) => s['id'].toString()));
             }
             
             final orphanSales = debtSales.where((s) => !mappedSaleIds.contains(s['id'].toString())).toList();
             final globalDebt = debtSales.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));
             
             return Container(
                color: const Color(0xFF0b0f14),
                child: Column(
                   children: [
                      Container(
                         padding: const EdgeInsets.all(24),
                         decoration: const BoxDecoration(color: Color(0xFF161b22), border: Border(bottom: BorderSide(color: Colors.white12))),
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
                      if (clientDebts.isEmpty && orphanSales.isEmpty)
                         const Expanded(child: Center(child: Text('No hay clientes registrados ni deudas activas.', style: TextStyle(color: Colors.white54, fontSize: 16))))
                      else
                         Expanded(
                            child: ListView(
                               padding: const EdgeInsets.all(16),
                               children: [
                                  ...clientDebts.entries.map((entry) => _buildClientCard(context, ref, entry.key, entry.value, canSettle)),
                                  if (orphanSales.isNotEmpty) _buildOrphanCard(context, ref, orphanSales, canSettle),
                                  const SizedBox(height: 80),
                               ]
                            )
                         )
                   ],
                ),
             );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
    ));
  }
}
