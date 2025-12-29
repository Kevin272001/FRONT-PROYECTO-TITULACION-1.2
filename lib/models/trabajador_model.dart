class TrabajadorModel {
  final int id;

  // ✅ si luego lo necesitas para ver perfil público, etc.
  final int userId;

  final String nombre;
  final String email;

  final String categoria;
  final String descripcion;

  final int experiencia;

  const TrabajadorModel({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.email,
    required this.categoria,
    required this.descripcion,
    required this.experiencia,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static int _i(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final str = _s(v);
    if (str.isEmpty) return fallback;

    // ✅ si viene tipo "3 años"
    final m = RegExp(r'(\d+)').firstMatch(str);
    if (m != null) return int.tryParse(m.group(1)!) ?? fallback;

    return int.tryParse(str) ?? fallback;
  }

  static String _pickStr(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = _s(v);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  factory TrabajadorModel.fromJson(Map<String, dynamic> json) {
    // ✅ tu backend (según lo pegado) usa `usuario` como alias
    final dynamic u = json['usuario'] ?? json['user'] ?? json['User'] ?? {};
    final dynamic pl = json['perfilLaboral'] ?? json['PerfilLaboral'] ?? {};

    final nombre = _pickStr([
      json['nombre'],                // por si viene plano
      u is Map ? u['nombre'] : null, // usual
      u is Map ? u['name'] : null,
    ], fallback: 'Sin nombre');

    final email = _pickStr([
      json['email'],               // por si viene plano
      u is Map ? u['email'] : null // usual
    ], fallback: 'Sin email');

    final categoria = _pickStr([
      json['categoria'],
      pl is Map ? pl['categoria'] : null,
    ], fallback: '');

    final descripcion = _pickStr([
      json['descripcion'],
      pl is Map ? pl['descripcion'] : null,
      json['bio'],
      pl is Map ? pl['bio'] : null,
    ], fallback: '');

    final experiencia = _i(
      json['experiencia'] ?? (pl is Map ? pl['experiencia'] : null),
      fallback: 0,
    );

    return TrabajadorModel(
      id: _i(json['id'], fallback: 0),
      userId: _i(json['userId'] ?? (u is Map ? u['id'] : null), fallback: 0),
      nombre: nombre,
      email: email,
      categoria: categoria,
      descripcion: descripcion,
      experiencia: experiencia,
    );
  }
}
