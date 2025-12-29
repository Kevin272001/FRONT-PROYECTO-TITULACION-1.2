import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrabajadorProvider extends ChangeNotifier {
  Map<String, dynamic>? perfil;
  bool loading = false;

  // OJO: este endpoint es el que tú ya usas
  final String baseUrl = "http://10.0.2.2:4000/api/perfil-laboral";

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    if (t == null || t.trim().isEmpty) return null;
    return t;
  }

  // ============================================================
  // ✅ Helper: sacar URL del récord policial venga como venga
  // ============================================================
  String? _extractRecordUrl(Map<String, dynamic>? data) {
    if (data == null) return null;

    const keys = [
      "recordPolicialUrl",
      "recordPolicial",
      "recordPolicialPath",
      "record_url",
      "recordUrl",
      "record_policial_url",
    ];

    for (final k in keys) {
      final v = data[k];
      final s = (v ?? "").toString().trim();
      if (s.isNotEmpty) return s;
    }

    return null;
  }

  // ============================================================
  // 🔹 OBTENER MI PERFIL
  // ============================================================
  Future<void> fetchPerfil() async {
    loading = true;
    notifyListeners();

    final token = await _getToken();
    if (token == null) {
      perfil = null;
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(baseUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        // Tu backend puede devolver:
        // { perfil: {...} }  o  {...}
        final Map<String, dynamic> data =
            (body is Map && body["perfil"] is Map)
                ? Map<String, dynamic>.from(body["perfil"])
                : (body is Map)
                    ? Map<String, dynamic>.from(body)
                    : <String, dynamic>{};

        final recordUrl = _extractRecordUrl(data);

        perfil = {
          "telefono": (data["telefono"] ?? "").toString(),
          "categoria": (data["categoria"] ?? "").toString(),
          "direccion": (data["direccion"] ?? "").toString(),
          "experiencia": data["experiencia"] ?? 0,
          "habilidades": (data["habilidades"] is List) ? data["habilidades"] : [],
          // ✅ CLAVE: guardamos el récord aquí
          "recordPolicialUrl": recordUrl,
          // opcional por si luego quieres:
          "fotoUrl": data["fotoUrl"],
        };
      } else {
        perfil = null;
      }
    } catch (e) {
      print("❌ ERROR FETCH PERFIL: $e");
      perfil = null;
    }

    loading = false;
    notifyListeners();
  }

  // ============================================================
  // 🔹 GUARDAR PERFIL (JSON)
  // ============================================================
  Future<bool> savePerfil({
    required String telefono,
    required String categoria,
    required String direccion,
    required int experiencia,
    required List<String> habilidades,
  }) async {
    loading = true;
    notifyListeners();

    final token = await _getToken();
    if (token == null) {
      loading = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await http.put(
        Uri.parse(baseUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "telefono": telefono,
          "categoria": categoria,
          "direccion": direccion,
          "experiencia": experiencia,
          "habilidades": habilidades,
        }),
      );

      if (res.statusCode == 200) {
        await fetchPerfil();
        return true;
      }
    } catch (e) {
      print("❌ ERROR SAVE PERFIL: $e");
    }

    loading = false;
    notifyListeners();
    return false;
  }

  // ============================================================
  // 🔹 SUBIR FOTO
  // ============================================================
  Future<bool> uploadFoto(File file) async {
    final token = await _getToken();
    if (token == null) return false;

    final url = Uri.parse("$baseUrl/upload-foto");
    final request = http.MultipartRequest("POST", url);
    request.headers["Authorization"] = "Bearer $token";

    request.files.add(await http.MultipartFile.fromPath("foto", file.path));

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        await fetchPerfil();
        return true;
      }
      return false;
    } catch (e) {
      print("❌ ERROR UPLOAD FOTO: $e");
      return false;
    }
  }
}
