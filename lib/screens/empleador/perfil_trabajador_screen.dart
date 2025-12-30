import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart'; // ✅ NUEVO
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/trabajador_model.dart';

class PerfilTrabajadorScreen extends StatefulWidget {
  final TrabajadorModel trabajador;

  const PerfilTrabajadorScreen({super.key, required this.trabajador});

  @override
  State<PerfilTrabajadorScreen> createState() => _PerfilTrabajadorScreenState();
}

class _PerfilTrabajadorScreenState extends State<PerfilTrabajadorScreen> {
  // ✅ PON EL MISMO PUERTO QUE TU BACKEND REAL
  // (tú vienes consumiendo API en 4000 en otros servicios)
  static const String _baseUrl = 'http://10.0.2.2:4000';

  bool _downloading = false;
  double _progress = 0.0;
  bool _hasTotal = false;
  String? _savedPath;

  // ✅ Si llega URL absoluta con puerto raro, forzamos a /uploads con nuestro _baseUrl
  String _buildFileUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    if (s.startsWith('http://') || s.startsWith('https://')) {
      try {
        final uri = Uri.parse(s);
        if (uri.path.startsWith('/uploads/')) {
          return '$_baseUrl${uri.path}';
        }
        return s;
      } catch (_) {
        // cae al fallback
      }
    }

    if (s.startsWith('/')) return '$_baseUrl$s';
    return '$_baseUrl/$s';
  }

  Future<Directory> _getPreferredDir() async {
    // ✅ En Android 11+ la carpeta de Downloads puede fallar por permisos.
    // Guardamos en carpeta externa de la APP (siempre funciona).
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _downloadRecord() async {
    final recordPath = widget.trabajador.recordPolicialUrl;
    final url = _buildFileUrl(recordPath);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este trabajador no tiene récord policial')),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _hasTotal = false;
      _savedPath = null;
    });

    try {
      final uri = Uri.parse(url);

      String filename = p.basename(uri.path);
      if (filename.trim().isEmpty) {
        filename = 'record_policial_${widget.trabajador.userId}.pdf';
      }

      final dir = await _getPreferredDir();
      var savePath = p.join(dir.path, filename);

      if (await File(savePath).exists()) {
        final nameNoExt = p.basenameWithoutExtension(filename);
        final ext = p.extension(filename);
        savePath = p.join(
          dir.path,
          '${nameNoExt}_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
      );

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() {
              _hasTotal = true;
              _progress = received / total;
            });
          } else {
            setState(() {
              _hasTotal = false;
              _progress = 0.0;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _savedPath = savePath;
        _downloading = false;
        _progress = 1.0;
        _hasTotal = true;
      });

      // ✅ NUEVO: ABRIR AUTOMÁTICAMENTE
      final result = await OpenFilex.open(savePath);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se descargó, pero no se pudo abrir: ${result.message}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Récord descargado y abierto.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = 0.0;
        _hasTotal = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error descargando: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nombre = widget.trabajador.nombre.trim();
    final email = widget.trabajador.email.trim();
    final categoria = widget.trabajador.categoria.trim();
    final descripcion = widget.trabajador.descripcion.trim();
    final exp = widget.trabajador.experiencia;

    final tieneRecord = widget.trabajador.recordPolicialUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del trabajador'),
      ),

      // ✅ ListView = ADIÓS franjas amarillas (overflow)
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // CABECERA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(0.05),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : "T",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.isNotEmpty ? nombre : "Sin nombre",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email.isNotEmpty ? email : "Sin email",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: "Copiar",
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: email),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Email copiado al portapapeles"),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            icon: Icons.work_outline,
                            label: categoria.isNotEmpty ? categoria : "Sin categoría",
                          ),
                          _Pill(
                            icon: Icons.timeline,
                            label: "Experiencia: $exp años",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "Resumen",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            child: Text(
              descripcion.isNotEmpty ? descripcion : "Sin descripción",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "Información laboral",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.category_outlined,
                  title: "Categoría",
                  value: categoria.isNotEmpty ? categoria : "Sin categoría",
                ),
                const Divider(height: 18),
                _InfoRow(
                  icon: Icons.military_tech_outlined,
                  title: "Experiencia",
                  value: "$exp años",
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "Contacto",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            child: _InfoRow(
              icon: Icons.email_outlined,
              title: "Email",
              value: email.isNotEmpty ? email : "Sin email",
              hideDivider: true,
            ),
          ),

          const SizedBox(height: 14),

          // ✅ RÉCORD POLICIAL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tieneRecord
                            ? "Récord policial: Disponible"
                            : "Récord policial: No disponible",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (tieneRecord)
                      TextButton.icon(
                        onPressed: _downloading ? null : _downloadRecord,
                        icon: const Icon(Icons.download),
                        label: const Text("Descargar"),
                      ),
                  ],
                ),
                if (_downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _hasTotal ? _progress : null),
                  const SizedBox(height: 6),
                  Text(
                    _hasTotal
                        ? "Descargando... ${(100 * _progress).toStringAsFixed(0)}%"
                        : "Descargando...",
                  ),
                ],
                if (_savedPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Guardado en:\n$_savedPath",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Aviso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.outline),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Revisa la información del perfil antes de contratar."),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // BOTONES
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar email'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: email));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copiado al portapapeles')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copiar todo'),
                  onPressed: () async {
                    final text = [
                      "Nombre: ${nombre.isNotEmpty ? nombre : 'Sin nombre'}",
                      "Email: ${email.isNotEmpty ? email : 'Sin email'}",
                      "Categoría: ${categoria.isNotEmpty ? categoria : 'Sin categoría'}",
                      "Experiencia: $exp años",
                      "Descripción: ${descripcion.isNotEmpty ? descripcion : 'Sin descripción'}",
                      "Récord: ${tieneRecord ? 'Disponible' : 'No disponible'}",
                      if (_savedPath != null) "Archivo: $_savedPath",
                    ].join("\n");

                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Información copiada')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool hideDivider;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.hideDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ),
        if (!hideDivider) const SizedBox(height: 10),
      ],
    );
  }
}
