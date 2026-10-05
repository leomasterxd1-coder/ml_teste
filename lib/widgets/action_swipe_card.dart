import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'animated_trash_icon.dart';

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

  final double _threshold = -100.0; // Distância mínima para acionar a eliminação

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
      if (_dragOffset > 0) _dragOffset = 0; // Restringe deslize apenas para a esquerda
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isDeleting) return;

    if (_dragOffset < _threshold) {
      setState(() {
        _isDeleting = true;
      });
      _controller.forward();
    } else {
      // Retorna ao estado inicial
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

    final bool isTrashOpen = _dragOffset < (_threshold / 2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Fundo Vermelho com o Ícone da Lixeira
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedScale(
                scale: isTrashOpen ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedRotation(
                  turns: isTrashOpen ? -0.05 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: AnimatedTrashIcon(animate: isTrashOpen || _isDeleting),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Card Interativo (Arraste + Animação de Papel Amassado)
          AnimatedBuilder(
            animation: _animProgress,
            builder: (context, _) {
              final progress = _animProgress.value;

              // FASE DE ARRASTE MANUAL
              if (!_isDeleting) {
                return Transform(
                  transform: Matrix4.identity()
                    ..translate(_dragOffset)
                    ..rotateZ(_dragOffset * 0.0008),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: widget.child,
                  ),
                );
              }

              // FASE DE ANIMAÇÃO (Amassar -> Voar para a Lixeira Vermelha)
              double scaleFactor = 1.0;
              double opacity = 1.0;
              double translateX = _dragOffset;
              double translateY = 0.0;
              double rotation = _dragOffset * 0.0008;

              if (progress <= 0.4) {
                // Etapa A: Deforma / encolhe levemente
                final p = progress / 0.4;
                scaleFactor = 1.0 - (p * 0.3);
              } else {
                // Etapa B: O papel voa em arco em direção à lixeira vermelha
                final p = (progress - 0.4) / 0.6;
                scaleFactor = 0.7 * (1.0 - p * 0.5);
                opacity = (1.0 - p).clamp(0.0, 1.0);

                // Trajetória do salto para dentro do bloco vermelho
                translateX = _dragOffset + (p * (-_dragOffset + 120));
                translateY = math.sin(p * math.pi) * -30;
                rotation = p * math.pi * 4;
              }

              return Opacity(
                opacity: opacity,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(translateX, translateY)
                    ..rotateZ(rotation)
                    ..scale(scaleFactor),
                  alignment: Alignment.center,
                  child: widget.child,
                ),
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
