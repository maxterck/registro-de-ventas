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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('AÑADIR PRODUCTO', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
        onPressed: () => _showProductForm(),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No hay productos en el catálogo.', style: TextStyle(color: Colors.white54)));
          }

          // Obtain unique categories
          final categories = {'Todas'};
          for (var p in products) {
            if (p['category'] != null) {
              categories.add(p['category'] as String);
            }
          }
          final categoryList = categories.toList()..sort();

          // Filter products based on selected category
          final filteredProducts = _selectedCategory == 'Todas' 
             ? products 
             : products.where((p) => p['category'] == _selectedCategory).toList();

          return Column(
            children: [
              Container(
                color: const Color(0xFF161b22),
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: categoryList.length,
                  itemBuilder: (context, index) {
                    final cat = categoryList[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                           _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigoAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.indigoAccent : Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // bottom padding for FAB
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final p = filteredProducts[index];
                    return Card(
                      color: const Color(0xFF161b22),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white12)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.withOpacity(0.2),
                          foregroundColor: Colors.indigoAccent,
                          child: const Icon(Icons.inventory_2),
                        ),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text('Categoría: ${p['category'] ?? "General"} | Precio: \$${p['price']}', style: const TextStyle(color: Colors.white54)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70),
                              tooltip: 'Editar',
                              onPressed: () => _showProductForm(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              tooltip: 'Eliminar',
                              onPressed: () => _deleteProduct(context, ref, p['id'], p['name']),
                            ),
                          ],
                        ),
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
