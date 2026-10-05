import 'package:flutter/material.dart';

class AnimatedTrashAction extends StatefulWidget {
  final VoidCallback onPressed;
  const AnimatedTrashAction({super.key, required this.onPressed});

  @override
  State<AnimatedTrashAction> createState() => _AnimatedTrashActionState();
}

class _AnimatedTrashActionState extends State<AnimatedTrashAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (_tapped) return;
    _tapped = true;
    await _ctrl.forward();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, _) {
            final t = _ctrl.value;

            double scale;
            if (t < 0.3) {
              scale = 1.0 + 0.35 * Curves.easeOutBack.transform(t / 0.3);
            } else if (t > 0.7) {
              scale = 1.35 - 0.35 * Curves.easeIn.transform((t - 0.7) / 0.3);
            } else {
              scale = 1.35;
            }

            double paperY = -30;
            double paperOpacity = 0;
            double paperScale = 1.0;
            if (t > 0.15 && t < 0.6) {
              final pt = (t - 0.15) / 0.45;
              paperY = -30 + 30 * Curves.easeIn.transform(pt);
              paperOpacity = pt > 0.7 ? (1 - pt) / 0.3 : 1.0;
              paperScale = 1.0 - 0.6 * pt;
            }

            return Container(
              color: const Color(0xFFD32F2F),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (paperOpacity > 0.01)
                    Transform.translate(
                      offset: Offset(0, paperY - 10),
                      child: Transform.scale(
                        scale: paperScale,
                        child: Opacity(
                          opacity: paperOpacity.clamp(0.0, 1.0),
                          child: Container(
                            width: 11,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(210),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: scale,
                    child: const Icon(Icons.delete, color: Colors.white, size: 26),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
