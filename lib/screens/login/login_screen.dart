import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/widgets/auth_logo_animado.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:minhaloja/screens/login/login_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _mostrarSenha = false;
  bool _salvarCredenciais = false;
  bool _showForm = false;
  bool _reconectando = false;
  bool _waitingBrowserReturn = false;
  bool _validatingToken = false;
  String _clipboardHash = '';

  final SessionManager _session = SessionManager.instance!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _controller.forward();

    if (_session.isLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      });
      return;
    }

    _emailController.text = _session.getUserEmail() ?? '';
    _salvarCredenciais = _session.hasSavedCredentials();

    if (_session.hasSavedCredentials()) {
      _senhaController.text = _session.getSavedPassword() ?? '';
      _iniciarReconexaoSilenciosa();
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showForm = true);
      });
    }
  }

  void _iniciarReconexaoSilenciosa() {
    setState(() {
      _reconectando = true;
      _showForm = false;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _abrirWebView(autoLogin: true, silencioso: true);
    });
  }

  void _abrirWebView({required bool autoLogin, bool silencioso = false}) {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (_salvarCredenciais) {
      _session.saveCredentials(email, senha);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(arguments: {
          LoginWebViewScreen.EXTRA_AUTO_LOGIN: autoLogin,
          LoginWebViewScreen.EXTRA_EMAIL: email,
          LoginWebViewScreen.EXTRA_SENHA: senha,
          LoginWebViewScreen.EXTRA_SILENCIOSO: silencioso,
        }),
        builder: (_) => const LoginWebViewScreen(),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _waitingBrowserReturn) {
      await _checkClipboardForToken();
    }
  }

  Future<void> _handleOpenBrowser() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _clipboardHash = data?.text ?? '';
      _waitingBrowserReturn = true;
      setState(() {});
      await launchUrl(
        Uri.parse('https://sl-authorization.americanas.io/minha-loja'),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) {
        ToastUtils.showInfo(context,
            'Faça login no navegador, copie o token e volte ao app.');
      }
    } catch (e) {
      _waitingBrowserReturn = false;
      if (mounted) {
        setState(() {});
        ToastUtils.showError(
            context, 'Não foi possível abrir o navegador: $e');
      }
    }
  }

  Future<void> _checkClipboardForToken() async {
    if (_validatingToken) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text ?? '';
      if (clipboardText.isEmpty || clipboardText == _clipboardHash) return;

      String token = clipboardText.trim();
      if (token.toLowerCase().startsWith('bearer ')) {
        token = token.substring(7).trim();
      }
      final cookieIdx = token.indexOf('newToken=');
      if (cookieIdx >= 0) {
        var value = token.substring(cookieIdx + 'newToken='.length);
        final sep = value.indexOf(RegExp(r'[;&]'));
        if (sep >= 0) value = value.substring(0, sep);
        token = value.trim();
      }
      if (token.contains('token=')) {
        final qi = token.indexOf('token=');
        var value = token.substring(qi + 'token='.length);
        final amp = value.indexOf(RegExp(r'[&\s]'));
        if (amp >= 0) value = value.substring(0, amp);
        token = Uri.decodeComponent(value).trim();
      }

      if (token.length < 50) {
        if (mounted) {
          ToastUtils.showInfo(context,
              'Nenhum token encontrado. Copie o token no navegador e volte ao app.');
        }
        return;
      }
      if (token == _clipboardHash) return;
      _clipboardHash = token;

      await _validateAndLogin(token);
    } catch (_) {}
  }

  Future<void> _validateAndLogin(String token) async {
    if (_validatingToken) return;
    _validatingToken = true;
    if (mounted) setState(() {});
    try {
      final dio = ApiClient.instance.getSlApiServiceWithToken(token);
      await ApiService(dio)
          .getPriceSignFilters(_session.getUserStore());
      if (!mounted) return;
      _salvarSessaoBrowser(token);
      _waitingBrowserReturn = false;
      _validatingToken = false;
      ToastUtils.showSuccess(context, 'Login realizado com sucesso');
      Navigator.pushReplacementNamed(context, '/main');
    } on ApiException catch (e) {
      _validatingToken = false;
      if (mounted) {
        setState(() {});
        ToastUtils.showError(context,
            'Token detectado mas rejeitado (${e.statusCode ?? 'erro'}). Tente copiar o token novamente no navegador.');
      }
    } catch (e) {
      _validatingToken = false;
      if (mounted) {
        setState(() {});
        ToastUtils.showError(
            context, 'Token detectado mas não foi possível validar.');
      }
      LogHelper.e('BrowserLogin: erro ao validar token', e);
    }
  }

  void _salvarSessaoBrowser(String token) {
    Map<String, dynamic>? claims;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final j = jsonDecode(utf8.decode(base64Url.decode(p)));
        if (j is Map) claims = Map<String, dynamic>.from(j);
      }
    } catch (_) {}

    _session.saveTokenWithExpiry(token,
        expiryEpochSeconds: claims?['exp'] is int ? claims!['exp'] as int : null);

    final user = claims?['user'] is Map
        ? Map<String, dynamic>.from(claims!['user'])
        : null;

    String email = (user?['email'] ??
            claims?['email'] ??
            claims?['preferred_username'] ??
            claims?['upn'])
        ?.toString() ??
        (_session.getUserEmail() ?? '');
    String nome = (user?['nome'] ??
            user?['name'] ??
            claims?['name'] ??
            claims?['given_name'])
        ?.toString() ??
        '';
    final stores = user?['stores'] ?? claims?['stores'];
    final loja = user?['loja']?.toString() ??
        claims?['loja']?.toString() ??
        (stores is List && stores.isNotEmpty
            ? stores.first.toString()
            : null);

    if (email.isEmpty) email = 'usuario@americanas.io';
    if (nome.isEmpty) {
      nome = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
      nome = nome
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' ');
    }
    _session.saveUserInfo(email, nome, loja ?? _session.getUserStore());
  }

  void _entrar() {
    _abrirWebView(autoLogin: false);
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: const AuthLogoAnimado(size: 150),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0.75, 0.1),
                child: Transform.scale(
                  scale: 5.0,
                  child: const Text(
                    'a',
                    style: TextStyle(
                      fontSize: 320,
                      color: Color(0x17111111),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 3200),
                      builder: (context, v, child) => Opacity(
                        opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0),
                        child: child,
                      ),
                      child: const Text(
                        'minha loja',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Para ter acesso ao portal, vamos manter os fluxos de '
                        'autenticação segura.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_reconectando)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sessão expirada. Reconectando automaticamente...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else if (_showForm)
                      AnimatedOpacity(
                        opacity: _showForm ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 600),
                        child: _buildForm(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    );
    return Card(
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'americanas.io',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F1F1F),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _entrar,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MicrosoftLogo(size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Login Microsoft',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'versão 1.1.73',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}

/// Logo 2x2 da Microsoft (4 quadrados coloridos).
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c = size / 2 - 1;
    final tiles = [
      Container(color: const Color(0xFFF25022)),
      Container(color: const Color(0xFF7FBA00)),
      Container(color: const Color(0xFF00A4EF)),
      Container(color: const Color(0xFFFFBA08)),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[0]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[1]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[2]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[3]),
          ]),
        ],
      ),
    );
  }
}
