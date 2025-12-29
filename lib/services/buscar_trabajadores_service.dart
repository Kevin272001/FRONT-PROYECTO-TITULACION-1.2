import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/trabajador_model.dart';

class BuscarTrabajadoresService {
  static const String _apiBase = 'http://10.0.2.2:4000';

  /// GET /api/trabajador/buscar?categoria=...&experiencia=...
  static Future<List<TrabajadorModel>> buscarPerfiles({
    String? categoria,
    int? experiencia,
  }) async {
    final uri = Uri.parse('$_apiBase/api/trabajador/buscar').replace(
      queryParameters: {
        if (categoria != null && categoria.trim().isNotEmpty)
          'categoria': categoria.trim(),
        if (experiencia != null) 'experiencia': experiencia.toString(),
      },
    );

    final resp = await http.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);

    // ✅ Soporta varias formas de respuesta
    final List<dynamic> lista = decoded is List
        ? decoded
        : (decoded['trabajadores'] ??
                decoded['data'] ??
                decoded['results'] ??
                decoded['perfiles'] ??
                []) as List<dynamic>;

    return lista
        .where((e) => e is Map)
        .map((e) => TrabajadorModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }
}
