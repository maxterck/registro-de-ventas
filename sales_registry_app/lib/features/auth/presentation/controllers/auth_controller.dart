import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/employee_session.dart';

final sessionProvider = StateProvider<EmployeeSession?>((ref) => null);
final authLoadingProvider = StateProvider<bool>((ref) => false);
final authErrorProvider = StateProvider<String?>((ref) => null);

Future<bool> loginWithAccessKey(WidgetRef ref, String accessKey) async {
  ref.read(authLoadingProvider.notifier).state = true;
  ref.read(authErrorProvider.notifier).state = null;

  try {
    final supabase = Supabase.instance.client;
    // Buscamos la llave usando maybeSingle()
    final data = await supabase
        .from('access_keys')
        .select('id, store_id, role, employee_name, is_active, can_manage_products')
        .eq('key_token', accessKey)
        .maybeSingle();

    if (data == null) throw Exception('Llave de acceso no encontrada.');
    if (data['is_active'] != true)
      throw Exception('Esta llave ha sido revocada.');

    // Guardar el token para auto-completar en el futuro
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_access_key', accessKey);

    // Autenticación exitosa
    ref.read(sessionProvider.notifier).state = EmployeeSession(
      keyId: data['id'],
      storeId: data['store_id'],
      role: data['role'],
      employeeName: data['employee_name'],
      canManageProducts: data['can_manage_products'] ?? false,
    );
    return true;
  } catch (e) {
    ref.read(authErrorProvider.notifier).state = e.toString().replaceAll(
      'Exception: ',
      '',
    );
    return false;
  } finally {
    ref.read(authLoadingProvider.notifier).state = false;
  }
}

Future<bool> loginAsAdmin(WidgetRef ref, String email, String password) async {
  ref.read(authLoadingProvider.notifier).state = true;
  ref.read(authErrorProvider.notifier).state = null;

  try {
    final supabase = Supabase.instance.client;
    
    // Iniciar sesión con Email y Contraseña de Administrador
    final authResponse = await supabase.auth.signInWithPassword(email: email, password: password);
    final user = authResponse.user;
    
    if (user == null) throw Exception('Credenciales incorrectas.');

    // Buscar el negocio del administrador
    final storeData = await supabase
        .from('stores')
        .select('*')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (storeData == null) {
       await supabase.auth.signOut();
       throw Exception('No tienes un negocio configurado.');
    }

    // Autenticación de Administrador Exitosa
    // Simulamos una EmployeeSession con permisos máximos y marcamos el role como 'admin'
    ref.read(sessionProvider.notifier).state = EmployeeSession(
      keyId: user.id, // Usamos el uid como keyId de forma temporal
      storeId: storeData['id'],
      role: 'admin',
      employeeName: 'Administrador',
      canManageProducts: true,
    );
    return true;
  } catch (e) {
    ref.read(authErrorProvider.notifier).state = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException(message: ', '').replaceAll(', statusCode: 400)', '');
    return false;
  } finally {
    ref.read(authLoadingProvider.notifier).state = false;
  }
}
