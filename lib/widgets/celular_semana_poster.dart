import 'dart:io';

import 'package:flutter/material.dart';
import 'package:minhaloja/utils/celular_semana.dart';
import 'package:qr_flutter/qr_flutter.dart';

String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

class CelularSemanaPoster extends StatelessWidget {
  static const double posterWidth = 1240;
  static const double posterHeight = 1754;
  static const Color _red = Color(0xFFE60012);
  static const Color _ink = Color(0xFF1D1D1B);
  static const Color _boxColor = Color(0xFFF1F1F1);

  final CelularSemanaData data;

  const CelularSemanaPoster({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'SFProDisplay', color: _ink),
      child: SizedBox(
        width: posterWidth,
        height: posterHeight,
        child: ColoredBox(
          color: _red,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 290,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'celular da\nsemana',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 120,
                        fontWeight: FontWeight.w900,
                        height: 0.86,
                        letterSpacing: -5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _cartaoBranco()),
                const SizedBox(height: 12),
                _rodape(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartaoBranco() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 56,
              padding: const EdgeInsets.only(left: 20, right: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'oferta especial cartão cliente •',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _logoA(size: 34),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 43, child: _foto()),
                const SizedBox(width: 20),
                Expanded(flex: 57, child: _informacoes()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _faixaCombo(),
          const SizedBox(height: 10),
          _caixasCombo(),
          const SizedBox(height: 10),
          _letraMiuda(),
        ],
      ),
    );
  }

  Widget _logoA({double size = 34, Color color = Colors.white}) {
    final barWidth = size * 0.66;
    final barHeight = size * 0.07;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: barWidth, height: barHeight, color: color),
        Text(
          'a',
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w700,
            height: 0.78,
            letterSpacing: -2,
          ),
        ),
        Container(width: barWidth, height: barHeight, color: color),
      ],
    );
  }

  Widget _foto() {
    final path = data.imagemPath.trim();
    if (path.isEmpty) return _semFoto();
    final file = File(path);
    if (!file.existsSync()) return _semFoto();
    return Center(
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _semFoto(),
      ),
    );
  }

  Widget _semFoto() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.smartphone, size: 210, color: Color(0xFFD9D9D9)),
          SizedBox(height: 12),
          Text(
            'imagem do celular',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informacoes() {
    final de = 'R\$ ${_money(data.precoOriginal)}';
    final por = 'R\$ ${_money(data.precoFinal)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.descricao,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 62,
            fontWeight: FontWeight.w700,
            height: 0.98,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'de: $de à vista',
          style: const TextStyle(
            color: _ink,
            fontSize: 30,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'por: ',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: por,
                  style: const TextStyle(
                    fontSize: 78,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2.5,
                  ),
                ),
              ],
            ),
            style: const TextStyle(color: _ink, height: 1),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '+ plano controle',
          style: TextStyle(
            color: _ink,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          '(válido na portabilidade para quaisquer bandeiras*)',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _red, width: 3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              Text(
                'condições válidas também\npara pagamento no pix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.06,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '(consulte opções de parcelamento)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _faixaCombo() {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Text(
        'oferta especial combo*:',
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _caixasCombo() {
    return SizedBox(
      height: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _comboBox(
              white: true,
              children: [
                const Text(
                  'preço sem\ndesconto',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${_money(data.precoOriginal)}',
                  textAlign: TextAlign.center,
                  style: _valor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _comboBox(
              children: [
                const Text(
                  'preço no\nplano controle*',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 4),
                const Text(
                  'desconto de',
                  textAlign: TextAlign.center,
                  style: _subLabel,
                ),
                Text(
                  'R\$ ${_money(data.descontoPortabilidade)}',
                  textAlign: TextAlign.center,
                  style: _valor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text('+', style: _plus),
          const SizedBox(width: 4),
          Expanded(
            child: _comboBox(
              children: [
                const Text(
                  'desconto no\ncartão cliente•a',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.percentualFormatado}% OFF',
                  textAlign: TextAlign.center,
                  style: _valorGrande,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text('+', style: _plus),
          const SizedBox(width: 4),
          Expanded(
            child: _comboBox(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('seguro', style: _label),
                    SizedBox(width: 5),
                    Icon(Icons.security, size: 24, color: _ink),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${_money(data.seguro)}',
                  textAlign: TextAlign.center,
                  style: _valorMedio,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _label = TextStyle(
    color: _ink,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const TextStyle _subLabel = TextStyle(
    color: _ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const TextStyle _valor = TextStyle(
    color: _ink,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );
  static const TextStyle _valorMedio = TextStyle(
    color: _ink,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );
  static const TextStyle _valorGrande = TextStyle(
    color: _ink,
    fontSize: 44,
    fontWeight: FontWeight.w900,
    height: 1.05,
  );
  static const TextStyle _plus = TextStyle(
    color: _ink,
    fontSize: 50,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  Widget _comboBox({bool white = false, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: white ? Colors.white : _boxColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _letraMiuda() {
    const base = TextStyle(
      color: _ink,
      fontSize: 15.5,
      height: 1.26,
      fontWeight: FontWeight.w400,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text: 'Descontos aplicados separadamente e podem ser adquiridos '
                'de forma individual.\n',
          ),
          const TextSpan(
            text: 'O desconto do seguro não está atrelado à venda de nenhum '
                'item e a contratação é opcional.\n',
          ),
          TextSpan(
            text: 'Parcelamento disponível no crédito para todas as bandeiras, '
                'disponível apenas para ${data.descricao}.\n',
          ),
          TextSpan(
            text: 'Desconto do plano controle disponível para portabilidade '
                'para quaisquer bandeiras, consulte planos\ne condições. Ofertas válidas de ${data.ofertaInicio} a ${data.ofertaFim} podendo encerrar sem aviso prévio.',
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _rodape() {
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 145,
            height: 145,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: QrImageView(
              data:
                  'https://play.google.com/store/apps/details?id=amer.papeleta.papeleta63',
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              size: 128,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'baixe\no app!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 58,
              fontWeight: FontWeight.w700,
              height: 0.9,
              letterSpacing: -1.5,
            ),
          ),
          const Spacer(),
          _logoA(size: 100),
        ],
      ),
    );
  }
}
