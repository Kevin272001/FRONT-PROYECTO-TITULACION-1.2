import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class AuthService {
  // =====================================================
  // ✅ BASE URL
  // =====================================================
  final String baseUrl = 'http://10.0.2.2:4000/api';

  // =====================================================
  // 🟦 LOGIN
  // =====================================================
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          return {
            'token': data['token'],
            'rol': data['rol'] ?? data['user']?['rol'],
            'perfilCompleto': data['perfilCompleto'] ?? false,
            'user': data['user'],
            'trabajador': data['trabajador'],
            'empleador': data['empleador'],
          };
        }
      }
    } catch (e) {
      print('❌ ERROR LOGIN SERVICE: $e');
    }

    return null;
  }

  // =====================================================
  // 🟩 REGISTRO (USUARIO / TRABAJADOR / EMPLEADOR)
  // =====================================================
  Future<bool> registerUser({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    String telefono = '',
  }) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
          'rol': rol, // 👈 CLAVE (NO QUITAR)
          'telefono': telefono,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ ERROR REGISTER SERVICE: $e');
      return false;
    }
  }

  // =====================================================
  // 🟧 PERFIL LABORAL (JSON si no hay archivo / MULTIPART si hay archivo)
  // =====================================================
  Future<bool> savePerfilLaboral(Map<String, dynamic> perfil, String token) async {
    final url = Uri.parse('$baseUrl/perfil-laboral');

    try {
      // ✅ puede venir null
      final PlatformFile? file = perfil['recordPolicialFile'] as PlatformFile?;

      // ✅ copiar el mapa SIN PlatformFile (NO se puede jsonEncode)
      final Map<String, dynamic> data = Map<String, dynamic>.from(perfil);
      data.remove('recordPolicialFile');

      // =====================================================
      // ✅ SI HAY ARCHIVO => MULTIPART
      // =====================================================
      if (file != null) {
        final req = http.MultipartRequest('POST', url);
        req.headers['Authorization'] = 'Bearer $token';

        // multipart fields (todo string)
        data.forEach((k, v) {
          if (v == null) return;
          req.fields[k] = v.toString();
        });

        // ✅ Nombre del campo de archivo (DEBE coincidir con tu backend)
        // Ej: multer.single('recordPolicial')
        const fieldName = 'recordPolicial';

        // Android/emulador: normalmente viene path
        if (file.path != null) {
          req.files.add(await http.MultipartFile.fromPath(
            fieldName,
            file.path!,
            filename: file.name,
          ));
        }
        // Web: normalmente viene bytes
        else if (file.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes(
            fieldName,
            file.bytes!,
            filename: file.name,
          ));
        } else {
          throw Exception('No se pudo leer el archivo (path y bytes null).');
        }

        final streamed = await req.send();
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode == 200 || resp.statusCode == 201) return true;

        print('❌ PERFIL LABORAL MULTIPART ERROR ${resp.statusCode}: ${resp.body}');
        return false;
      }

      // =====================================================
      // ✅ SI NO HAY ARCHIVO => JSON NORMAL
      // =====================================================
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return true;

      print('❌ PERFIL LABORAL JSON ERROR ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      print('❌ ERROR PERFIL LABORAL: $e');
      return false;
    }
  }
}
