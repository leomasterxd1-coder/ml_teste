import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session_manager.dart';
import '../services/product_image_service.dart';

/// Abre o diálogo com a imagem do produto pelo EAN.
Future<void> mostrarImagemProduto(
  BuildContext context, {
  required String ean,
  String descricao = '',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ProdutoImagemDialog(ean: ean, descricao: descricao),
  );
}

class _ProdutoImagemDialog extends StatefulWidget {
  final String ean;
  final String descricao;

  const _ProdutoImagemDialog({required this.ean, required this.descricao});

  @override
  State<_ProdutoImagemDialog> createState() => _ProdutoImagemDialogState();
}

class _ProdutoImagemDialogState extends State<_ProdutoImagemDialog> {
  String? _url;
  String? _fonte;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    ProductImageResult? resultado;
    try {
      final session = await SessionManager.getInstance();
      final store = session.getUserStore();
      resultado = await ProductImageService.buscarImagem(
        widget.ean, store, descricao: widget.descricao);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _url = resultado?.url;
      _fonte = resultado?.fonte;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Imagem do produto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.descricao.isEmpty ? widget.ean : widget.descricao,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: widget.ean));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('EAN copiado: ${widget.ean}'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(
                'EAN: ${widget.ean} (toque para copiar)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_carregando)
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_url == null)
              const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'Imagem não encontrada',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 360,
                  minHeight: 120,
                ),
                child: Image.network(
                  _url!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        'Não foi possível carregar a imagem',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ),
            if (_fonte != null) ...[
              const SizedBox(height: 8),
              Text(
                'Fonte: $_fonte',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'FECHAR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
