import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/sales_repository.dart';
import '../../admin/presentation/admin_catalog_view.dart';
import '../../admin/presentation/jefe_clients_view.dart';

// Provider del Catálogo
final productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final response = await Supabase.instance.client
      .from('products')
      .select()
      .eq('store_id', session.storeId)
      .order('sold_count', ascending: false) // Lo más vendido primero!
      .order('category', ascending: true) // Si no existe localmente, igual lo ordena
      .order('name');
  return response;
});

// Filtros Locales de Muestra
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Proveedor derivado (Filtrado)
final filteredProductsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final category = ref.watch(selectedCategoryProvider);

  return productsAsync.whenData((list) {
    return list.where((p) {
      final matchesSearch = p['name'].toString().toLowerCase().contains(query);
      final pCategory = p['category']?.toString() ?? 'General';
      final matchesCat = category == null || category == 'Todas' || pCategory == category;
      return matchesSearch && matchesCat;
    }).toList();
  });
});

// Estado del carrito local
final cartProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final isCheckingOutProvider = StateProvider<bool>((ref) => false);

class POSScreen extends ConsumerWidget {
  const POSScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final productsAsync = ref.watch(productsProvider); // Para listar Categorías Únicas
    final filteredAsync = ref.watch(filteredProductsProvider); // Para mostrar la Cuadrícula
    final cart = ref.watch(cartProvider);
    
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalCart = cart.fold<double>(0, (sum, item) => sum + (item['price'] as num).toDouble());
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    // Calcular las categorías únicas disponibles
    final rawProducts = productsAsync.value ?? [];
    final uniqueCategories = rawProducts.map((p) => p['category']?.toString() ?? 'General').toSet().toList();
    if (uniqueCategories.isNotEmpty && !uniqueCategories.contains('Todas')) {
       uniqueCategories.insert(0, 'Todas');
    }

    // 1. Cabecera dinámica de Filtros y Búsqueda
    Widget buildSearchAndFilters() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Column(
          children: [
            // Buscador Predictivo
            TextField(
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0)
              ),
            ),
            const SizedBox(height: 12),
            // Chips de Categorías
            if (uniqueCategories.length > 1)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: uniqueCategories.length,
                  separatorBuilder: (_,__) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                     final cat = uniqueCategories[index];
                     final selected = ref.watch(selectedCategoryProvider) == cat || (cat == 'Todas' && ref.watch(selectedCategoryProvider) == null);
                     
