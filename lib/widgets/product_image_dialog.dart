import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session_manager.dart';
import '../services/product_image_service.dart';

/// Abre a imagem do produto em tela cheia, com descrição, saldo, EAN e SAP.
Future<void> mostrarImagemProduto(
  BuildContext context, {
  required String ean,
  String descricao = '',
  String codSap = '',
  double? saldo,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ProdutoImagemDialog(
      ean: ean,
      descricao: descricao,
      codSap: codSap,
      saldo: saldo,
    ),
  );
}

class _ProdutoImagemDialog extends StatefulWidget {
  final String ean;
  final String descricao;
  final String codSap;
  final double? saldo;

  const _ProdutoImagemDialog({
    required this.ean,
    required this.descricao,
    required this.codSap,
    this.saldo,
  });

  @override
  State<_ProdutoImagemDialog> createState() => _ProdutoImagemDialogState();
}

class _ProdutoImagemDialogState extends State<_ProdutoImagemDialog> {
  String? _url;
  Uint8List? _bytes;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    ProductImageResult? resultado;
    Uint8List? bytes;
    try {
      final session = await SessionManager.getInstance();
      final store = session.getUserStore();
      resultado = await ProductImageService.buscarImagem(
        widget.ean,
        store,
        descricao: widget.descricao,
      );
      if (resultado != null) {
        bytes = await ProductImageService.baixarBytes(resultado.url);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _url = resultado?.url;
      _bytes = bytes;
      _carregando = false;
    });
  }

  String _extensao() {
    final url = (_url ?? '').toLowerCase();
    if (url.contains('.png')) return 'png';
    if (url.contains('.webp')) return 'webp';
    return 'jpg';
  }

  Future<void> _salvarImagemComConfirmacao() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Salvar imagem'),
        content: const Text('Deseja salvar a imagem em Download/Imagem do produto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ext = _extensao();
    final mime = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
    try {
      await const MethodChannel('minhaloja/pdf').invokeMethod<String>(
        'saveImageToDownloads',
        {
          'fileName': '${widget.ean}.$ext',
          'mime': mime,
          'bytes': bytes,
          'subfolder': 'Imagem do produto',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagem salva em Download/Imagem do produto',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a imagem'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copiarEan() async {
    await Clipboard.setData(ClipboardData(text: widget.ean));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('EAN copiado: ${widget.ean}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descricao = widget.descricao.trim().isEmpty
        ? widget.ean
        : widget.descricao.trim();
    final size = MediaQuery.sizeOf(context);
    final alturaImagem = math.min(size.width * 0.9, 460.0);

    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                          SizedBox(width: 8),
                          Text('FECHAR',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descricao,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: alturaImagem,
                          child: _conteudoImagem(),
                        ),
                      ),
                      if (widget.saldo != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.saldo! < 0
                                ? const Color(0xFFFDECEC)
                                : const Color(0xFFE7F4E8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Estoque estimado: ${widget.saldo!.toInt()}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.saldo! < 0
                                    ? const Color(0xFFD81B3A)
                                    : const Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text('Informações do produto no SAP',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 10),
                      Text(descricao,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                              height: 1.4)),
                      const SizedBox(height: 8),
                      if (widget.codSap.trim().isNotEmpty)
                        _linhaInfo('Código SAP', widget.codSap.trim()),
                      if (widget.ean.trim().isNotEmpty)
                        InkWell(
                          onTap: _copiarEan,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Flexible(
                                  child: _linhaInfo(
                                      'EAN', widget.ean.trim(),
                                      mostrarIcone: false),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy,
                                    size: 14, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudoImagem() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Buscando imagem...',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    if (_bytes == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 42, color: Color(0xFF9CA3AF)),
            SizedBox(height: 10),
            Text('Imagem não encontrada',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _salvarImagemComConfirmacao,
      child: Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _linhaInfo(String label, String valor, {bool mostrarIcone = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF666666))),
              TextSpan(
                  text: valor,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A1A1A))),
            ],
          ),
        ),
      );
}
