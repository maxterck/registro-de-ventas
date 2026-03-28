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
  String _selectedEmployee = 'Todos';

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

  Future<void> _showHistorial(List<Map<String, dynamic>> filteredList) async {
    final today = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
           backgroundColor: const Color(0xFF161b22),
           title: Text('Historial de Ventas (${today.day}/${today.month}/${today.year})', style: const TextStyle(color: Colors.white, fontSize: 18)),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                SizedBox(
                   width: double.maxFinite,
                   height: 300,
                   child: SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     child: SizedBox(
                        width: 800,
                        height: 300,
                        child: _PulsingScatterPlot(data: filteredList),
                     )
                   ),
                ),
                const SizedBox(height: 16),
                Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('VENTA (Cobrada)', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('FIADO (Deuda)', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                   ],
                )
             ],
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: Colors.white54)))
           ]
        );
      }
    );
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
                final employees = ['Todos', ...list.map((s) => (s['access_keys']?['employee_name'] ?? '?').toString()).toSet()];
                var filtered = filter == 'all' ? list : list.where((s) => s['payment_method'] == filter).toList();
                final scatterData = filtered.toList();
                
                if (_selectedEmployee != 'Todos') {
                   filtered = filtered.where((s) => (s['access_keys']?['employee_name'] ?? '?') == _selectedEmployee).toList();
                }
                
                final totalRev = filtered.fold<double>(0, (sum, s) => sum + ((s['is_voided'] == true) ? 0 : (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0)));

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF161b22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.indigo.withOpacity(0.3))),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               const Text('Total del Filtro:', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                               Text('\$${totalRev.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                               Expanded(
                                 child: DropdownButtonFormField<String>(
                                   dropdownColor: const Color(0xFF1c2128),
                                   value: employees.contains(_selectedEmployee) ? _selectedEmployee : 'Todos',
                                   style: const TextStyle(color: Colors.white, fontSize: 13),
                                   decoration: InputDecoration(
                                     isDense: true,
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     filled: true,
                                     fillColor: const Color(0xFF0b0f14),
                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                   ),
                                   items: employees.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                   onChanged: (v) => setState(() => _selectedEmployee = v!),
                                 )
                               ),
                               const SizedBox(width: 8),
                               ElevatedButton.icon(
                                 onPressed: () => _showHistorial(scatterData),
                                 icon: const Icon(Icons.bar_chart, color: Colors.white, size: 16),
                                 label: const Text('Historial', style: TextStyle(color: Colors.white)),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))
                               )
                            ]
                          )
                        ]
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
                                             if (isDebt) IconButton(icon: const Icon(Icons.check_circle, color: Colors.greenAccent), onPressed: () => _toggleDebt(s)),
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

class _PulsingScatterPlot extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const _PulsingScatterPlot({Key? key, required this.data}) : super(key: key);

  @override
  State<_PulsingScatterPlot> createState() => _PulsingScatterPlotState();
}

class _PulsingScatterPlotState extends State<_PulsingScatterPlot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
         return CustomPaint(
           painter: _ScatterPainter(widget.data, _controller.value),
         );
      }
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double pulseValue;
  _ScatterPainter(this.data, this.pulseValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()..color = Colors.white12..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw axes
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paintLine);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paintLine);

    // Draw grid lines
    for (int i = 0; i <= 24; i += 4) {
      final x = (i / 24) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintLine);
      textPainter.text = TextSpan(text: '${i}h', style: const TextStyle(color: Colors.white30, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width/2), size.height + 4));
    }

    double maxVal = 0;
    for (var d in data) {
       if (d['is_voided'] == true) continue;
       final amt = num.tryParse(d['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
       if (amt > maxVal) maxVal = amt;
    }
    if (maxVal == 0) maxVal = 100;

    // Draw Y axis labels
    for (int i = 0; i <= 4; i++) {
       final y = size.height - ((i / 4) * size.height);
       final val = (maxVal * (i / 4)).toInt();
       textPainter.text = TextSpan(text: '\$$val', style: const TextStyle(color: Colors.white30, fontSize: 10));
       textPainter.layout();
       textPainter.paint(canvas, Offset(-textPainter.width - 4, y - (textPainter.height/2)));
    }

    for (var d in data) {
       if (d['is_voided'] == true) continue;
       final amt = num.tryParse(d['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
       final dt = DateTime.parse(d['timestamp']).toLocal();
       final timeFloat = dt.hour + (dt.minute / 60.0);
       
       final x = (timeFloat / 24) * size.width;
       final y = size.height - ((amt / maxVal) * size.height);

       final isDebt = d['is_debt'] == true;
       final baseColor = isDebt ? Colors.orangeAccent : Colors.lightBlueAccent;

       // Base core point
       final dotPaint = Paint()..color = baseColor;
       canvas.drawCircle(Offset(x, y), 5.0, dotPaint);

       // Pulsing halo stroke
       final haloRadius = 5.0 + (pulseValue * 15.0); 
       final haloOpacity = (1.0 - pulseValue).clamp(0.0, 1.0);

       final strokePaint = Paint()
         ..color = baseColor.withOpacity(haloOpacity)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 2.0;
       canvas.drawCircle(Offset(x, y), haloRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) => true;
}
