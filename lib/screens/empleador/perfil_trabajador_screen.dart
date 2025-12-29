import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/trabajador_model.dart';

class PerfilTrabajadorScreen extends StatelessWidget {
  final TrabajadorModel trabajador;

  const PerfilTrabajadorScreen({super.key, required this.trabajador});

  // =========================
  // Helpers
  // =========================
  String _safe(String? v, {String fallback = ""}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    return s.contains("@") && s.contains(".") && !s.toLowerCase().contains("sin email");
  }

  Color _colorFromString(String s) {
    final hash = s.codeUnits.fold<int>(0, (p, c) => p + c);
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.45, 0.85).toColor();
  }

  Future<void> _copy(BuildContext context, String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nombre = _safe(trabajador.nombre, fallback: "Sin nombre");
    final email = _safe(trabajador.email, fallback: "Sin email");
    final categoria = _safe(trabajador.categoria, fallback: "Sin categoría");
    final descripcion = _safe(
      trabajador.descripcion,
      fallback: "Este trabajador aún no ha agregado una descripción.",
    );
    final exp = trabajador.experiencia;

    final baseColor = _colorFromString("$categoria|$nombre");
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "T";
    final canCopyEmail = _isValidEmail(email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del trabajador'),
        centerTitle: true,
      ),

      // ✅ Botones abajo (se ven mejor y llenan espacio)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canCopyEmail
                      ? () => _copy(context, email, "Email copiado ✅")
                      : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text("Copiar email"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copy(
                    context,
                    "Nombre: $nombre\nEmail: $email\nCategoría: $categoria\nExperiencia: $exp años\nDescripción: $descripcion",
                    "Perfil copiado ✅",
                  ),
                  icon: const Icon(Icons.person_pin_rounded),
                  label: const Text("Copiar todo"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER bonito (avatar + nombre + email + chips)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withOpacity(0.18),
                    theme.colorScheme.surface,
                  ],
                ),
                border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withOpacity(0.20),
                      border: Border.all(
                        color: baseColor.withOpacity(0.70),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: baseColor.withOpacity(0.95),
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
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(Icons.mail_outline_rounded,
                                size: 16, color: theme.colorScheme.outline),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (canCopyEmail)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: () => _copy(context, email, "Email copiado ✅"),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(icon: Icons.work_outline, label: categoria),
                            _Chip(icon: Icons.timeline, label: "Experiencia: $exp años"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ✅ Resumen
            const _SectionTitle(title: "Resumen"),
            const SizedBox(height: 8),
            _CardBox(
              child: Text(
                descripcion,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: theme.colorScheme.onSurface.withOpacity(0.82),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ✅ Información laboral
            const _SectionTitle(title: "Información laboral"),
            const SizedBox(height: 8),
            _CardBox(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.category_outlined,
                    title: "Categoría",
                    value: categoria,
                  ),
                  const Divider(height: 18),
                  _InfoRow(
                    icon: Icons.emoji_events_outlined,
                    title: "Experiencia",
                    value: "$exp años",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ✅ Contacto
            const _SectionTitle(title: "Contacto"),
            const SizedBox(height: 8),
            _CardBox(
              child: _InfoRow(
                icon: Icons.email_outlined,
                title: "Email",
                value: email,
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Tip / aviso (rellena visualmente y se ve pro)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: theme.colorScheme.outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Revisa la información del perfil antes de contratar.",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// Widgets de UI
// =========================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  final Widget child;
  const _CardBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 7),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
