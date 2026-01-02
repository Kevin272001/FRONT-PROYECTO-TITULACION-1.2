import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_services.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  // ================= ESTADO =================
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _role;
  String? _userName;
  String? _telefono;
  int? _userId;
  int _empleadorId = 0;
  int _trabajadorId = 0;
  String? _token;
  bool _perfilCompleto = false;

  // ================= GETTERS =================
  String? get role => _role;
  String? get userName => _userName;
  String? get telefono => _telefono;
  int? get userId => _userId;
  int get empleadorId => _empleadorId;
  int get trabajadorId => _trabajadorId;
  String? get token => _token;
  bool get perfilCompleto => _perfilCompleto;

  // ================= SETTERS =================
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =====================================================
  // 🔹 LOGIN
  // =====================================================
  Future<String?> login(String email, String password) async {
    isLoading = true;

    try {
      final response = await _authService.login(email, password);
      if (response == null) return null;

      final user = response['user'] ?? {};

      _role = response['rol'];
      _userName = user['nombre'];
      _telefono = user['telefono'];
      _userId = user['id'];
      _token = response['token'];
      _perfilCompleto = response['perfilCompleto'] ?? false;

      final empleador = response['empleador'];
      final trabajador = response['trabajador'];

      if (empleador != null && empleador['id'] != null) {
        _empleadorId = empleador['id'];
      }

      if (trabajador != null && trabajador['id'] != null) {
        _trabajadorId = trabajador['id'];
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
      await prefs.setString('role', _role ?? '');
      await prefs.setString('userName', _userName ?? '');
      await prefs.setString('telefono', _telefono ?? '');
      await prefs.setInt('userId', _userId ?? 0);
      await prefs.setBool('perfilCompleto', _perfilCompleto);
      await prefs.setInt('empleadorId', _empleadorId);
      await prefs.setInt('trabajadorId', _trabajadorId);

      notifyListeners(); // 🔑 CLAVE

      return _role;
    } finally {
      isLoading = false;
    }
  }

  // =====================================================
  // 🔹 REGISTRO BASE
  // =====================================================
  Future<bool> register({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    String telefono = '',
  }) async {
    isLoading = true;

    try {
      final ok = await _authService.registerUser(
        nombre: nombre,
        email: email,
        password: password,
        rol: rol,
        telefono: telefono,
      );

      if (ok) {
        _userName = nombre;
        _telefono = telefono;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', nombre);
        await prefs.setString('telefono', telefono);

        notifyListeners(); // 🔑 CLAVE
      }

      return ok;
    } finally {
      isLoading = false;
    }
  }

  // =====================================================
  // 🔹 REGISTRO TRABAJADOR
  // =====================================================
  Future<bool> registerWorker(
    String nombre,
    String usuario,
    String password,
    String email,
    String telefono,
  ) async {
    return await register(
      nombre: nombre,
      email: email,
      password: password,
      rol: 'trabajador',
      telefono: telefono,
    );
  }

  // =====================================================
  // 🔹 PERFIL COMPLETO
  // =====================================================
  Future<void> setPerfilCompleto(bool value) async {
    _perfilCompleto = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('perfilCompleto', value);
    notifyListeners();
  }

  // =====================================================
  // 🔹 CARGAR SESIÓN (CLAVE PARA AUTOLLENADO)
  // =====================================================
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    _token = prefs.getString('token');
    _role = prefs.getString('role');
    _userName = prefs.getString('userName');
    _telefono = prefs.getString('telefono');
    _userId = prefs.getInt('userId');
    _perfilCompleto = prefs.getBool('perfilCompleto') ?? false;
    _empleadorId = prefs.getInt('empleadorId') ?? 0;
    _trabajadorId = prefs.getInt('trabajadorId') ?? 0;

    notifyListeners(); // 🔑 SIN ESTO NO SE AUTOLLENA
  }

  // =====================================================
  // 🔹 LOGOUT
  // =====================================================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _role = null;
    _userName = null;
    _telefono = null;
    _userId = null;
    _token = null;
    _perfilCompleto = false;
    _empleadorId = 0;
    _trabajadorId = 0;

    notifyListeners();
  }
}
