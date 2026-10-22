import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

const String _path1 =
    'M1482 4338 c-43 -24 -60 -42 -322 -344 -91 -104 -177 -202 -191 -219 -15 -16 -120 -138 -235 -270 -114 -132 -227 -262 -252 -290 -41 -46 -44 -53 -40 -95 10 -101 96 -213 203 -265 33 -17 96 -37 140 -45 l80 -16 5 -984 5 -985 28 -53 c37 -70 97 -128 166 -161 l56 -26 1470 0 1470 0 56 26 c75 36 134 96 172 177 l31 66 0 970 1 970 72 12 c187 32 337 165 351 313 l4 46 -189 216 c-275 316 -541 622 -680 783 -67 77 -141 153 -164 169 -43 27 -43 27 -230 27 l-187 0 300 -597 c291 -581 300 -599 295 -645 -25 -214 -304 -375 -542 -313 -180 47 -303 177 -324 343 -28 213 -170 1180 -176 1200 -4 10 -61 12 -262 10 l-258 -3 -56 -375 c-53 -357 -100 -685 -120 -832 -22 -173 -153 -307 -339 -348 -192 -42 -422 63 -497 227 -53 115 -70 68 265 736 l301 597 -183 0 c-171 0 -186 -1 -224 -22z m1648 -1664 l0 -124 -547 2 -548 3 -3 122 -3 122 551 0 550 0 0 -125z m-337 -309 c118 -31 174 -72 223 -165 17 -32 19 -69 24 -410 5 -315 8 -381 22 -412 9 -20 14 -39 10 -42 -3 -3 -61 -6 -128 -6 -137 0 -147 4 -158 65 l-7 36 -37 -29 c-131 -103 -337 -121 -488 -44 -75 38 -125 110 -142 202 -19 103 8 192 81 267 52 55 141 85 332 113 158 24 217 46 235 90 12 29 7 77 -12 113 -16 31 -87 57 -154 57 -100 0 -153 -31 -179 -107 l-13 -38 -132 -3 -133 -3 6 46 c7 47 34 109 70 157 42 57 154 110 272 128 78 12 234 4 308 -15z m367 -1350 l0 -125 -565 0 -565 0 0 125 0 125 565 0 565 0 0 -125z';

const String _path2 =
    'M2715 1815 c-17 -7 -73 -20 -125 -29 -162 -28 -210 -65 -210 -160 0 -87 67 -131 190 -124 129 7 187 76 197 237 7 100 5 101 -52 76z';

/// Ícone do app (logo) sendo "desenhado" (traçado) em branco.
class AuthLogoAnimado extends StatefulWidget {
  final double size;
  final Color color;
  const AuthLogoAnimado({
    super.key,
    this.size = 140,
    this.color = Colors.white,
  });

  @override
  State<AuthLogoAnimado> createState() => _AuthLogoAnimadoState();
}

class _AuthLogoAnimadoState extends State<AuthLogoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Path _path;
  late final List<PathMetric> _metrics;
  late final double _total;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    final m = Matrix4.identity()
      ..translate(0.0, 480.0)
      ..scale(0.1, -0.1);
    _path = Path()
      ..addPath(parseSvgPathData(_path1).transform(m.storage), Offset.zero)
      ..addPath(parseSvgPathData(_path2).transform(m.storage), Offset.zero);
    _metrics = _path.computeMetrics().toList();
    _total = _metrics.fold(0.0, (s, mt) => s + mt.length);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final drawP = (t / 0.85).clamp(0.0, 1.0);
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(
            path: _path,
            metrics: _metrics,
            total: _total,
            drawP: drawP,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Path path;
  final List<PathMetric> metrics;
  final double total;
  final double drawP;
  final Color color;

  _LogoPainter({
    required this.path,
    required this.metrics,
    required this.total,
    required this.drawP,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final b = path.getBounds();
    final s = math.min(size.width / b.width, size.height / b.height);
    final dx = (size.width - b.width * s) / 2 - b.left * s;
    final dy = (size.height - b.height * s) / 2 - b.top * s;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(s);

    var restante = total * drawP;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in metrics) {
      if (restante <= 0) break;
      final len = math.min(m.length, restante);
      canvas.drawPath(m.extractPath(0, len), stroke);
      restante -= len;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.drawP != drawP || old.color != color;
}
