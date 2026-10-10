import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Botão BUSCAR dentro do campo:
/// - EAN/SAP -> ícone de leitor (SVG).
/// - Descrição -> lupa com animação (traço que se desenha).
class BuscarBotao extends StatefulWidget {
  final bool porDescricao;
  final bool buscando;
  final VoidCallback onPressed;

  const BuscarBotao({
    super.key,
    required this.porDescricao,
    required this.buscando,
    required this.onPressed,
  });

  @override
  State<BuscarBotao> createState() => _BuscarBotaoState();
}

class _BuscarBotaoState extends State<BuscarBotao>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.porDescricao) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BuscarBotao oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.porDescricao && !oldWidget.porDescricao) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.buscando ? null : widget.onPressed,
      child: Container(
        height: double.infinity,
        color: const Color(0xFFC61033),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: widget.buscando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : widget.porDescricao
                ? AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => CustomPaint(
                      size: const Size(22, 22),
                      painter: _LupaPainter(progress: _c.value),
                    ),
                  )
                : SvgPicture.asset(
                    'assets/icons/ic_leitor.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn),
                  ),
      ),
    );
  }
}

class _LupaPainter extends CustomPainter {
  final double progress;

  _LupaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    final p = progress;
    final circleFrac = (p / 0.714).clamp(0.0, 1.0);
    final handleFrac = ((p - 0.714) / 0.286).clamp(0.0, 1.0);

    final circle = Path()
      ..moveTo(10.76 * s, 13.24 * s)
      ..relativeCubicTo(-2.34 * s, -2.34 * s, -2.34 * s, -6.14 * s, 0, -8.49 * s)
      ..relativeCubicTo(2.34 * s, -2.34 * s, 6.14 * s, -2.34 * s, 8.49 * s, 0)
      ..relativeCubicTo(2.34 * s, 2.34 * s, 2.34 * s, 6.14 * s, 0, 8.49 * s)
      ..relativeCubicTo(-2.34 * s, 2.34 * s, -6.14 * s, 2.34 * s, -8.49 * s, 0)
      ..close();
    for (final m in circle.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * circleFrac), stroke);
    }

    if (handleFrac > 0) {
      final handle = Path()
        ..moveTo(10.5 * s, 13.5 * s)
        ..relativeLineTo(-7.5 * s, 7.5 * s);
      for (final m in handle.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * handleFrac), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LupaPainter old) => old.progress != progress;
}
