import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'controllers/auth_controller.dart';

class ShiftGateScreen extends ConsumerStatefulWidget {
  const ShiftGateScreen({super.key});

  @override
  ConsumerState<ShiftGateScreen> createState() => _ShiftGateScreenState();
}

class _ShiftGateScreenState extends ConsumerState<ShiftGateScreen> {
  final _cashController = TextEditingController();
  bool _isLoading = true;
  bool _needsToOpen = false;

  @override
  void initState() {
    super.initState();
    _checkActiveShift();
  }
  
  @override
  void dispose() {
     _cashController.dispose();
     super.dispose();
  }

  Future<void> _checkActiveShift() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
       if (mounted) context.go('/login');
       return;
    }

    if (!session.requiresShiftControl || session.role == 'admin') {
       if (mounted) {
          context.go('/');
       }
       return;
    }

    try {
      final supabase = Supabase.instance.client;
      final existingShift = await supabase
          .from('shift_records')
          .select('id')
          .eq('access_key_id', session.keyId)
          .eq('status', 'open')
          .maybeSingle();

      if (mounted) {
        if (existingShift != null) {
          // Ya hay turno abierto, pase directo.
          context.go('/');
        } else {
          // Bloqueado hasta abrir turno.
          setState(() {
            _isLoading = false;
            _needsToOpen = true;
          });
        }
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de Red: $e')));
         setState(() => _isLoading = false);
       }
    }
  }

  Future<void> _openShift() async {
    final cashStr = _cashController.text.trim();
    if (cashStr.isEmpty) return;
    
    final cashAmount = double.tryParse(cashStr.replaceAll(',', '.'));
    if (cashAmount == null || cashAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido')));
      return;
    }

    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('shift_records').insert({
        'store_id': session!.storeId,
        'access_key_id': session.keyId,
        'employee_name': session.employeeName,
        'opened_cash': cashAmount,
        'status': 'open'
      });

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir caja: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
         backgroundColor: Color(0xFF0d1117),
         body: Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
       );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
         title: const Text('Comprobación de Turno', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
         backgroundColor: const Color(0xFF161b22),
         elevation: 0,
         centerTitle: true,
         automaticallyImplyLeading: false, // Bloquear volver
         actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () {
                ref.read(sessionProvider.notifier).state = null;
                context.go('/login');
              },
            )
         ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF161b22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5), width: 2)
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock, size: 64, color: Colors.deepPurpleAccent),
                const SizedBox(height: 24),
                const Text('CAJA CERRADA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('El Jefe ha activado el Control Estricto para tu cuenta. Debes declarar el efectivo inicial antes de operar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade300)),
                const SizedBox(height: 32),
                TextField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Efectivo en Caja',
                    labelStyle: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 16),
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.deepPurpleAccent, size: 30),
                    filled: true,
                    fillColor: const Color(0xFF0b0f14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openShift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: const Text('ABRIR MI TURNO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                )
              ]
            ),
          )
        )
      ),
    );
  }
}
