import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sales/presentation/pos_screen.dart'; // import productsProvider
import 'product_form_view.dart';

class AdminCatalogView extends ConsumerStatefulWidget {
  const AdminCatalogView({super.key});

  @override
  ConsumerState<AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends ConsumerState<AdminCatalogView> {
  String _selectedCategory = 'Todas';
  String _searchQuery = '';

  Future<void> _updateStock(BuildContext context, WidgetRef ref, String id, int currentStock, int delta) async {
     final newStock = (currentStock + delta).clamp(0, 999999);
     try {
        await Supabase.instance.client.from('products').update({'stock': newStock}).eq('id', id);
        ref.invalidate(productsProvider);
     } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
        }
     }
  }

  Future<void> _deleteProduct(BuildContext context, WidgetRef ref, String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('Eliminar Producto', style: TextStyle(color: Colors.white)),
        content: Text('¿Seguro que deseas eliminar "$name"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
             onPressed: () => Navigator.pop(ctx, true), 
             style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
             child: const Text('Eliminar')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('products').delete().eq('id', id);
        ref.invalidate(productsProvider);
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto eliminado con éxito.'), backgroundColor: Colors.green)
           );
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red)
           );
        }
      }
    }
  }

  void _showProductForm([Map<String, dynamic>? product]) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF161b22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ProductFormView(
             productToEdit: product,
             onProductSaved: () {
                Navigator.pop(ctx);
             },
          ),
        )
      );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0b0f14),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showProductForm(),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No hay productos en el catálogo.', style: TextStyle(color: Colors.white54)));
          }

          // Category list 
          final catSet = <String>{};
          for (var p in products) {
             if (p['category'] != null) catSet.add(p['category'] as String);
          }
          final categoryList = ['Todas', 'En Escasez', ...catSet.toList()..sort()];

          // Filter
          final filteredProducts = products.where((p) {
             final bool matchesSearch = _searchQuery.isEmpty || 
                 (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                 
             final int stock = (p['stock'] as num?)?.toInt() ?? 0;
             final bool matchesCat = _selectedCategory == 'Todas' || 
                 (_selectedCategory == 'En Escasez' ? stock <= 5 : p['category'] == _selectedCategory);
                 
             return matchesSearch && matchesCat;
          }).toList();

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    hintText: 'Buscar producto...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF161b22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              // Category Tabs
              Container(
                color: const Color(0xFF0b0f14),
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categoryList.length,
                  itemBuilder: (context, index) {
                    final cat = categoryList[index];
                    final isSelected = cat == _selectedCategory;
                    final isEscasez = cat == 'En Escasez';
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() { _selectedCategory = cat; });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? (isEscasez ? Colors.amber : Colors.indigoAccent) 
                            : const Color(0xFF161b22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            if (isEscasez) ...[
                               Icon(Icons.warning_amber_rounded, size: 16, color: isSelected ? Colors.black : Colors.amber),
                               const SizedBox(width: 6),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected 
                                   ? (isEscasez ? Colors.black : Colors.white) 
                                   : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Products Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80), 
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                     maxCrossAxisExtent: 400,
                     mainAxisExtent: 130,
                     crossAxisSpacing: 12,
                     mainAxisSpacing: 12,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final p = filteredProducts[index];
                    final int stock = (p['stock'] as num?)?.toInt() ?? 0;
                    final bool isLowStock = stock <= 5;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161b22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isLowStock ? Colors.amber.withOpacity(0.5) : Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                           Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                     const SizedBox(height: 2),
                                     Text(p['category'] ?? "General", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                   ],
                                 ),
                               ),
                               Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                     IconButton(
                                       icon: const Icon(Icons.edit, color: Colors.indigoAccent, size: 20),
                                       padding: EdgeInsets.zero,
                                       constraints: const BoxConstraints(),
                                       onPressed: () => _showProductForm(p),
                                     ),
                                     const SizedBox(width: 8),
                                     IconButton(
                                       icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                       padding: EdgeInsets.zero,
                                       constraints: const BoxConstraints(),
                                       onPressed: () => _deleteProduct(context, ref, p['id'], p['name']),
                                     ),
                                  ],
                               )
                             ]
                           ),
                           const Spacer(),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    const Text('Precio', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text('\$${p['price']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w900)),
                                 ],
                               ),
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.end,
                                 children: [
                                    const Text('Stock Físico', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Container(
                                       margin: const EdgeInsets.only(top: 2),
                                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                       decoration: BoxDecoration(
                                         color: const Color(0xFF0b0f14),
                                         borderRadius: BorderRadius.circular(8),
                                         border: Border.all(color: isLowStock ? Colors.amber.withOpacity(0.3) : Colors.white12),
                                       ),
                                       child: Row(
                                         children: [
                                            InkWell(
                                               onTap: () => _updateStock(context, ref, p['id'], stock, -1),
                                               child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, color: Colors.white54, size: 16)),
                                            ),
                                            Container(
                                               width: 32,
                                               alignment: Alignment.center,
                                               child: Text('$stock', style: TextStyle(color: isLowStock ? Colors.amber : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                            ),
                                            InkWell(
                                               onTap: () => _updateStock(context, ref, p['id'], stock, 1),
                                               child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, color: Colors.white54, size: 16)),
                                            ),
                                         ]
                                       )
                                    )
                                 ],
                               )
                             ],
                           )
                        ]
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
      )
    );
  }
}
