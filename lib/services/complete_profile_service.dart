import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CompleteProfileService {
  static const String _apiBase = 'http://10.0.2.2:4000/api';
  static Uri _endpoint() => Uri.parse('$_apiBase/perfil-laboral');

  static MediaType _mediaTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('application', 'octet-stream');
  }

  static Future<void> submit(
    Map<String, dynamic> data,
    PlatformFile? file,
    String token,
  ) async {
    // ✅ CON ARCHIVO => MULTIPART
    if (file != null) {
      final req = http.MultipartRequest('POST', _endpoint());
      req.headers['Authorization'] = 'Bearer $token';

      data.forEach((k, v) {
        if (v == null) return;
        req.fields[k] = v.toString();
      });

      // 🔥 MUY IMPORTANTE: que coincida con multer.single('recordPolicial')
      const fieldName = 'recordPolicial';

      final ct = _mediaTypeFromFilename(file.name);

      if (file.path != null) {
        req.files.add(await http.MultipartFile.fromPath(
          fieldName,
          file.path!,
          filename: file.name,
          contentType: ct, // ✅ aquí
        ));
      } else if (file.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes(
          fieldName,
          file.bytes!,
          filename: file.name,
          contentType: ct, // ✅ aquí
        ));
      } else {
        throw Exception('No se pudo leer el archivo (path y bytes null).');
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(resp.body);
      }
      return;
    }

    // ✅ SIN ARCHIVO => JSON
    final resp = await http.post(
      _endpoint(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(resp.body);
    }
  }
}
