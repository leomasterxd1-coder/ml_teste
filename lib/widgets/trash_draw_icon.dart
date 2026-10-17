import 'package:flutter/material.dart';

/// Lixeira com efeito de "desenho" (stroke surgindo), espelhando o SVG:
/// corpo (0-0.5s), tampa (0.5-0.8s) e detalhes (0.8-1.0s).
class TrashDrawIcon extends StatefulWidget {
  final double size;
  final bool animate;

  const TrashDrawIcon({super.key, this.size = 34, required this.animate});

  @override
  State<TrashDrawIcon> createState() => _TrashDrawIconState();
}

class _TrashDrawIconState extends State<TrashDrawIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.value = 1;
    if (widget.animate) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(TrashDrawIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _TrashPainter(_controller.value),
      ),
    );
  }
}

class _TrashPainter extends CustomPainter {
  final double progress;

  _TrashPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(12, 20)
      ..lineTo(17, 20)
      ..cubicTo(17.5, 20, 18, 19.5, 18, 19)
      ..lineTo(18, 5)
      ..moveTo(12, 20)
      ..lineTo(7, 20)
      ..cubicTo(6.5, 20, 6, 19.5, 6, 19)
      ..lineTo(6, 5);

    final lid = Path()
      ..moveTo(4, 5)
      ..lineTo(20, 5);

    final details = Path()
      ..moveTo(10, 4)
      ..lineTo(14, 4)
      ..moveTo(10, 9)
      ..lineTo(10, 16)
      ..moveTo(14, 9)
      ..lineTo(14, 16);

    _drawProgress(canvas, body, paint, _clamp((progress - 0.0) / 0.5));
    _drawProgress(canvas, lid, paint, _clamp((progress - 0.5) / 0.3));
    _drawProgress(canvas, details, paint, _clamp((progress - 0.8) / 0.2));

    canvas.restore();
  }

  double _clamp(double v) => v.clamp(0.0, 1.0);

  void _drawProgress(Canvas canvas, Path path, Paint paint, double fraction) {
    if (fraction <= 0) return;
    if (fraction >= 0.999) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * fraction),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrashPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
