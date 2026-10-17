import 'package:flutter/material.dart';

/// Badge flutuante de ação: icone a esquerda do texto e, ao clicar, o texto
/// some e o icone assume o centro pulsando enquanto a ação roda.
class BadgeAcao extends StatefulWidget {
  final String texto;
  final IconData icone;
  final Color corFundo;
  final Color corTexto;
  final Color? corBorda;
  final void Function() onPressed;

  const BadgeAcao({
    super.key,
    required this.texto,
    required this.icone,
    required this.corFundo,
    required this.corTexto,
    this.corBorda,
    required this.onPressed,
  });

  @override
  State<BadgeAcao> createState() => _BadgeAcaoState();
}

class _BadgeAcaoState extends State<BadgeAcao>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _escala;
  bool _executando = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _escala = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _executar() async {
    if (_executando) return;
    setState(() => _executando = true);
    _controller.repeat(reverse: true);
    try {
      await Future.sync(widget.onPressed);
    } finally {
      _controller.stop();
      if (mounted) setState(() => _executando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borda = widget.corBorda;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _executar,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: widget.corFundo,
            borderRadius: BorderRadius.circular(30),
            border: borda != null ? Border.all(color: borda) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _executando
                    ? _escala
                    : const AlwaysStoppedAnimation<double>(1.0),
                child: Icon(widget.icone, color: widget.corTexto, size: 20),
              ),
              if (!_executando) ...[
                const SizedBox(width: 6),
                Text(
                  widget.texto,
                  style: TextStyle(
                    color: widget.corTexto,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
