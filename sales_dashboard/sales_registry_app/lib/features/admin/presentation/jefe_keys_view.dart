import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

final keysProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  
  final res = await Supabase.instance.client
      .from('access_keys')
      .select('*, sales(amount)')
      .eq('store_id', session.storeId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

class JefeKeysView extends ConsumerStatefulWidget {
  const JefeKeysView({super.key});

  @override
  ConsumerState<JefeKeysView> createState() => _JefeKeysViewState();
}

class _JefeKeysViewState extends ConsumerState<JefeKeysView> {
  final _nameController = TextEditingController();
  String _newRole = 'edit';
  bool _isLoading = false;

  Future<void> _createKey() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final token = "POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 12)}";

    try {
      await Supabase.instance.client.from('access_keys').insert({
        'store_id': session?.storeId,
        'key_token': token,
        'employee_name': name,
        'role': _newRole,
        'is_active': true,
      });
      _nameController.clear();
      ref.invalidate(keysProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso generado con éxito'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> keyData) async {
    try {
      await Supabase.instance.client.from('access_keys').update({'is_active': !keyData['is_active']}).eq('id', keyData['id']);
      ref.invalidate(keysProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleVIP(Map<String, dynamic> keyData) async {
    try {
      await Supabase.instance.client.from('access_keys').update({'can_manage_products': !(keyData['can_manage_products'] ?? false)}).eq('id', keyData['id']);
      ref.invalidate(keysProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permisos de Cajero actualizados'), backgroundColor: Colors.indigo));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Verifica tu SQL column can_manage_products. $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteKey(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Acceso'),
        content: const Text('¿Seguro que deseas eliminar permanentemente este acceso?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      )
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('access_keys').delete().eq('id', id);
        ref.invalidate(keysProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(keysProvider);

    return Container(
      color: const Color(0xFF0b0f14),
      child: Column(
        children: [
          // Header / Form
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF161b22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Añadir Nuevo Empleado o Caja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nombre (Ej. Juan Perez)',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF0b0f14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF161b22),
                        value: _newRole,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0b0f14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'edit', child: Text('Cajero')),
                          DropdownMenuItem(value: 'read_only', child: Text('Lector')),
                        ],
                        onChanged: (v) => setState(() => _newRole = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('GENERAR ACCESO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: keysAsync.when(
              data: (keys) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final keyData = keys[index];
                  final isActive = keyData['is_active'] == true;
                  final salesList = (keyData['sales'] as List?) ?? [];
                  final revenue = salesList.fold<double>(0, (sum, s) => sum + (num.tryParse(s['amount']?.toString() ?? '0')?.toDouble() ?? 0.0));

                  return Card(
                    color: const Color(0xFF161b22),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isActive ? Colors.indigoAccent.withOpacity(0.3) : Colors.red.withOpacity(0.3))
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: isActive ? Colors.indigo.withOpacity(0.2) : Colors.red.withOpacity(0.2), child: Icon(Icons.monitor, color: isActive ? Colors.indigoAccent : Colors.redAccent)),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(keyData['employee_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                      Text(keyData['role'] == 'edit' ? 'Cajero Activo ${(keyData['can_manage_products'] == true) ? '(VIP)' : ''}' : 'Solo Lectura', style: TextStyle(color: keyData['role'] == 'edit' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(icon: Icon(Icons.star, color: (keyData['can_manage_products'] == true) ? Colors.amber : Colors.white30), tooltip: 'VIP', onPressed: () => _toggleVIP(keyData)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.white30), onPressed: () => _deleteKey(keyData['id'])),
                                ],
                              )
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recaudado: \$${revenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                  Text('Token: ${keyData['key_token']}', style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                ],
                              ),
                              Switch(
                                value: isActive,
                                activeColor: Colors.greenAccent,
                                inactiveThumbColor: Colors.redAccent,
                                inactiveTrackColor: Colors.red.withOpacity(0.3),
                                onChanged: (val) => _toggleStatus(keyData),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
            ),
          )
        ],
      ),
    );
  }
}
