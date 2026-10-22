import 'package:flutter/material.dart';
import '../../core/session_manager.dart';
import '../../widgets/auth_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final logado = SessionManager.instance?.isLoggedIn() == true;
    Navigator.of(context).pushReplacementNamed(logado ? '/main' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFD7193F),
      body: AuthLoader(titulo: 'ML Flutter', subtitulo: 'Autenticando...'),
    );
  }
}
