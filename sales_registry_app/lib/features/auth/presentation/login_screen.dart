import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/auth_controller.dart';
import 'admin_login_dialog.dart';
import 'susy_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _keyController = TextEditingController();
  int _adminTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedToken();
  }

  Future<void> _loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_access_key');
    if (saved != null && saved.isNotEmpty && mounted) {
      _keyController.text = saved;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final errorMessage = ref.watch(authErrorProvider);

    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SusyMarketLogo(size: 100),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _adminTapCount++;
                  if (_adminTapCount >= 5) {
                    _adminTapCount = 0;
                    _showAdminLoginDialog(context, ref);
                  }
                },
                child: const Text(
                  'Susy Market',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.indigo,
                    letterSpacing: 1.2
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa para comenzar tu turno',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 48),

              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: 'Llave de Acceso',
                  hintText: 'Ej. POS-AB123',
                  prefixIcon: const Icon(Icons.key, color: Colors.indigo),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                obscureText: true,
              ),
              const SizedBox(height: 16),

              if (errorMessage != null)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_keyController.text.trim().isEmpty) return;

                          final success = await loginWithAccessKey(
                            ref,
                            _keyController.text.trim(),
                          );
                          if (success && context.mounted) {
                            context.go('/'); // Navigate to dashboard/POS view
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.indigo,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdminLoginDialog(),
    );
  }
}

