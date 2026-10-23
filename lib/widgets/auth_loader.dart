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
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 3200),
              builder: (context, v, child) => Opacity(
                opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0),
                child: child,
              ),
              child: const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'minha loja',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
