import 'dart:io';

import 'package:flutter/material.dart';
import 'package:minhaloja/utils/celular_semana.dart';

String _money(double value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final inteiro = (int.tryParse(fixed[0]) ?? 0).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
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
      left: 25,
      top: 322,
      width: 480,
      height: 565,
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
      left: 515,
      top: 340,
      width: 510,
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
              fontSize: 40,
              fontWeight: FontWeight.w400,
              height: 1,
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
              fontSize: 60,
              fontWeight: FontWeight.w700,
              height: 0.95,
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
    var n = 2;
    if (palavras.length <= 2) {
      n = 1;
    } else if (RegExp(r'\d').hasMatch(palavras[1])) {
      n = 1;
    }
    final primeira = palavras.take(n).join(' ');
    final segunda = palavras.skip(n).join(' ');
    return (primeira, segunda);
  }

  Widget _de() {
    return Positioned(
      left: 515,
      top: 510,
      width: 510,
      child: Text(
        'de: R\$ ${_money(data.precoOriginal)} à vista',
        style: const TextStyle(
          fontFamily: 'SFProDisplay',
          color: _ink,
          fontSize: 36,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _por() {
    return Positioned(
      left: 515,
      top: 565,
      width: 510,
      height: 104,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
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
                text: 'R\$ ${_money(data.precoFinal)}',
                style: const TextStyle(
                  fontSize: 90,
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

  Widget _comboValores() {
    return Positioned.fill(
      child: Stack(
        children: [
          _valorCaixa(
            left: 35,
            width: 210,
            top: 1055,
            texto: 'R\$ ${_money(data.precoOriginal)}',
            fontSize: 34,
          ),
          _valorCaixa(
            left: 280,
            width: 235,
            top: 1078,
            texto: 'R\$ ${_money(data.descontoPortabilidade)}',
            fontSize: 30,
          ),
          _valorCaixa(
            left: 550,
            width: 235,
            top: 1052,
            texto: '${data.percentualFormatado}% OFF',
            fontSize: 42,
          ),
          _valorCaixa(
            left: 820,
            width: 200,
            top: 1048,
            texto: 'R\$ ${_money(data.seguro)}',
            fontSize: 30,
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
        'disponível apenas para ${data.descricao}.\n'
        'Desconto do plano controle disponível para portabilidade para '
        'quaisquer bandeiras, consulte planos\n'
        'e condições. Ofertas válidas de ${data.ofertaInicio} a '
        '${data.ofertaFim} podendo encerrar sem aviso prévio.';
    return Positioned(
      left: 35,
      top: 1122,
      width: 985,
      height: 176,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 965,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                color: _ink,
                fontSize: 20.5,
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