                     return ActionChip(
                       label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.indigo)),
                       backgroundColor: selected ? Colors.indigo : Colors.indigo.shade50,
                       side: BorderSide.none,
                       onPressed: () {
                          ref.read(selectedCategoryProvider.notifier).state = cat == 'Todas' ? null : cat;
                       },
                     );
                  },
                ),
              )
          ],
        ),
      );
    }

    // 2. Grid Filtrado de Productos
    Widget buildProductGrid() {
      return filteredAsync.when(
        data: (products) {
          if (products.isEmpty) {
             return const Center(child: Padding(
               padding: EdgeInsets.all(30.0),
               child: Text('No se encontraron productos.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
             ));
          }
          return GridView.builder(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: isDesktop ? 16 : 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2, 
              childAspectRatio: 0.82, // Cambiado un poco para dar espacio a la categoría visualmente
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return InkWell(
                onTap: () async {
                  if (p['category'] == 'Peso/Cantidad') {
                     final ctrl = TextEditingController();
                     final res = await showDialog<double>(
                       context: context,
                       builder: (ctx) => AlertDialog(
                         backgroundColor: const Color(0xFF161b22),
                         title: Text('¿Cantidad de ${p['name']}?', style: const TextStyle(color: Colors.white)),
                         content: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              TextField(
                                controller: ctrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                autofocus: true,
                                decoration: InputDecoration(
                                   filled: true,
                                   fillColor: Colors.black26,
                                   hintText: 'Ej: 1.5 o 0.250',
                                   hintStyle: const TextStyle(color: Colors.white38),
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                                )
                              ),
                              const SizedBox(height: 12),
                              const Text('Tip: Para 250 gramos ingresa 0.250', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                           ]
                         ),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                           TextButton(
                             onPressed: () {
                               final val = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                               Navigator.pop(ctx, val);
                             },
                             child: const Text('AÑADIR', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                           )
                         ]
                       )
                     );
                     
                     if (res != null && res > 0) {
                         final currentCart = ref.read(cartProvider);
                         final finalPrice = (p['price'] as num).toDouble() * res;
                         final updatedProduct = {
                             ...p,
                             'cart_id': DateTime.now().millisecondsSinceEpoch.toString(),
                             'name': '${p['name']} (${res.toStringAsFixed(3)} Kg/Und)',
                             'price': double.parse(finalPrice.toStringAsFixed(2)),
                         };
                         ref.read(cartProvider.notifier).state = [...currentCart, updatedProduct];
                         if (!isDesktop && context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+ ${updatedProduct['name']}', textAlign: TextAlign.center), duration: const Duration(milliseconds: 600), backgroundColor: Colors.indigo, behavior: SnackBarBehavior.floating));
                         }
                     }
                  } else {
                     final currentCart = ref.read(cartProvider);
                     ref.read(cartProvider.notifier).state = [...currentCart, {...p, 'cart_id': DateTime.now().millisecondsSinceEpoch.toString()}];
                     if (!isDesktop && context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+ ${p['name']}', textAlign: TextAlign.center), duration: const Duration(milliseconds: 400), backgroundColor: Colors.indigo, behavior: SnackBarBehavior.floating));
                     }
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.indigo.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Stack(
                    children: [
                      if (p['category'] == 'Peso/Cantidad')
                        Positioned(
                          top: 8, right: 8,
                          child: Icon(Icons.scale, size: 16, color: Colors.orange.shade400),
                        )
                      else
                        Positioned(
                          top: 8, right: 8,
                          child: Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade400),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              p['name'], 
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87, height: 1.2), 
                              textAlign: TextAlign.center, 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const Spacer(),
                            Text(
                              '\$${p['price']}', 
                              style: const TextStyle(fontSize: 22, color: Colors.indigo, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      );
    }

    // 3. Panel del Carrito (Ticket)
    Widget buildCartPanel({bool isModal = false}) {
      return Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: isModal ? const BorderRadius.vertical(top: Radius.circular(24)) : BorderRadius.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TICKET ACTUAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.indigo, letterSpacing: 1.2)),
                  if (isModal) 
                    IconButton(icon: const Icon(Icons.close, color: Colors.indigo), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty 
                ? const Center(child: Text('El ticket está vacío.\nToca un producto para agregarlo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.separated(
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                itemCount: cart.length,
                itemBuilder: (context, index) {
                  final item = cart[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.shopping_bag, size: 18, color: Colors.white)),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text('\$${item['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green)),
                         const SizedBox(width: 8),
                         IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                            onPressed: () {
                               final newCart = List<Map<String, dynamic>>.from(cart)..removeAt(index);
                               ref.read(cartProvider.notifier).state = newCart;
                            },
                         )
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: isModal ? 32 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL A COBRAR:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black54)),
                      Text('\$${totalCart.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.point_of_sale, size: 28),
                    label: const Text('COBRAR VENTA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: (cart.isEmpty) ? null : () {
                       // AL TOCAR COBRAR, LEVANTAMOS EL DIÁLOGO CON OPCIONES (EFECTIVO, DEUDA, CLIENTE)
                       if (isModal && context.mounted) Navigator.pop(context); 
                       showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => CheckoutDialog(cart: cart, total: totalCart)
                       );
                    },
                  )
                ],
              ),
            )
          ],
        ),
      );
    }

    // 4. Layout principal responsive
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Punto de Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Cajero: ${session.employeeName}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (session.canSettleDebts)
            IconButton(
              icon: const Icon(Icons.scale, color: Colors.greenAccent),
              tooltip: 'Saldar Deudas (Fiados)',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                   appBar: AppBar(
                     title: const Text('Deudas y Fiados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     backgroundColor: const Color(0xFF161b22),
                     iconTheme: const IconThemeData(color: Colors.white)
                   ),
                   body: const JefeClientsView()
                )));
              },
            ),
          if (session.canManageProducts)
            IconButton(
              icon: const Icon(Icons.inventory, color: Colors.amberAccent),
              tooltip: 'Modo VIP: Catálogo',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                   appBar: AppBar(
                     title: const Text('Modo VIP: Añadir/Editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     backgroundColor: const Color(0xFF161b22),
                     iconTheme: const IconThemeData(color: Colors.white)
                   ),
                   body: const AdminCatalogView()
                )));
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(sessionProvider.notifier).state = null;
              context.go('/login');
            },
          )
        ],
      ),
      body: isDesktop 
        ? Row(
            children: [
              Expanded(flex: 2, child: Column(children: [ buildSearchAndFilters(), Expanded(child: buildProductGrid()) ])),
              Expanded(flex: 1, child: buildCartPanel(isModal: false)),
            ],
          )
        : Column(
            children: [
              buildSearchAndFilters(),
              Expanded(child: buildProductGrid())
            ],
          ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isDesktop ? null : 
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              shadowColor: Colors.indigo.withOpacity(0.5)
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Consumer(
                  builder: (ctx, modalRef, child) {
                    // Forzamos a que el Builder escuche al cartProvider localmente.
                    // Al cambiar, re-ejecuta buildCartPanel()
                    modalRef.watch(cartProvider);
                    modalRef.watch(isCheckingOutProvider);
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.85,
                      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                      child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: buildCartPanel(isModal: true)),
                    );
                  }
                )
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, size: 24),
                    const SizedBox(width: 12),
                    Text('${cart.length} items', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Ver Ticket -> \$${totalCart.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
              ],
            ),
          ),
        ),
    );
  }
}

