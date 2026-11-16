import 'package:flutter/material.dart';

import 'auth_logo_animado.dart';

class LogoRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color cor;

  const LogoRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.cor = const Color(0xFFD7193F),
  });

  @override
  State<LogoRefresh> createState() => _LogoRefreshState();
}

class _LogoRefreshState extends State<LogoRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _acumulado = 0;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _definirProgresso(double progresso) {
    final p = progresso.clamp(0.0, 1.0);
    if ((p - _controller.value).abs() < 0.005) return;
    _controller.value = p;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _atualizando) return false;
    if (n is ScrollStartNotification) {
      _acumulado = 0;
      _definirProgresso(0);
    } else if (n is OverscrollNotification && n.overscroll < 0) {
      _acumulado += -n.overscroll;
      _definirProgresso(_acumulado / 90);
    } else if (n is ScrollUpdateNotification && n.metrics.pixels < 0) {
      _definirProgresso(-n.metrics.pixels / 90);
    } else if (n is ScrollEndNotification) {
      _acumulado = 0;
      _definirProgresso(0);
    }
    return false;
  }

  Future<void> _atualizar() async {
    _atualizando = true;
    _acumulado = 0;
    await _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    try {
      await widget.onRefresh();
    } finally {
      _atualizando = false;
      await _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: _atualizar,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final p = _controller.value;
                if (p < 0.01) return const SizedBox.shrink();
                return Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: AuthLogoAnimado(
                        size: 40,
                        color: widget.cor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class LogoRefreshPage extends StatefulWidget {
  final Widget child;
  final Color cor;

  const LogoRefreshPage({
    super.key,
    required this.child,
    this.cor = const Color(0xFFD7193F),
  });

  @override
  State<LogoRefreshPage> createState() => _LogoRefreshPageState();
}

class _LogoRefreshPageState extends State<LogoRefreshPage> {
  int _chave = 0;

  Future<void> _recarregar() async {
    setState(() => _chave++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return LogoRefresh(
      cor: widget.cor,
      onRefresh: _recarregar,
      child: KeyedSubtree(
        key: ValueKey(_chave),
        child: widget.child,
      ),
    );
  }
}
