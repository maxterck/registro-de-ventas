import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../sales/presentation/pos_screen.dart'; // import productsProvider

class ProductFormView extends ConsumerStatefulWidget {
  final Map<String, dynamic>? productToEdit;
  final VoidCallback onProductSaved;

  const ProductFormView({super.key, this.productToEdit, required this.onProductSaved});

  @override
  ConsumerState<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends ConsumerState<ProductFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = 'General';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      _nameController.text = widget.productToEdit!['name'];
      _priceController.text = widget.productToEdit!['price'].toString();
      _category = widget.productToEdit!['category'] ?? 'General';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);

    try {
      final supabase = Supabase.instance.client;
      final productData = {
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'category': _category,
        'store_id': session?.storeId,
      };

      if (widget.productToEdit == null) {
        // Create new
        await supabase.from('products').insert(productData);
      } else {
        // Update existing
        await supabase.from('products').update(productData).eq('id', widget.productToEdit!['id']);
      }

      ref.invalidate(productsProvider); // Actualizar UI
      
      if (mounted) {
         if (widget.productToEdit == null) {
            // Limpiar si es creación
            _nameController.clear();
            _priceController.clear();
            setState(() => _category = 'General');
         }
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto guardado correctamente'), backgroundColor: Colors.green)
         );
         widget.onProductSaved();
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red)
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productToEdit == null ? 'Añadir Nuevo Producto' : 'Editar Producto',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre del Producto',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.inventory_2, color: Colors.indigoAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
              ),
              validator: (v) => v!.isEmpty ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Precio de Venta (\$)',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.indigoAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
              ),
              validator: (v) {
                 if (v!.isEmpty) return 'El precio es obligatorio';
                 if (double.tryParse(v) == null) return 'Precio inválido';
                 return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              dropdownColor: const Color(0xFF1c2128),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Categoría',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.category, color: Colors.indigoAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
              ),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General')),
                DropdownMenuItem(value: 'Bebidas', child: Text('Bebidas')),
                DropdownMenuItem(value: 'Snacks', child: Text('Snacks')),
                DropdownMenuItem(value: 'Golosinas', child: Text('Golosinas')),
                DropdownMenuItem(value: 'Lácteos', child: Text('Lácteos')),
                DropdownMenuItem(value: 'Limpieza', child: Text('Limpieza')),
                DropdownMenuItem(value: 'Peso/Cantidad', child: Text('Peso/Cantidad ⚖️')),
                DropdownMenuItem(value: 'Otros', child: Text('Otros')),
              ],
              onChanged: (val) => setState(() => _category = val!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.productToEdit == null ? 'GUARDAR PRODUCTO' : 'ACTUALIZAR PRODUCTO', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
