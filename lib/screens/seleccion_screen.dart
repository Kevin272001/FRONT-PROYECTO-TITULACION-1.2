import 'package:flutter/material.dart';
import 'login_screen.dart';

class SeleccionScreen extends StatelessWidget {
  const SeleccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ServiX',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Selecciona tu tipo de cuenta',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 60),

              // 👉 BOTÓN EMPLEADOR
              SizedBox(
                width: 250,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(rol: 'empleador'),
                      ),
                    );
                  },
                  child: const Text(
                    'Soy Empleador',
                    style: TextStyle(
                      color: Color(0xFF2575FC),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // 👉 BOTÓN TRABAJADOR
              SizedBox(
                width: 250,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(rol: 'trabajador'),
                      ),
                    );
                  },
                  child: const Text(
                    'Soy Trabajador',
                    style: TextStyle(
                      color: Color(0xFF2575FC),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),
              const Text(
                '© 2025 ServiX- Todos los derechos reservados',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
