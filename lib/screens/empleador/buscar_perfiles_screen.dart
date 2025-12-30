import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ NUEVO
import '../../services/buscar_trabajadores_service.dart';
import '../../models/trabajador_model.dart';
import 'perfil_trabajador_screen.dart';

class BuscarPerfilesScreen extends StatefulWidget {
  const BuscarPerfilesScreen({super.key});

  @override
  State<BuscarPerfilesScreen> createState() => _BuscarPerfilesScreenState();
}

class _BuscarPerfilesScreenState extends State<BuscarPerfilesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = "";

  // ✅ BACKEND URL (Emulador Android)
  // Si es celular físico: cambia a la IP de tu PC, ej: http://192.168.1.50:3000
  static const String _baseUrl = 'http://10.0.2.2:3000';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _safeStr(String? v, {String fallback = ""}) {
    final s = (v ?? "").trim();
    return s.isEmpty ? fallback : s;
  }

  Color _colorFromString(String s) {
    // ✅ color estable por categoría/nombre
    final hash = s.codeUnits.fold<int>(0, (p, c) => p + c);
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.45, 0.85).toColor();
  }

  // ✅ NUEVO: construir URL absoluta del archivo
  String _buildFileUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$_baseUrl$path'; // /uploads/... => http://10.0.2.2:3000/uploads/...
  }

  // ✅ NUEVO: abrir PDF/imagen
  Future<void> _openRecord(String recordPath) async {
    final url = _buildFileUrl(recordPath);
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el récord policial')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar perfiles'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<TrabajadorModel>>(
        future: BuscarTrabajadoresService.buscarPerfiles(),
        builder: (context, snapshot) {
          // ⏳ Cargando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ Error
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 46, color: theme.colorScheme.error),
                    const SizedBox(height: 10),
                    const Text(
                      'Error al cargar perfiles',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }

          final all = snapshot.data ?? [];

          if (all.isEmpty) {
            return const Center(child: Text('No hay trabajadores registrados'));
          }

          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((t) {
                  final nombre = (t.nombre).toLowerCase();
                  final categoria = (t.categoria).toLowerCase();
                  return nombre.contains(q) || categoria.contains(q);
                }).toList();

          return Column(
            children: [
              // 🔎 Buscador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.35)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o categoría…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = "");
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Resultados
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = filtered[index];

                    final nombre = _safeStr(t.nombre, fallback: "Sin nombre");
                    final categoria =
                        _safeStr(t.categoria, fallback: "Sin categoría");
                    final desc = _safeStr(
                      t.descripcion,
                      fallback: "Disponible para trabajos en tu zona.",
                    );

                    final baseColor = _colorFromString("$categoria|$nombre");
                    final initial =
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : "T";

                    final tieneRecord = t.recordPolicialUrl.isNotEmpty;

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PerfilTrabajadorScreen(trabajador: t),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              baseColor.withOpacity(0.16),
                              theme.colorScheme.surface,
                            ],
                          ),
                          border: Border.all(
                              color: theme.dividerColor.withOpacity(0.35)),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: baseColor.withOpacity(0.20),
                                border: Border.all(
                                    color: baseColor.withOpacity(0.65),
                                    width: 1.2),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: baseColor.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Contenido
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nombre + flecha
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 24,
                                        color: theme.colorScheme.outline
                                            .withOpacity(0.75),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // Chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _Chip(
                                        icon: Icons.work_outline,
                                        label: categoria,
                                      ),
                                      _Chip(
                                        icon: Icons.timeline,
                                        label: "Exp: ${t.experiencia} años",
                                      ),
                                      _Chip(
                                        icon: Icons.security,
                                        label: tieneRecord
                                            ? "Récord: Sí"
                                            : "Récord: No",
                                      ),
                                    ],
                                  ),

                                  // ✅ NUEVO: botón para abrir PDF/imagen
                                  if (tieneRecord) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _openRecord(t.recordPolicialUrl),
                                        icon: const Icon(Icons.picture_as_pdf),
                                        label: const Text('Ver récord'),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  // Descripción
                                  Text(
                                    desc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.72),
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

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