// -----------------------------------------------------------------------
// WIDGET MODAL PARA DETALLES DE PAGO Y CLIENTE ESTILO "CHECKOUT" 
// -----------------------------------------------------------------------
class CheckoutDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double total;

  const CheckoutDialog({super.key, required this.cart, required this.total});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  String _paymentMethod = 'cash'; // 'cash', 'transfer', 'credit'
  bool _isProcessing = false;
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  double _changeAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final received = double.tryParse(_cashReceivedController.text.trim()) ?? 0.0;
    setState(() {
      _changeAmount = received - widget.total;
    });
  }

  Future<void> _submitSale() async {
    final customer = _customerController.text.trim();
    final isDebt = _paymentMethod == 'credit';

    if (isDebt && customer.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('⚠️ EL TOKEN DEL CLIENTE ES OBLIGATORIO PARA FIADOS', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)),
        );
        return;
    }

    setState(() => _isProcessing = true);
    final repo = ref.read(salesRepositoryProvider);
    try {
      final customerName = customer.isEmpty ? 'Cliente sin registrar' : customer;

      for (var item in widget.cart) {
        await repo.saveTransaction(
          productId: item['id'],
          productDescription: item['name'],
          amount: (item['price'] as num).toDouble(),
          paymentMethod: _paymentMethod, 
          isDebt: isDebt,
          customerName: customerName
        );
      }
      ref.read(cartProvider.notifier).state = []; // Limpiamos el carrito principal
      if (mounted) {
         Navigator.pop(context); // Cierra el checkout
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('VENTA REGISTRADA CON ÉXITO 💰', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center,), backgroundColor: Colors.green, duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating),
         );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cobrar: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               const Icon(Icons.receipt_long, size: 48, color: Colors.indigo),
               const SizedBox(height: 16),
               const Text('Confirmar Venta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               const SizedBox(height: 8),
               Text('\$${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.green), textAlign: TextAlign.center),
               
               const Divider(height: 48),

               // Cliente Registrado (Obligatorio en Fiado)
               Text(_paymentMethod == 'credit' ? 'Token de Cliente (OBLIGATORIO)' : 'Token de Cliente (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _paymentMethod == 'credit' ? Colors.redAccent : Colors.grey)),
               const SizedBox(height: 8),
               TextField(
                  controller: _customerController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                     hintText: 'Ej. FAM-V1P',
                     prefixIcon: Icon(Icons.person, color: _paymentMethod == 'credit' ? Colors.redAccent : Colors.indigo),
                     filled: true,
                     fillColor: _paymentMethod == 'credit' ? Colors.red.shade50 : Colors.indigo.shade50,
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                  ),
               ),
               
               const SizedBox(height: 24),
               const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
               const SizedBox(height: 8),
               
               // Botones de Selección de Pago
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    _PayMethodBtn(icon: Icons.payments, label: 'Efectivo', isSelected: _paymentMethod == 'cash', onTap: () => setState(() => _paymentMethod = 'cash')),
                    const SizedBox(width: 8),
                    _PayMethodBtn(icon: Icons.compare_arrows, label: 'Transf.', isSelected: _paymentMethod == 'transfer', onTap: () => setState(() => _paymentMethod = 'transfer')),
                    const SizedBox(width: 8),
                    _PayMethodBtn(icon: Icons.money_off, label: 'Fiado', isSelected: _paymentMethod == 'credit', onTap: () => setState(() => _paymentMethod = 'credit')),
                 ],
               ),
               const SizedBox(height: 24),

               // Calculadora de Vuelto Automática (Solo si es en Efectivo)
               if (_paymentMethod == 'cash') ...[
                  const Text('Calculadora de Vuelto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                           TextField(
                              controller: _cashReceivedController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                 hintText: 'Paga con: Ej. ${widget.total.ceil()}',
                                 prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                                 filled: true,
                                 fillColor: Colors.white,
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                              ),
                           ),
                           if (_cashReceivedController.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              if (_changeAmount >= 0)
                                 Text('DAR VUELTO: \$${_changeAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 22), textAlign: TextAlign.center)
                              else
                                 Text('FALTAN: \$${_changeAmount.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                           ]
                        ]
                     )
                  ),
                  const SizedBox(height: 32),
               ] else ...[
                  const SizedBox(height: 32),
               ],

               // Botones Finales
               Row(
                  children: [
                     Expanded(child: OutlinedButton(onPressed: _isProcessing ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)))),
                     const SizedBox(width: 12),
                     Expanded(child: ElevatedButton(onPressed: _isProcessing ? null : _submitSale, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('CONFIRMAR', style: TextStyle(fontWeight: FontWeight.bold)))),
                  ],
               )
            ],
          ),
        ),
      ),
    );
  }
}

class _PayMethodBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PayMethodBtn({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
             color: isSelected ? Colors.indigo : Colors.grey.shade100,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300)
          ),
          child: Column(
             children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13))
             ],
          ),
        ),
      ),
    );
  }
}
