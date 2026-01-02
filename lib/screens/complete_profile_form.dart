import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CompleteProfileForm extends StatefulWidget {
  final bool autoValidate;
  final Map<String, dynamic>? initialData;
  final String token;

  final Future<void> Function(
    Map<String, dynamic> data,
    PlatformFile? recordPolicialFile,
    String token,
  ) onSubmit;

  const CompleteProfileForm({
    super.key,
    required this.token,
    required this.onSubmit,
    this.autoValidate = false,
    this.initialData,
  });

  @override
  State<CompleteProfileForm> createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _nombreComercialController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _horarioController = TextEditingController();
  final _experienciaController = TextEditingController();

  String? _categoria;
  String? _tipoPersona; // NATURAL | JURIDICA
  PlatformFile? _recordPolicialFile;

  bool _loading = false;

  final List<String> _categorias = [
    'Plomería',
    'Electricidad',
    'Limpieza',
    'Mantenimiento',
    'Belleza',
    'Transporte',
    'Tecnología',
    'Servicios Automotrices',
    'Otros'
  ];

  // =====================================================
  // INIT
  // =====================================================
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔹 CASO 1: EDITAR PERFIL
      if (widget.initialData != null) {
        final d = widget.initialData!;
        _nombreController.text = d['nombreCompleto'] ?? '';
        _cedulaController.text = d['cedulaRuc'] ?? '';
        _telefonoController.text = d['telefono'] ?? '';
        _nombreComercialController.text = d['nombreComercial'] ?? '';
        _categoria = d['categoria'];
        _descripcionController.text = d['descripcion'] ?? '';
        _direccionController.text = d['direccion'] ?? '';
        _horarioController.text = d['horario'] ?? '';
        _experienciaController.text =
            d['experiencia']?.toString() ?? '';
        _tipoPersona = d['tipoPersona'];
        setState(() {});
        return;
      }

      // 🔹 CASO 2: REGISTRO / LOGIN
      final auth = context.read<AuthProvider>();

      // ⏳ ESPERAMOS A QUE EL PROVIDER CARGUE BIEN
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      _nombreController.text = auth.userName ?? '';
      _telefonoController.text = auth.telefono ?? '';

      setState(() {});
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _nombreComercialController.dispose();
    _descripcionController.dispose();
    _direccionController.dispose();
    _horarioController.dispose();
    _experienciaController.dispose();
    super.dispose();
  }

  // =====================================================
  // FILE PICKER
  // =====================================================
  Future<void> _pickRecordPolicial() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _recordPolicialFile = result.files.first;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando archivo: $e')),
      );
    }
  }

  void _removeRecordPolicial() {
    setState(() => _recordPolicialFile = null);
  }

  // =====================================================
  // SUBMIT
  // =====================================================
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos obligatorios')),
      );
      return;
    }

    setState(() => _loading = true);

    final payload = <String, dynamic>{
      'nombreCompleto': _nombreController.text.trim(),
      'cedulaRuc': _cedulaController.text.trim().isEmpty
          ? null
          : _cedulaController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'nombreComercial': _nombreComercialController.text.trim(),
      'categoria': _categoria ?? 'Otros',
      'descripcion': _descripcionController.text.trim(),
      'direccion': _direccionController.text.trim(),
      'horario': _horarioController.text.trim(),
      'experiencia':
          int.tryParse(_experienciaController.text.trim()) ?? 0,
      'tipoPersona': _tipoPersona ?? 'NATURAL',
    };

    try {
      await widget.onSubmit(
        payload,
        _recordPolicialFile,
        widget.token,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =====================================================
  // UI
  // =====================================================
  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        autovalidateMode: widget.autoValidate
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            const Text(
              'Completa tu perfil laboral',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _tipoPersona,
              items: const [
                DropdownMenuItem(
                  value: 'NATURAL',
                  child: Text('Persona Natural'),
                ),
                DropdownMenuItem(
                  value: 'JURIDICA',
                  child: Text('Persona Jurídica'),
                ),
              ],
              decoration: _inputDecoration(
                label: 'Tipo de persona',
                icon: Icons.person_outline,
              ),
              onChanged: (v) => setState(() => _tipoPersona = v),
              validator: (v) =>
                  v == null ? 'Seleccione el tipo de persona' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nombreController,
              decoration: _inputDecoration(
                label: 'Nombre completo',
                icon: Icons.person,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _cedulaController,
              decoration: _inputDecoration(
                label: 'Cédula o RUC',
                icon: Icons.badge,
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _telefonoController,
              decoration: _inputDecoration(
                label: 'Teléfono',
                icon: Icons.phone,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nombreComercialController,
              decoration: _inputDecoration(
                label: 'Nombre comercial',
                icon: Icons.business,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _categoria,
              items: _categorias
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              decoration: _inputDecoration(
                label: 'Categoría',
                icon: Icons.category,
              ),
              onChanged: (v) => setState(() => _categoria = v),
              validator: (v) =>
                  v == null ? 'Seleccione una categoría' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _descripcionController,
              decoration: _inputDecoration(
                label: 'Descripción del servicio',
                icon: Icons.description,
              ),
              maxLines: 3,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _direccionController,
              decoration: _inputDecoration(
                label: 'Dirección o zona',
                icon: Icons.location_on,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _horarioController,
              decoration: _inputDecoration(
                label: 'Horario de atención',
                icon: Icons.access_time,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _experienciaController,
              decoration: _inputDecoration(
                label: 'Años de experiencia',
                icon: Icons.timeline,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                child: Text(
                  _loading ? 'Guardando...' : 'Guardar y continuar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
