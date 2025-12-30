import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';

class VerPerfilTrabajadorScreen extends StatefulWidget {
  final int trabajadorId; // ✅ aquí es userId del trabajador
  final String? nombreInicial;
  final String? telefonoInicial;

  const VerPerfilTrabajadorScreen({
    super.key,
    required this.trabajadorId,
    this.nombreInicial,
    this.telefonoInicial,
  });

  @override
  State<VerPerfilTrabajadorScreen> createState() => _VerPerfilTrabajadorScreenState();
}

class _VerPerfilTrabajadorScreenState extends State<VerPerfilTrabajadorScreen> {
  static const _apiBase = "http://10.0.2.2:4000";

  bool loading = true;
  String? error;

  bool abriendoPdf = false;
  bool abriendoRecord = false;

  Map<String, dynamic>? perfil;

  // ===============================
  // helpers
  // ===============================
  String _s(dynamic v, {String fallback = ""}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _pick(Map<String, dynamic> m, List<String> keys, {String fallback = ""}) {
    for (final k in keys) {
      final v = _s(m[k]);
      if (v.isNotEmpty) return v;
    }
    return fallback;
  }

  /// ✅ parsea experiencia aunque venga "3 años", "3", 3, 3.0
  int? _yearsNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();

    final str = v.toString().trim();
    if (str.isEmpty) return null;

    final m = RegExp(r'(\d+)').firstMatch(str);
    if (m != null) return int.tryParse(m.group(1) ?? '');
    return null;
  }

  /// ✅ busca experiencia en varias keys sin “dañar”
  int _pickYears(Map<String, dynamic> m, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final parsed = _yearsNullable(m[k]);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _fullUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://") || u.startsWith("https://")) return u;
    // si viene "/uploads/..." => _apiBase + "/uploads/..."
    if (u.startsWith("/")) return "$_apiBase$u";
    return "$_apiBase/$u";
  }

