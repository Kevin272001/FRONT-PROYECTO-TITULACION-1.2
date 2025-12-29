import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

// Providers
import '../providers/auth_provider.dart';

// Services
import '../services/complete_profile_service.dart';

// Pantallas
import 'register_trabajador_screen.dart';
import 'register_employer_screen.dart';
import 'complete_profile_form.dart';
import 'seleccion_screen.dart';
import 'home_trabajador.dart';
import 'empleador/home_empleador_screen.dart';

class LoginScreen extends StatefulWidget {
  final String rol;
  const LoginScreen({super.key, required this.rol});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // ======================================================
  // 🔥 LÓGICA DESPUÉS DEL LOGIN
  // ======================================================
  Future<void> _afterLogin(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final bool isTrabajador = auth.role == 'trabajador';
    final String? token = auth.token;

    // ===========================
    // 🔵 SI ES EMPLEADOR → IR A SU HOME
    // ===========================
    if (!isTrabajador) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeEmpleadorScreen()),
      );
      return;
    }

    // 🔵 SI ES TRABAJADOR Y NO TIENE TOKEN → FUERA
    if (token == null || token.isEmpty) return;

    // ====================================
    // 🔥 1️⃣ Verificar si tiene perfil laboral
    // ====================================
    bool tienePerfil = false;

    try {
      final url = Uri.parse('http://10.0.2.2:4000/api/perfil-laboral/mine');
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        tienePerfil = data["exists"] == true;
      }
    } catch (e) {
      debugPrint('❌ Error consultando perfil: $e');
    }

    if (tienePerfil) {
      await auth.setPerfilCompleto(true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeTrabajadorScreen()),
      );
      return;
    }

    // ====================================
    // 🔥 2️⃣ Preguntar si quiere completar perfil
    // ====================================
    final wantToComplete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Completar perfil'),
        content: const Text(
          'Para continuar necesitas completar tu perfil laboral. ¿Deseas hacerlo ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (wantToComplete != true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SeleccionScreen()),
      );
      return;
    }

    // ====================================
    // 🔥 3️⃣ Mostrar formulario de perfil
    // ====================================
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CompleteProfileForm(
            token: token,
            initialData: null,

            // ✅ OJO: firma nueva (data, file, token)
            onSubmit: (Map<String, dynamic> data, PlatformFile? file, String token) async {
              try {
                // ✅ Aquí se hace JSON si NO hay archivo, y MULTIPART si SÍ hay archivo
                await CompleteProfileService.submit(data, file, token);

                await auth.setPerfilCompleto(true);

                // cerrar el dialog
                Navigator.of(dialogCtx).pop();

                // ir al home
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeTrabajadorScreen()),
                );
              } catch (e) {
                debugPrint('❌ Error guardando perfil: $e');
                rethrow;
              }
            },
          ),
        ),
      ),
    );
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(32),
            width: size.width > 500 ? 400 : double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'INICIAR SESIÓN COMO ${widget.rol.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B21B6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Usuario (correo)',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                final role = await auth.login(
                                  usernameController.text.trim(),
                                  passwordController.text.trim(),
                                );

                                if (role != null) {
                                  await _afterLogin(context);
                                }
                              }
                            },
                      child: auth.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      if (widget.rol == 'trabajador') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterTrabajadorScreen(rol: 'trabajador'),
                          ),
                        );
                      } else {
                        Navigator.pushNamed(context, '/empleador/tipo');
                      }
                    },
                    child: Text(
                      widget.rol == 'trabajador'
                          ? '¿Nuevo trabajador? Regístrate aquí'
                          : '¿Nuevo empleador? Regístrate aquí',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
