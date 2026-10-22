import 'package:flutter/material.dart';
import 'auth_logo_animado.dart';

/// Tela/widget de autenticação: logo do app sendo desenhado (branco),
/// título e subtítulo.
class AuthLoader extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  const AuthLoader({
    super.key,
    this.titulo = 'ML Flutter',
    this.subtitulo = 'Autenticando...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AuthLogoAnimado(size: 140),
            const SizedBox(height: 28),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
