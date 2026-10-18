import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
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
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pulseScale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
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
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha e-mail e senha.'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _abrirWebView(autoLogin: true);
  }

  Widget _buildLogo() {
    const topD =
        'M16674 19124 c8 -20 8 -2398 0 -2418 -6 -15 -556 -16 -6135 -16 l-6129 0 0 1218 c0 670 3 1222 7 1225 3 4 2761 7 6129 7 5573 0 6122 -1 6128 -16z';
    const bodyD =
        'M11350 14527 c400 -31 679 -64 970 -115 194 -35 468 -115 690 -204 41 -16 88 -35 105 -41 126 -50 444 -232 541 -310 262 -211 431 -391 547 -584 167 -276 266 -569 297 -882 6 -67 10 -932 10 -2475 0 -2260 6 -2817 30 -3076 14 -145 38 -372 50 -470 5 -41 12 -100 15 -130 6 -61 30 -186 45 -240 44 -161 87 -275 146 -393 19 -37 34 -69 34 -72 0 -3 -552 -4 -1226 -3 -1079 3 -1228 5 -1234 18 -7 13 -51 166 -79 275 -27 107 -66 342 -77 468 -3 42 -9 77 -13 77 -4 0 -25 -18 -46 -41 -61 -63 -241 -218 -330 -285 -335 -252 -692 -424 -1110 -534 -66 -18 -140 -38 -165 -45 -60 -18 -268 -62 -355 -75 -348 -53 -530 -70 -830 -77 -419 -9 -742 23 -1130 113 -38 9 -81 18 -95 21 -55 11 -287 83 -335 104 -11 5 -43 17 -71 28 -63 24 -279 135 -354 181 -185 116 -330 231 -470 376 -338 350 -537 763 -624 1294 -47 286 -47 771 0 1040 28 161 93 390 144 515 34 82 45 106 85 185 50 102 151 259 224 350 150 187 402 408 586 516 111 64 136 78 290 153 194 95 334 147 535 201 210 56 270 71 360 90 58 12 168 35 245 51 191 41 382 74 590 104 55 8 116 17 135 20 19 3 114 16 210 30 170 23 237 31 520 60 247 26 324 35 390 44 36 6 88 13 115 16 60 7 293 50 390 71 166 37 204 47 275 70 203 67 431 188 534 283 70 65 137 180 173 296 25 83 24 398 -1 530 -57 287 -175 493 -364 634 -242 179 -530 244 -1134 258 -223 5 -285 3 -385 -12 -259 -38 -485 -117 -705 -247 -125 -74 -299 -279 -385 -453 -79 -161 -138 -382 -145 -545 l-3 -55 -555 -6 c-305 -3 -856 -7 -1223 -8 l-668 -1 6 78 c34 470 158 880 378 1257 169 289 441 580 757 812 85 62 243 163 256 163 2 0 23 12 47 27 23 15 103 57 177 94 187 92 252 120 425 183 140 50 175 61 395 123 232 64 702 137 1125 173 265 23 947 21 1265 -3z';
    const baseD =
        'M16675 3148 c3 -13 4 -513 3 -1113 l-3 -1090 -6132 -3 -6133 -2 0 1115 0 1115 6130 0 6130 0 5 -22z';
    const sD =
        'M12036 9781 c-122 -96 -289 -163 -579 -235 -236 -58 -502 -106 -662 -121 -38 -3 -99 -10 -135 -16 -36 -5 -130 -18 -210 -29 -329 -44 -432 -63 -615 -110 -66 -18 -133 -35 -150 -39 -92 -24 -294 -101 -383 -147 -197 -102 -307 -191 -417 -338 -154 -205 -215 -407 -215 -707 0 -336 93 -582 291 -776 83 -80 129 -113 236 -167 253 -126 532 -178 983 -180 268 -1 417 16 645 75 132 34 190 55 365 136 301 138 583 426 728 743 89 195 128 343 168 635 27 201 32 1317 5 1314 -3 0 -28 -17 -55 -38z';
    String part(String d) =>
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2048 2048">'
        '<g transform="translate(0,2048) scale(0.1,-0.1)" fill="#FFFFFF" stroke="none">'
        '<path d="$d"/></g></svg>';
    const cubic = Cubic(0.77, 0, 0.175, 1);
    final barAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 110.0)
              .chain(CurveTween(curve: cubic)),
          weight: 25),
      TweenSequenceItem(tween: ConstantTween(110.0), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 110.0, end: 0.0)
              .chain(CurveTween(curve: cubic)),
          weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_pulse);
    final letterOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: cubic)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: cubic)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    ]).animate(_pulse);
    final letterScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.95)
              .chain(CurveTween(curve: cubic)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.95), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.95, end: 1.0)
              .chain(CurveTween(curve: cubic)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    ]).animate(_pulse);

    return ScaleTransition(
      scale: _logoScale,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: SizedBox(
          width: 200,
          height: 240,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 400,
              height: 480,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Stack(
                  children: [
                    Positioned(
                      left: 50,
                      top: 90,
                      width: 300,
                      height: 300,
                      child: Opacity(
                        opacity: letterOpacity.value,
                        child: Transform.scale(
                          scale: letterScale.value,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SvgPicture.string(part(bodyD)),
                              SvgPicture.string(part(sD)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 90,
                      width: 300,
                      height: 300,
                      child: Transform.translate(
                        offset: Offset(0, barAnim.value),
                        child: SvgPicture.string(part(topD)),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 90,
                      width: 300,
                      height: 300,
                      child: Transform.translate(
                        offset: Offset(0, -barAnim.value),
                        child: SvgPicture.string(part(baseD)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                alignment: const Alignment(0.35, 0.1),
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
                    const Text(
                      'minha loja',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'E-mail',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Microsoft',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Senha',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _senhaController,
                obscureText: !_mostrarSenha,
                decoration: InputDecoration(
                  hintText: 'Senha',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarSenha
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppColors.gray900,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            InkWell(
              onTap: () =>
                  setState(() => _salvarCredenciais = !_salvarCredenciais),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _salvarCredenciais,
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      onChanged: (v) =>
                          setState(() => _salvarCredenciais = v ?? false),
                    ),
                    const Text(
                      'Salvar credenciais e ativar login automático',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
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
    _pulse.dispose();
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
