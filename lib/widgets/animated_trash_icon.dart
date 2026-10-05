import 'package:flutter/material.dart';

class AnimatedTrashIcon extends StatefulWidget {
  final bool animate;
  const AnimatedTrashIcon({super.key, this.animate = false});

  @override
  State<AnimatedTrashIcon> createState() => _AnimatedTrashIconState();
}

class _AnimatedTrashIconState extends State<AnimatedTrashIcon>
    with TickerProviderStateMixin {
  late final AnimationController _lidController;
  late final Animation<double> _lidAngle;

  @override
  void initState() {
    super.initState();
    _lidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _lidAngle = Tween<double>(begin: 0, end: -0.6).animate(
      CurvedAnimation(parent: _lidController, curve: Curves.easeOutBack),
    );
    if (widget.animate) _lidController.forward();
  }

  @override
  void didUpdateWidget(AnimatedTrashIcon old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) {
      _lidController.forward();
    } else if (!widget.animate && old.animate) {
      _lidController.reverse();
    }
  }

  @override
  void dispose() {
    _lidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _lidAngle,
      builder: (context, _) {
        return SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Lixeira corpo
              Positioned(
                bottom: 1,
                child: Icon(Icons.delete, color: Colors.white, size: 24),
              ),
              // Tampa animada
              Positioned(
                top: 1,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_lidAngle.value),
                  child: Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
