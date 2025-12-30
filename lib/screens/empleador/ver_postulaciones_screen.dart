import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'progreso_trabajo_screen.dart';
import 'ver_perfil_trabajador_screen.dart';

// EMULADOR → 10.0.2.2
const String baseUrl = "http://10.0.2.2:4000";

class VerPostulacionesScreen extends StatefulWidget {
  final int trabajoId;
  final String tituloTrabajo;

  const VerPostulacionesScreen({
    super.key,
    required this.trabajoId,
    required this.tituloTrabajo,
  });

  @override
  State<VerPostulacionesScreen> createState() => _VerPostulacionesScreenState();
}

class _VerPostulacionesScreenState extends State<VerPostulacionesScreen> {
  bool loading = true;
  List postulaciones = [];

  static const _brand = Color(0xff6A4CE8);

  // ============================
  // CARGAR POSTULACIONES
  // ============================
  Future<void> cargarPostulaciones({bool mostrarLoader = false}) async {
    if (!mounted) return;

    if (mostrarLoader) setState(() => loading = true);

    try {
      final url = Uri.parse("$baseUrl/api/postulaciones/trabajo/${widget.trabajoId}");
      final resp = await http.get(url);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          postulaciones = data["postulaciones"] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          postulaciones = [];
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        postulaciones = [];
        loading = false;
      });
    }
  }

  // =====================================================
  // ✅ VER DETALLES → ABRE VerPerfilTrabajadorScreen
  // =====================================================
  void _irAVerDetalles(Map postulante) {
    final trabajadorId = postulante["userId"]; // ✅ userId del trabajador

    if (trabajadorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró userId del postulante")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerPerfilTrabajadorScreen(
          trabajadorId: trabajadorId,
          nombreInicial: (postulante["nombre"] ?? "Trabajador").toString(),
          telefonoInicial: (postulante["telefono"] ??
                  postulante["celular"] ??
                  postulante["phone"] ??
                  "")
              .toString(),
        ),
      ),
    );
  }

  // =====================================================
  // ✅ ACEPTAR Y ENTRAR A PROGRESO (USER ID)
  // =====================================================
  Future<void> aceptarYIrAProgreso(Map p) async {
    try {
      final url = Uri.parse("$baseUrl/api/postulaciones/${p["id"]}/estado");

      final resp = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"estado": "aceptado"}),
      );

      if (resp.statusCode == 200) {
        final postulante = p["postulante"] ?? {};
        final trabajadorId = postulante["userId"];

        if (trabajadorId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se encontró userId del postulante")),
          );
          return;
        }

        await cargarPostulaciones();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgresoTrabajoScreen(
              trabajoId: widget.trabajoId,
              trabajadorId: trabajadorId,
              tituloTrabajo: widget.tituloTrabajo,
              nombreTrabajador: postulante["nombre"] ?? "Trabajador",
              rol: "EMPLEADOR",
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo aceptar (${resp.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error aceptando postulación")),
      );
    }
  }

  // ============================
  // RECHAZAR POSTULACIÓN
  // ============================
  Future<void> cambiarEstado(int id, String estado) async {
    try {
      final url = Uri.parse("$baseUrl/api/postulaciones/$id/estado");

      await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"estado": estado}),
      );

      await cargarPostulaciones();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error cambiando estado")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    cargarPostulaciones(mostrarLoader: true);
  }

  // =====================================================
  // 🎨 CHIP DE ESTADO (bonito)
  // =====================================================
  Widget _estadoChip(String estado) {
    final String e = estado.toLowerCase();

    final Color bg = e == "aceptado"
        ? const Color(0xFF16A34A)
        : e == "rechazado"
            ? const Color(0xFFDC2626)
            : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // =====================================================
  // ✅ BOTÓN PILL (para “Ver detalles”, “Ver progreso”)
  // =====================================================
  Widget _pillAction({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = _brand,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // 📊 TARJETA DE ESTADÍSTICA
  // ============================
  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = postulaciones.length;
    final aceptadas = postulaciones.where((p) => p["estado"] == "aceptado").length;
    final rechazadas = postulaciones.where((p) => p["estado"] == "rechazado").length;

    return Scaffold(
      backgroundColor: const Color(0xffF3F0FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        centerTitle: true,
        title: const Text(
          "Postulaciones",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ================= CABECERA =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tituloTrabajo,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Gestiona las postulaciones recibidas",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 22 * 2 - 10) / 2,
                            child: _statCard("Postulaciones", total.toString(), Icons.group, Colors.blue),
                          ),
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 22 * 2 - 10) / 2,
                            child: _statCard("Aceptadas", aceptadas.toString(), Icons.check_circle, Colors.green),
                          ),
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 22 * 2 - 10) / 2,
                            child: _statCard("Rechazadas", rechazadas.toString(), Icons.cancel, Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ================= LISTA =================
                Expanded(
                  child: postulaciones.isEmpty
                      ? const Center(child: Text("Aún no hay postulaciones"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: postulaciones.length,
                          itemBuilder: (_, i) {
                            final p = postulaciones[i];
                            final postulante = p["postulante"] ?? {};

                            final nombre = (postulante["nombre"] ?? "Sin nombre").toString();
                            final email = (postulante["email"] ?? "Sin email").toString();

                            final msgRaw = (p["mensaje"] ?? "").toString().trim();
                            final mensaje = msgRaw.isEmpty ? "Sin mensaje" : msgRaw;

                            final estado = (p["estado"] ?? "pendiente").toString();

                            final trabajadorId = postulante["userId"];
                            final inicial = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : "?";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.deepPurple.shade100,
                                        child: Text(
                                          inicial,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
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
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _estadoChip(estado),
                                    ],
                                  ),

                                  const SizedBox(height: 14),
                                  Text(mensaje, style: const TextStyle(fontSize: 14)),

                                  const SizedBox(height: 14),

                                  // ✅ ACCIONES (YA NO SE VE FEO)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // VER DETALLES (pill pro)
                                      _pillAction(
                                        icon: Icons.visibility,
                                        text: "Ver Perfil",
                                        onTap: () => _irAVerDetalles(postulante),
                                      ),

                                      const SizedBox(height: 12),

                                      if (estado == "pendiente") ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 42,
                                                child: ElevatedButton(
                                                  onPressed: () => aceptarYIrAProgreso(p),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF16A34A),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "Aceptar",
                                                    style: TextStyle(fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: SizedBox(
                                                height: 42,
                                                child: OutlinedButton(
                                                  onPressed: () => cambiarEstado(p["id"], "rechazado"),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF6B7280),
                                                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "Rechazar",
                                                    style: TextStyle(fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      if (estado == "aceptado") ...[
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: _pillAction(
                                            icon: Icons.timeline,
                                            text: "Ver progreso",
                                            onTap: () {
                                              if (trabajadorId == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text("No se encontró userId del postulante"),
                                                  ),
                                                );
                                                return;
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ProgresoTrabajoScreen(
                                                    trabajoId: widget.trabajoId,
                                                    trabajadorId: trabajadorId,
                                                    tituloTrabajo: widget.tituloTrabajo,
                                                    nombreTrabajador: nombre,
                                                    rol: "EMPLEADOR",
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
