import 'package:flutter/material.dart';

class SwipeToTrashItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const SwipeToTrashItem({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  @override
  State<SwipeToTrashItem> createState() => _SwipeToTrashItemState();
}

class _SwipeToTrashItemState extends State<SwipeToTrashItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isDeleting = false;
  bool _isRemoved = false;

  late AnimationController _controller;
  late Animation<double> _animProgress;

  final double _threshold = 100.0; // Distância mínima para acionar a eliminação

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _animProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isRemoved = true;
        });
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDeleting) return;
    setState(() {
      _dragOffset += details.delta.dx;
      if (_dragOffset < 0) _dragOffset = 0; // Deslize apenas para a direita
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isDeleting) return;

    if (_dragOffset > _threshold) {
      setState(() {
        _isDeleting = true;
      });
      _controller.forward();
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemoved) {
      return const SizedBox.shrink();
    }

    final double largura = MediaQuery.of(context).size.width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 1. Fundo vermelho com a lixeira (igual ao Compose: raio 8,
          // icone estatico branco alinhado ao inicio).
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(color: Color(0xFFD32F2F)),
              child: const Icon(Icons.delete, color: Colors.white, size: 28),
            ),
          ),

          // 2. Card arrastavel: slide simples ate sair (SwipeToDismiss).
          AnimatedBuilder(
            animation: _animProgress,
            builder: (context, _) {
              if (!_isDeleting) {
                return Transform(
                  transform: Matrix4.identity()..translate(_dragOffset),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: widget.child,
                  ),
                );
              }

              final progress = _animProgress.value;
              final translateX = _dragOffset + ((largura - _dragOffset) * progress);
              return Transform(
                transform: Matrix4.identity()..translate(translateX),
                alignment: Alignment.center,
                child: widget.child,
              );
            },
          ),
        ],
      ),
    );
  }
}

// Alias para compatibilidade
class ActionSwipeCard extends SwipeToTrashItem {
  const ActionSwipeCard({
    super.key,
    required super.child,
    required super.onDismissed,
  });
}
