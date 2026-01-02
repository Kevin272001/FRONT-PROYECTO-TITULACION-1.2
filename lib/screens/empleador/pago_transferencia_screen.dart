import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/transactions_provider.dart';

// 🔴 IMPORTA EL HOME REAL
import '../empleador/home_empleador_screen.dart';

const String baseUrl = "http://10.0.2.2:4000/api";

class PagoTransferenciaScreen extends StatefulWidget {
  final int trabajadorId;
  final int? trabajoId;
  final int? servicioId;
  final double? montoSugerido;

  const PagoTransferenciaScreen({
    super.key,
    required this.trabajadorId,
    this.trabajoId,
    this.servicioId,
    this.montoSugerido,
  });

  @override
  State<PagoTransferenciaScreen> createState() =>
      _PagoTransferenciaScreenState();
}

class _PagoTransferenciaScreenState extends State<PagoTransferenciaScreen> {
  Map<String, dynamic>? cuenta;
  bool loading = true;
  bool pagando = false;
  PlatformFile? comprobanteFile;

  final montoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    montoCtrl.text =
        (widget.montoSugerido ?? 0).toStringAsFixed(2);
    _cargarCuenta();
  }

  @override
  void dispose() {
    montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCuenta() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    try {
      final resp = await http.get(
        Uri.parse("$baseUrl/perfil/public/${widget.trabajadorId}"),
        headers: {
          "Authorization": "Bearer ${auth.token}",
          "Content-Type": "application/json",
        },
      );

      if (resp.statusCode == 200) {
        cuenta = jsonDecode(resp.body);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _pickComprobante() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => comprobanteFile = res.files.first);
  }

  // =====================================================
  // 🔐 CONFIRMACIÓN DE PAGO (SEGURIDAD)
  // =====================================================
  Future<void> _mostrarConfirmacionPago() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar pago"),
        content: const Text(
          "¿Estás seguro de realizar el pago?\nEsta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("NO"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text(
              "SÍ, PAGAR",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      _confirmarPago();
    }
  }

  // =====================================================
  // 💰 REGISTRAR PAGO
  // =====================================================
  Future<void> _confirmarPago() async {
    final auth = context.read<AuthProvider>();
    final transProv = context.read<TransactionsProvider>();

    final m = double.tryParse(montoCtrl.text);
    if (m == null || m <= 0) {
      _snack("Ingresa un monto válido", Colors.red);
      return;
    }

    if (auth.token == null || auth.userId == null) {
      _snack("Sesión no válida", Colors.red);
      return;
    }

    setState(() => pagando = true);

    final ok = await transProv.confirmarPago(
      token: auth.token!,
      empleadorId: auth.userId!,
      trabajadorId: widget.trabajadorId,
      trabajoId: widget.trabajoId,
      servicioId: widget.servicioId,
      monto: m,
      descripcion: "Pago registrado por transferencia",
      comprobante: comprobanteFile,
    );

    if (!mounted) return;
    setState(() => pagando = false);

    if (ok) {
      _snack("✅ Pago realizado con éxito", Colors.green);

      await Future.delayed(const Duration(milliseconds: 800));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeEmpleadorScreen(),
        ),
        (route) => false,
      );
    } else {
      _snack("❌ No se pudo registrar el pago", Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // =====================================================
  // 🧱 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final qrUrl = cuenta?["qrCuentaUrl"];
    final fullQr = (qrUrl is String && qrUrl.isNotEmpty)
        ? "http://10.0.2.2:4000$qrUrl"
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pagar por transferencia"),
        backgroundColor: Colors.deepPurple,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text(
                    "Datos del trabajador",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  _info("Banco", cuenta?["banco"]),
                  _info("Tipo de cuenta", cuenta?["tipoCuenta"]),
                  _info("Número de cuenta", cuenta?["numeroCuenta"]),
                  _info("Titular", cuenta?["titularCuenta"]),
                  _info("Cédula", cuenta?["cedulaTitular"]),

                  if (fullQr != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _verImagenDialog(
                        titulo: "QR de la cuenta",
                        url: fullQr,
                      ),
                      icon: const Icon(Icons.qr_code),
                      label: const Text("Ver QR"),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text("Monto",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed:
                        pagando ? null : _mostrarConfirmacionPago,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      pagando
                          ? "Procesando..."
                          : "Confirmar pago",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _info(String label, dynamic value) {
    final txt = (value == null ||
            (value is String && value.trim().isEmpty))
        ? "(no configurado)"
        : value.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text("$label:")),
          Expanded(
            child: Text(
              txt,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _verImagenDialog({required String titulo, required String url}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Image.network(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
