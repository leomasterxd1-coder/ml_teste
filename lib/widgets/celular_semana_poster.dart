import 'dart:io';

import 'package:flutter/material.dart';
import 'package:minhaloja/utils/celular_semana.dart';

String _money(double value, {bool omitZeroCents = false}) {
  final fixed = value.toStringAsFixed(2).split('.');
  final inteiro = (int.tryParse(fixed[0]) ?? 0).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  if (omitZeroCents && fixed[1] == '00') return buf.toString();
  return '${buf.toString()},${fixed[1]}';
}

class CelularSemanaPoster extends StatelessWidget {
  static const double posterWidth = 1055;
  static const double posterHeight = 1491;
  static const Color _ink = Color(0xFF1D1D1B);
  static const String _overlay = 'assets/overlays/celular_semana.png';

  final CelularSemanaData data;

  const CelularSemanaPoster({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: posterWidth,
      height: posterHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _overlay,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          _foto(),
          _descricao(),
          _de(),
          _por(),
          _planoControle(),
          _comboValores(),
          _letraMiuda(),
        ],
      ),
    );
  }

  Widget _foto() {
    final path = data.imagemPath.trim();
    final file = path.isEmpty ? null : File(path);
    return Positioned(
      left: 70,
      top: 415,
      width: 345,
      height: 470,
      child: file != null && file.existsSync()
          ? Image.file(
              file,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _semFoto(),
            )
          : _semFoto(),
    );
  }

  Widget _semFoto() {
    return const Center(
      child: Icon(Icons.smartphone, size: 200, color: Color(0xFFD9D9D9)),
    );
  }

  Widget _descricao() {
    final partes = _partesDescricao(data.descricao);
    return Positioned(
      left: 430,
      top: 425,
      width: 525,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partes.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 58,
              fontWeight: FontWeight.w400,
              height: 0.9,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            partes.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 62,
              fontWeight: FontWeight.w700,
              height: 0.9,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _partesDescricao(String descricao) {
    final palavras = descricao.trim().split(RegExp(r'\s+'));
    if (palavras.isEmpty || palavras.first.isEmpty) {
      return ('', '');
    }
    final n = palavras.length <= 2 ? 1 : 2;
    final primeira = palavras.take(n).join(' ');
    final segunda = palavras.skip(n).join(' ');
    return (primeira, segunda);
  }

  Widget _de() {
    return Positioned(
      left: 430,
      top: 550,
      width: 525,
      child: Text(
        'de: R\$${_money(data.precoOriginal)} à vista',
        style: const TextStyle(
          fontFamily: 'SFProDisplay',
          color: _ink,
          fontSize: 34,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _por() {
    return Positioned(
      left: 430,
      top: 600,
      width: 525,
      height: 88,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'por: ',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'R\$${_money(data.precoFinal)}',
                style: const TextStyle(
                  fontSize: 88,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.8,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'SFProDisplay',
            color: _ink,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _planoControle() {
    return Positioned(
      left: 430,
      top: 700,
      width: 525,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '+ plano controle',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 44,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '(válido na portabilidade para quaisquer bandeiras*)',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comboValores() {
    return Positioned.fill(
      child: Stack(
        children: [
          _valorCaixa(
            left: 72,
            width: 209,
            top: 1150,
            texto: 'R\$${_money(data.precoOriginal, omitZeroCents: true)}',
            fontSize: 36,
          ),
          _valorCaixa(
            left: 302,
            width: 190,
            top: 1155,
            texto: 'R\$${_money(data.descontoPortabilidade)}',
            fontSize: 36,
          ),
          _valorCaixa(
            left: 526,
            width: 191,
            top: 1150,
            texto: '${data.percentualFormatado}% OFF',
            fontSize: 36,
          ),
          _valorCaixa(
            left: 750,
            width: 190,
            top: 1150,
            texto: 'R\$${_money(data.seguro)}',
            fontSize: 36,
          ),
        ],
      ),
    );
  }

  Widget _valorCaixa({
    required double left,
    required double width,
    required double top,
    required String texto,
    required double fontSize,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SFProDisplay',
            color: _ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _letraMiuda() {
    final texto = 'Descontos aplicados separadamente e podem ser adquiridos '
        'de forma individual.\n'
        'O desconto do seguro não está atrelado à venda de nenhum item e a '
        'contratação é opcional.\n'
        'Parcelamento disponível no crédito para todas as bandeiras, '
        'disponível apenas para ${data.descricao.toUpperCase()}.\n'
        'Desconto do plano controle disponível para portabilidade para '
        'quaisquer bandeiras, consulte planos\n'
        'e condições. Ofertas válidas de ${data.ofertaInicio} a '
        '${data.ofertaFim} podendo encerrar sem aviso prévio.';
    return Positioned(
      left: 60,
      top: 1210,
      width: 900,
      height: 135,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 900,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                color: _ink,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