  bool _isPdf(String url) => url.toLowerCase().endsWith(".pdf");
  bool _isImage(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".jpg") || u.endsWith(".jpeg") || u.endsWith(".png");
  }

  // ==========================================================
  // ✅ SACAR URL DEL RÉCORD desde el perfil
  // ==========================================================
  String? _extractRecordUrl(Map<String, dynamic>? p) {
    if (p == null) return null;

    const keys = [
      "recordPolicialUrl",
      "recordPolicial",
      "recordUrl",
      "record_policial_url",
      "recordPolicialPath",
      "record_path",
    ];

    for (final k in keys) {
      final v = (p[k] ?? "").toString().trim();
      if (v.isNotEmpty) return v;
    }

    // por si viene anidado
    final nested = p["perfilLaboral"];
    if (nested is Map) {
      final nn = Map<String, dynamic>.from(nested);
      for (final k in keys) {
        final v = (nn[k] ?? "").toString().trim();
        if (v.isNotEmpty) return v;
      }
    }

    return null;
  }

  Future<Uint8List> _downloadBytes(String url, {String? token}) async {
    final resp = await http.get(
      Uri.parse(url),
      headers: {
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) throw Exception("El archivo está vacío.");
      return resp.bodyBytes;
    }
    throw Exception("No se pudo descargar (HTTP ${resp.statusCode})");
  }

  Future<void> _verRecord(String url, {String? token}) async {
    if (abriendoRecord) return;
    setState(() => abriendoRecord = true);

    try {
      if (_isPdf(url)) {
        final bytes = await _downloadBytes(url, token: token);
        if (!mounted) return;
        await Printing.layoutPdf(onLayout: (_) async => bytes);
        return;
      }

      if (_isImage(url)) {
        final bytes = await _downloadBytes(url, token: token);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
        return;
      }

      throw Exception("Tipo de archivo no soportado.");
    } finally {
      if (mounted) setState(() => abriendoRecord = false);
    }
  }

  Future<void> _descargarRecordComoPdf(String url, {String? token}) async {
    if (abriendoRecord) return;
    setState(() => abriendoRecord = true);

    try {
      final bytes = await _downloadBytes(url, token: token);

      // si ya es PDF => share directo
      if (_isPdf(url)) {
        await Printing.sharePdf(bytes: bytes, filename: "record_policial.pdf");
        return;
      }

      // si es imagen => convertir a PDF
      if (_isImage(url)) {
        final doc = pw.Document();
        final img = pw.MemoryImage(bytes);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Image(img, fit: pw.BoxFit.contain),
            ),
          ),
        );

        await Printing.sharePdf(bytes: await doc.save(), filename: "record_policial.pdf");
        return;
      }

      throw Exception("Tipo no soportado para descargar.");
    } finally {
      if (mounted) setState(() => abriendoRecord = false);
    }
  }

  // ===============================
  // lifecycle
  // ===============================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null) {
      setState(() {
        loading = false;
        error = "No hay token. Inicia sesión.";
      });
      return;
    }

    if (widget.trabajadorId <= 0) {
      setState(() {
        loading = false;
        error = "ID de trabajador inválido.";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final path = "/api/trabajador/publico/${widget.trabajadorId}";

      final resp = await http.get(
        Uri.parse("$_apiBase$path"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (resp.statusCode != 200) {
        setState(() {
          loading = false;
          error = "No se pudo cargar el perfil (HTTP ${resp.statusCode}).";
        });
        return;
      }

      final decoded = jsonDecode(resp.body);

      if (decoded is Map && decoded["perfil"] is Map) {
        setState(() {
          perfil = Map<String, dynamic>.from(decoded["perfil"]);
          loading = false;
        });
        return;
      }

      if (decoded is Map) {
        setState(() {
          perfil = Map<String, dynamic>.from(decoded);
          loading = false;
        });
        return;
      }

      setState(() {
        loading = false;
        error = "Respuesta inválida del servidor.";
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = "Error cargando perfil: $e";
      });
    }
  }

  // ==========================================================
  // ✅ Botón: abre vista previa tipo impresión
  // ==========================================================
  Future<void> _abrirCV() async {
    if (abriendoPdf) return;

    final auth = context.read<AuthProvider>();
    final token = auth.token;

    final p = perfil ?? {};

    final cvUrl = _pick(
      p,
      ["cvUrl", "archivoCv", "cv", "cvPdfUrl", "pdfCv", "urlCv"],
      fallback: "",
    );

    setState(() => abriendoPdf = true);

    try {
      Uint8List bytes;

      if (cvUrl.trim().isNotEmpty) {
        bytes = await _downloadPdfBytes(_fullUrl(cvUrl), token: token);
      } else {
        bytes = await _buildCvPdfBytes(p);
      }

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: "CV_${_s(p["nombre"], fallback: "trabajador")}.pdf",
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No se pudo abrir el CV ❌\n$e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => abriendoPdf = false);
    }
  }

  Future<Uint8List> _downloadPdfBytes(String url, {String? token}) async {
    final uri = Uri.parse(url);

    final resp = await http.get(
      uri,
      headers: {
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (resp.statusCode != 200) {
      throw Exception("HTTP ${resp.statusCode} descargando CV");
    }

    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception("El archivo descargado está vacío.");
    }

    return bytes;
  }

  // ==========================================================
  // ✅ CV PDF PRO (tu misma función, solo corregí experiencia)
  // ==========================================================
  Future<Uint8List> _buildCvPdfBytes(Map<String, dynamic> perfil) async {
    final doc = pw.Document();

    final nombre =
        _s(perfil['nombre'], fallback: _s(widget.nombreInicial, fallback: ''));
    final telefono = _pick(perfil, ["telefono", "celular", "phone"],
        fallback: _s(widget.telefonoInicial, fallback: ''));
    final categoria =
        _pick(perfil, ["categoria", "profesion", "oficio", "category"], fallback: "");
    final direccion = _pick(
      perfil,
      ["direccion", "ubicacion", "direccionCompleta", "location", "address"],
      fallback: "",
    );

    final exp = _pickYears(perfil, [
      "experiencia",
      "aniosExperiencia",
      "anosExperiencia",
      "yearsExperience",
      "years"
    ], fallback: 0);

    final habilidades = (perfil['habilidades'] is List)
        ? List<dynamic>.from(perfil['habilidades'])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final purple = PdfColor.fromInt(0xFF7C3AED);
    final purpleDark = PdfColor.fromInt(0xFF5B21B6);
    final text = PdfColor.fromInt(0xFF111827);
    final muted = PdfColor.fromInt(0xFF6B7280);
    final border = PdfColor.fromInt(0xFFE5E7EB);
    final soft = PdfColor.fromInt(0xFFF3F4F6);

    final white18 = PdfColor.fromInt(0x2EFFFFFF);
    final white85 = PdfColor.fromInt(0xD9FFFFFF);
    final white92 = PdfColor.fromInt(0xEBFFFFFF);
    final white75 = PdfColor.fromInt(0xBFFFFFFF);

    pw.Widget tag(String t) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
        decoration: pw.BoxDecoration(
          color: soft,
          borderRadius: pw.BorderRadius.circular(20),
          border: pw.Border.all(color: border, width: 0.8),
        ),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 10.5, color: text)),
      );
    }

    pw.Widget sectionTitle(String t) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
        child: pw.Row(
          children: [
            pw.Container(
              width: 6,
              height: 14,
              decoration: pw.BoxDecoration(
                color: purple,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              t,
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget infoRow(String k, String v) {
      final vv = v.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 92,
              child: pw.Text(
                k,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  color: muted,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                vv.isEmpty ? "—" : vv,
                style: pw.TextStyle(fontSize: 10.8, color: text),
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(22),
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: border, width: 1),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  width: 170,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: purpleDark,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(18),
                      bottomLeft: pw.Radius.circular(18),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 56,
                        height: 56,
                        decoration: pw.BoxDecoration(
                          color: white18,
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: PdfColors.white, width: 1),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'T',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        nombre.isEmpty ? 'CV Trabajador' : nombre,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        categoria.isEmpty ? 'Trabajador' : categoria,
                        style: pw.TextStyle(color: white85, fontSize: 10.5),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Container(height: 1, color: white18),
                      pw.SizedBox(height: 14),
                      pw.Text(
                        "CONTACTO",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      if (telefono.isNotEmpty)
                        pw.Text("📞  $telefono",
                            style: pw.TextStyle(color: white92, fontSize: 10.5)),
                      if (direccion.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Text("📍  $direccion",
                            style: pw.TextStyle(color: white92, fontSize: 10.5),
                            maxLines: 3),
                      ],
                      pw.Spacer(),
                      pw.Container(height: 1, color: white18),
                      pw.SizedBox(height: 10),
                      pw.Text("Generado: $fecha",
                          style: pw.TextStyle(color: white75, fontSize: 9.5)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                "CURRÍCULUM VITAE",
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: text,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: soft,
                                borderRadius: pw.BorderRadius.circular(20),
                                border: pw.Border.all(color: border, width: 0.8),
                              ),
                              child: pw.Text(
                                "ServX",
                                style: pw.TextStyle(
                                  fontSize: 10.5,
                                  color: PdfColor.fromInt(0xFF5B21B6),
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),
                        sectionTitle("Perfil"),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(14),
                            border: pw.Border.all(color: border, width: 1),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              infoRow("Nombre", nombre),
                              infoRow("Categoría", categoria),
                              infoRow("Experiencia", "$exp años"),
                              infoRow("Ubicación", direccion),
                              infoRow("Teléfono", telefono),
                            ],
                          ),
                        ),
                        sectionTitle("Habilidades"),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(14),
                            border: pw.Border.all(color: border, width: 1),
                          ),
                          child: habilidades.isEmpty
                              ? pw.Text("—", style: pw.TextStyle(color: muted, fontSize: 11))
                              : pw.Wrap(children: habilidades.map(tag).toList()),
                        ),
                        sectionTitle("Resumen"),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: soft,
                            borderRadius: pw.BorderRadius.circular(14),
                            border: pw.Border.all(color: border, width: 1),
                          ),
                          child: pw.Text(
                            "Trabajador registrado en ServX. Perfil generado automáticamente con los datos proporcionados en la aplicación.",
                            style: pw.TextStyle(color: muted, fontSize: 10.8),
                          ),
                        ),
                        pw.Spacer(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Documento generado desde la app",
                                style: pw.TextStyle(color: muted, fontSize: 9.5)),
                            pw.Text("© ServX",
                                style: pw.TextStyle(color: muted, fontSize: 9.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  // ===============================
  // UI helpers
  // ===============================
  BorderRadius get _r16 => BorderRadius.circular(16);

  BoxDecoration _cardBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: _r16,
      boxShadow: const [
        BoxShadow(
          blurRadius: 18,
          spreadRadius: 0,
          offset: Offset(0, 8),
          color: Color(0x14000000),
        ),
      ],
      border: Border.all(color: const Color(0x11000000)),
    );
  }

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _recordInlineUI({
    required Map<String, dynamic> p,
    required String? token,
  }) {
    final raw = _extractRecordUrl(p);
    final full = raw == null ? null : _fullUrl(raw);

    String fileName = "record_policial";
    if (full != null) {
      try {
        final u = Uri.parse(full);
        if (u.pathSegments.isNotEmpty) fileName = u.pathSegments.last;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Récord Policial",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),

        if (full == null) ...[
          const Text(
            "No disponible",
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: abriendoRecord ? null : () async {
                    try {
                      await _verRecord(full, token: token);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("No se pudo abrir: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: abriendoRecord
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility),
                  label: const Text("Ver"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: abriendoRecord ? null : () async {
                    try {
                      await _descargarRecordComoPdf(full, token: token);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("No se pudo descargar: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Descargar"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isPdf(full)
                ? "Tipo: PDF"
                : _isImage(full)
                    ? "Tipo: Imagen"
                    : "Tipo: Desconocido",
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  // ===============================
  // build
  // ===============================
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    final p = perfil ?? {};

    final nombre = _s(
      p["nombre"],
      fallback: _s(widget.nombreInicial, fallback: "Trabajador"),
    );

    final telefono = _pick(
      p,
      ["telefono", "celular", "phone"],
      fallback: _s(widget.telefonoInicial, fallback: "—"),
    );

    final direccionUI = _pick(
      p,
      ["direccion", "ubicacion", "direccionCompleta", "location", "address"],
      fallback: "—",
    );

    final categoria = _pick(
      p,
      ["categoria", "profesion", "oficio", "category"],
      fallback: "—",
    );

    final experiencia = _pickYears(p, [
      "experiencia",
      "aniosExperiencia",
      "anosExperiencia",
      "yearsExperience",
      "years"
    ], fallback: 0);

    final descripcion = _s(p["descripcion"], fallback: "");
    final horario = _s(p["horario"], fallback: "");

    final habilidades = (p["habilidades"] is List)
        ? List<dynamic>.from(p["habilidades"])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final fotoUrl = _pick(p, ["fotoUrl", "fotoPerfil", "foto", "avatarUrl"], fallback: "");

    final cvUrl = _pick(
      p,
      ["cvUrl", "archivoCv", "cv", "cvPdfUrl", "pdfCv", "urlCv"],
      fallback: "",
    );

    final tieneCv = cvUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Perfil del Trabajador",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorState(msg: error!, onRetry: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // ======== CARD ARRIBA (CV) ========
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardBox(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle("Mi Perfil Profesional", icon: Icons.badge_outlined),
                            const SizedBox(height: 6),
                            const Text(
                              "Información del trabajador para contratación",
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _chip(categoria == "—" ? "Trabajador" : categoria),
                                _chip("$experiencia años"),
                                _chip(direccionUI == "—" ? "Sin ubicación" : direccionUI),
                              ],
                            ),
                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: abriendoPdf ? null : _abrirCV,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text(
                                  abriendoPdf
                                      ? "Abriendo..."
                                      : (tieneCv ? "Descargar CV" : "Generar CV"),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tieneCv
                                  ? "CV disponible ✅"
                                  : "Este trabajador no ha subido CV (se generará con sus datos).",
                              style: TextStyle(
                                color: tieneCv ? Colors.green : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ======== CARD NOMBRE/FOTO ========
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardBox(),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: const Color(0xFFF3F4F6),
                              backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(_fullUrl(fotoUrl)) : null,
                              child: fotoUrl.isEmpty
                                  ? Text(
                                      nombre.isNotEmpty ? nombre[0].toUpperCase() : "T",
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    categoria,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ======== INFO ========
                      _InfoCardPro(
                        items: [
                          _InfoItem(icon: Icons.phone, label: "Teléfono", value: telefono),
                          _InfoItem(icon: Icons.location_on_outlined, label: "Ubicación", value: direccionUI),
                          _InfoItem(icon: Icons.work_outline, label: "Experiencia", value: "$experiencia años"),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ======== HABILIDADES ========
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardBox(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle("Habilidades", icon: Icons.auto_awesome),
                            const SizedBox(height: 12),
                            if (habilidades.isEmpty)
                              const Text("—", style: TextStyle(color: Color(0xFF6B7280)))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: habilidades
                                    .map(
                                      (h) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDE9FE),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: const Color(0x227C3AED)),
                                        ),
                                        child: Text(
                                          h,
                                          style: const TextStyle(
                                            color: Color(0xFF5B21B6),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ======== DETALLES (AQUÍ VA EL RÉCORD ABAJO DE HORARIO) ========
                      if (descripcion.isNotEmpty || horario.isNotEmpty || _extractRecordUrl(p) != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardBox(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("Detalles", icon: Icons.info_outline),
                              const SizedBox(height: 12),

                              if (descripcion.isNotEmpty) ...[
                                const Text(
                                  "Descripción",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  descripcion,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (horario.isNotEmpty) ...[
                                const Text(
                                  "Horario",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  horario,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // ✅ AQUÍ VA EL RÉCORD POLICIAL (DEBAJO DE HORARIO)
                              const Divider(height: 24),
                              _recordInlineUI(p: p, token: token),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ===============================
// Widgets reutilizables
// ===============================
class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _ErrorState({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text("Reintentar")),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem({required this.icon, required this.label, required this.value});
}

class _InfoCardPro extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoCardPro({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 8),
            color: Color(0x14000000),
          ),
        ],
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Column(
        children: items
            .map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(it.icon, size: 18, color: const Color(0xFF111827)),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: Text(
                        it.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        it.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
