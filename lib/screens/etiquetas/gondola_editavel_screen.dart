import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/toast_utils.dart';

/// Fonte condensada do rótulo (Helvetica Neue Lt Std 67 Medium Condensed).

String _fmt(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final dec = parts[1];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${buf.toString()},$dec';
}

double _parse(String s) =>
    double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

double _precoAtual(PrintingData d) {
  if (d.displayPrice > 0) return d.displayPrice;
  if (d.unitValue > 0) return d.unitValue;
  if (d.unitQty > 0) return d.unitQty;
  if ((d.promotionalPrice?.value ?? 0) > 0) return d.promotionalPrice!.value;
  return d.price?.value ?? 0;
}

bool _ehLeveGanhe(PrintingData d) => (d.takeAndWin?.qty ?? 0) > 0;
bool _ehParcelado(PrintingData d) =>
    (d.installments?.installmentQuantity ?? 0) > 0;
bool _ehDepor(PrintingData d) {
  final promo = d.promotionalPrice?.value ?? 0;
  final normal = d.price?.value ?? 0;
  return (d.takeAndWin?.qty ?? 0) == 0 &&
      (d.installments?.installmentQuantity ?? 0) == 0 &&
      promo > 0 &&
      promo < normal;
}

bool _ehDeporParcelado(PrintingData d) {
  final promo = d.promotionalPrice?.value ?? 0;
  final normal = d.price?.value ?? 0;
  return (d.installments?.installmentQuantity ?? 0) > 0 &&
      promo > 0 &&
      (normal <= 0 || promo < normal);
}

class GondolaEditavelScreen extends StatefulWidget {
  final List<PrintingData> items;
  final String printerId;
  const GondolaEditavelScreen(
      {super.key, required this.items, required this.printerId});

  
  State<GondolaEditavelScreen> createState() => _GondolaEditavelScreenState();
}

class _GondolaEditavelScreenState extends State<GondolaEditavelScreen> {
  late List<PrintingData> _items = List.from(widget.items);
  final Set<int> _selecionados = {};
  int _index = 0;

  final _descController = TextEditingController();
  final _eanController = TextEditingController();
  final _precoController = TextEditingController();
  final _precoDeController = TextEditingController();
  final _precoPorController = TextEditingController();
  final _unitarioController = TextEditingController();
  final _qtdController = TextEditingController();
  final _precoPromoController = TextEditingController();
  final _quantoFicaController = TextEditingController();
  final _valorAnteriorController = TextEditingController();
  final _precoParceladoController = TextEditingController();
  final _parcelasController = TextEditingController();
  final _valorParcelaController = TextEditingController();

  ui.Image? _templateComum;
  ui.Image? _templatePromocional;
  bool _sending = false;

  
  void initState() {
    super.initState();
    _selecionados.addAll(_items.asMap().keys);
    _loadTemplates();
    _carregar();
  }

  Future<void> _loadTemplates() async {
    _templateComum =
        await _decode('assets/overlays/gondola_comum.png');
    _templatePromocional =
        await _decode('assets/overlays/gondola_promocional.png');
    if (mounted) setState(() {});
  }

  Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  
  void dispose() {
    _descController.dispose();
    _eanController.dispose();
    _precoController.dispose();
    _precoDeController.dispose();
    _precoPorController.dispose();
    _unitarioController.dispose();
    _qtdController.dispose();
    _precoPromoController.dispose();
    _quantoFicaController.dispose();
    _valorAnteriorController.dispose();
    _precoParceladoController.dispose();
    _parcelasController.dispose();
    _valorParcelaController.dispose();
    super.dispose();
  }

  PrintingData get _d => _items[_index];

  void _carregar() {
    final d = _d;
    _descController.text = d.description;
    _eanController.text = d.ean;
    if (_ehLeveGanhe(d)) {
      _unitarioController.text = _fmt(d.price?.value ?? 0);
      _qtdController.text = '${d.takeAndWin?.qty ?? 1}';
      _precoPromoController.text = _fmt(d.takeAndWin?.totalValue ?? 0);
      _quantoFicaController.text = _fmt(d.promotionalPrice?.value ?? 0);
    } else if (_ehParcelado(d)) {
      final normal =
          (d.price?.value ?? 0) > 0 ? d.price!.value : _precoAtual(d);
      _valorAnteriorController.text = _fmt(normal);
      final promo = (d.promotionalPrice?.value ?? 0) > 0
          ? d.promotionalPrice!.value
          : _precoAtual(d);
      _precoParceladoController.text = _fmt(promo);
      _parcelasController.text =
          '${d.installments?.installmentQuantity ?? 1}';
      _valorParcelaController.text =
          _fmt(d.installments?.installmentValue ?? 0);
    } else if (_ehDepor(d)) {
      _precoDeController.text = _fmt(d.price?.value ?? 0);
      _precoPorController.text = _fmt(d.promotionalPrice?.value ?? 0);
    } else {
      _precoController.text = _fmt(d.price?.value ?? 0);
    }
    setState(() {});
  }

  void _salvar() {
    final d = _items[_index];
    final desc = _descController.text.trim();
    final eanEdit = _eanController.text.trim();
    PrintingData novo = d.copyWith(
        description: desc.isNotEmpty ? desc : d.description,
        ean: eanEdit.isNotEmpty ? eanEdit : d.ean);
    if (_ehLeveGanhe(d)) {
      final qty = int.tryParse(_qtdController.text) ?? d.takeAndWin?.qty ?? 1;
      final total =
          _parse(_precoPromoController.text) > 0 ? _parse(_precoPromoController.text) : (d.takeAndWin?.totalValue ?? 0);
      final unit = _parse(_quantoFicaController.text) > 0
          ? _parse(_quantoFicaController.text)
          : (d.promotionalPrice?.value ?? 0);
      final unitario = _parse(_unitarioController.text) > 0
          ? _parse(_unitarioController.text)
          : (d.price?.value ?? 0);
      novo = novo.copyWith(
        price: PriceInfo(
            value: unitario,
            discountPercent: d.price?.discountPercent ?? 0,
            startAt: d.price?.startAt ?? '',
            endAt: d.price?.endAt ?? ''),
        takeAndWin: TakeAndWin(
            discountValue: d.takeAndWin?.discountValue ?? 0,
            qty: qty,
            totalValue: total),
        promotionalPrice: PromotionalPriceInfo(
            value: unit,
            discountPercent: d.promotionalPrice?.discountPercent ?? 0,
            startAt: d.promotionalPrice?.startAt ?? '',
            endAt: d.promotionalPrice?.endAt ?? ''),
        promotionPrice: unit,
        takeAndWinQuantity: qty,
        takeAndWinPrice: unit,
      );
    } else if (_ehParcelado(d)) {
      final valAnterior = _parse(_valorAnteriorController.text) > 0
          ? _parse(_valorAnteriorController.text)
          : ((d.price?.value ?? 0) > 0 ? d.price!.value : _precoAtual(d));
      final preco = _parse(_precoParceladoController.text) > 0
          ? _parse(_precoParceladoController.text)
          : _precoAtual(d);
      final parcelas = int.tryParse(_parcelasController.text) ??
          d.installments?.installmentQuantity ??
          1;
      final valorParcela = _parse(_valorParcelaController.text) > 0
          ? _parse(_valorParcelaController.text)
          : (d.installments?.installmentValue ?? 0);
      novo = novo.copyWith(
        price: PriceInfo(
            value: valAnterior,
            discountPercent: d.price?.discountPercent ?? 0,
            startAt: d.price?.startAt ?? '',
            endAt: d.price?.endAt ?? ''),
        promotionalPrice: PromotionalPriceInfo(
            value: preco,
            discountPercent: d.promotionalPrice?.discountPercent ?? 0,
            startAt: d.promotionalPrice?.startAt ?? '',
            endAt: d.promotionalPrice?.endAt ?? ''),
        installments:
            Installments(installmentQuantity: parcelas, installmentValue: valorParcela),
      );
    } else if (_ehDepor(d)) {
      final de = _parse(_precoDeController.text) > 0
          ? _parse(_precoDeController.text)
          : (d.price?.value ?? 0);
      final por = _parse(_precoPorController.text) > 0
          ? _parse(_precoPorController.text)
          : (d.promotionalPrice?.value ?? 0);
      novo = novo.copyWith(
        price: PriceInfo(
            value: de,
            discountPercent: d.price?.discountPercent ?? 0,
            startAt: d.price?.startAt ?? '',
            endAt: d.price?.endAt ?? ''),
        promotionalPrice: PromotionalPriceInfo(
            value: por,
            discountPercent: d.promotionalPrice?.discountPercent ?? 0,
            startAt: d.promotionalPrice?.startAt ?? '',
            endAt: d.promotionalPrice?.endAt ?? ''),
      );
    } else {
      final preco = _parse(_precoController.text) > 0
          ? _parse(_precoController.text)
          : (d.price?.value ?? 0);
      novo = novo.copyWith(
          price: PriceInfo(
              value: preco,
              discountPercent: d.price?.discountPercent ?? 0,
              startAt: d.price?.startAt ?? '',
              endAt: d.price?.endAt ?? ''));
    }
    _items[_index] = novo;
  }

  Future<void> _enviar() async {
    _salvar();
    final selecionados = _selecionados.toList()..sort();
    if (selecionados.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos uma etiqueta');
      return;
    }
    final lista = selecionados.map((i) => _items[i]).toList();
    setState(() => _sending = true);
    try {
      final storeId =
          SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
      await ApiService(ApiClient.instance.getSlApiService())
          .sendPriceTagsToPrinter(
        storeId,
        widget.printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: lista),
      );
      if (!mounted) return;
      ToastUtils.showSuccess(context, '${lista.length} etiqueta(s) enviada(s)');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ToastUtils.showError(context, 'Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _anterior() {
    _salvar();
    if (_index > 0) {
      setState(() => _index--);
      _carregar();
    }
  }

  void _proximo() {
    _salvar();
    if (_index < _items.length - 1) {
      setState(() => _index++);
      _carregar();
    } else {
      ToastUtils.show(context, 'Última etiqueta');
    }
  }

  
  Widget build(BuildContext context) {
    final d = _d;
    final isLeve = _ehLeveGanhe(d);
    final isParcelado = _ehParcelado(d);
    final isDepor = _ehDepor(d);
    final promocional = isLeve || isParcelado || isDepor;
    final template = promocional ? _templatePromocional : _templateComum;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFF2),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFD7193F),
            foregroundColor: Colors.white,
            centerTitle: true,
            floating: true,
            title: const Text('Edição de gôndola'),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1}/${_items.length}',
                  style: const TextStyle(
                    color: Color(0xFFD7193F),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TemplateHeaderDelegate(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 10),
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: AspectRatio(
                    aspectRatio: 746 / 335,
                    child: template == null
                        ? const Center(child: CircularProgressIndicator())
                        : CustomPaint(
                            painter: _GondolaPreviewPainter(
                              template: template,
                              modo: promocional ? 1 : 0,
                              codigo: d.codSap.isNotEmpty
                                  ? d.codSap
                                  : d.department,
                              ean: _eanController.text.trim().isEmpty
                                  ? d.ean
                                  : _eanController.text.trim(),
                              descricao: _descController.text.trim().isEmpty
                                  ? d.description
                                  : _descController.text.trim().toUpperCase(),
                              cifrao: _cifrao(d),
                              valor: _valor(d),
                              unidade: 'R\$/PCE ${_fmt(d.unitValue)}',
                              promoLinha1: _promoLinha1(d),
                              promoLinha2: _promoLinha2(d),
                            ),
                          ),
                  ),
                ),
              ),
              height: 10 + (MediaQuery.sizeOf(context).width - 40) * 335 / 746,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _campo('DESCRIÇÃO', _descController),
                  _campo('EAN', _eanController,
                      keyboardType: TextInputType.number),
                  if (!isLeve && !isParcelado && !isDepor)
                    _campo('PREÇO (R\$)', _precoController),
                  if (isLeve) ...[
                    _campo('PREÇO UNITÁRIO - AMARELO (R\$)',
                        _unitarioController),
                    _campo('QUANTIDADE (LEVE)', _qtdController),
                    _campo('PREÇO PROMOCIONAL - TOTAL (R\$)',
                        _precoPromoController),
                    _campo('QUANTO FICA (R\$)', _quantoFicaController),
                  ],
                  if (isDepor) ...[
                    _campo('PREÇO DE (R\$)', _precoDeController),
                    _campo('PREÇO POR (R\$)', _precoPorController),
                  ],
                  if (isParcelado) ...[
                    _campo('VALOR ANTERIOR (R\$)', _valorAnteriorController),
                    _campo('PREÇO PROMOCIONAL (R\$)', _precoParceladoController),
                    _campo('Nº DE PARCELAS', _parcelasController),
                    _campo('VALOR DA PARCELA (R\$)', _valorParcelaController),
                  ],
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selecionados.contains(_index),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selecionados.add(_index);
                      } else {
                        _selecionados.remove(_index);
                      }
                    }),
                    title: const Text('Incluir esta etiqueta na impressão'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _botao('ANTERIOR', _anterior),
                      const SizedBox(width: 6),
                      _botao('AVANÇAR', _proximo),
                      const SizedBox(width: 6),
                      _botao(_sending ? 'ENVIANDO...' : 'ENVIAR', _enviar,
                          filled: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cifrao(PrintingData d) {
    if (_ehDepor(d) || _ehDeporParcelado(d)) return 'De R\$';
    return 'R\$';
  }

  String _valor(PrintingData d) {
    if (_ehLeveGanhe(d)) {
      final v = _parse(_unitarioController.text);
      return _fmt(v > 0 ? v : (d.price?.value ?? 0));
    }
    if (_ehParcelado(d)) {
      final v = _parse(_valorAnteriorController.text);
      return _fmt(v > 0
          ? v
          : ((d.price?.value ?? 0) > 0 ? d.price!.value : _precoAtual(d)));
    }
    if (_ehDepor(d)) {
      final v = _parse(_precoDeController.text);
      return _fmt(v > 0 ? v : (d.price?.value ?? 0));
    }
    final v = _parse(_precoController.text);
    return _fmt(v > 0 ? v : (d.price?.value ?? 0));
  }

  String _promoLinha1(PrintingData d) {
    if (_ehLeveGanhe(d)) {
      final qty = int.tryParse(_qtdController.text) ?? d.takeAndWin?.qty ?? 1;
      final total = _parse(_precoPromoController.text) > 0
          ? _parse(_precoPromoController.text)
          : (d.takeAndWin?.totalValue ?? 0);
      return '$qty por R\$ ${_fmt(total)}';
    }
    if (_ehParcelado(d)) {
      if (_ehDeporParcelado(d)) {
        final por = _parse(_precoParceladoController.text) > 0
            ? _parse(_precoParceladoController.text)
            : (d.promotionalPrice?.value ?? 0);
        return 'Por R\$ ${_fmt(por)}';
      }
      final parcelas = int.tryParse(_parcelasController.text) ??
          d.installments?.installmentQuantity ??
          1;
      final valor = _parse(_valorParcelaController.text) > 0
          ? _parse(_valorParcelaController.text)
          : (d.installments?.installmentValue ?? 0);
      return '${parcelas}X de R\$ ${_fmt(valor)}';
    }
    if (_ehDepor(d)) {
      final por = _parse(_precoPorController.text) > 0
          ? _parse(_precoPorController.text)
          : (d.promotionalPrice?.value ?? 0);
      return 'Por R\$ ${_fmt(por)}';
    }
    return '';
  }

  String _promoLinha2(PrintingData d) {
    if (_ehLeveGanhe(d)) {
      final unit = _parse(_quantoFicaController.text) > 0
          ? _parse(_quantoFicaController.text)
          : (d.promotionalPrice?.value ?? 0);
      return 'NA PROMOÇÃO A UND SAIRÁ POR R\$ ${_fmt(unit)}';
    }
    if (_ehParcelado(d)) {
      if (_ehDeporParcelado(d)) {
        final parcelas = int.tryParse(_parcelasController.text) ??
            d.installments?.installmentQuantity ??
            1;
        final valor = _parse(_valorParcelaController.text) > 0
            ? _parse(_valorParcelaController.text)
            : (d.installments?.installmentValue ?? 0);
        return '${parcelas}X de R\$ ${_fmt(valor)}';
      }
      return 'SEM JUROS';
    }
    return '';
  }

  Widget _botao(String label, VoidCallback onPressed, {bool filled = false}) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD7193F),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF757575),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          );
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
    return Expanded(
      child: filled
          ? ElevatedButton(onPressed: _sending ? null : onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }

  Widget _campo(String label, TextEditingController c,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDA1C2E))),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            keyboardType: keyboardType,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GondolaPreviewPainter extends CustomPainter {
  final ui.Image template;
  final int modo;
  final String codigo;
  final String ean;
  final String descricao;
  final String cifrao;
  final String valor;
  final String unidade;
  final String promoLinha1;
  final String promoLinha2;

  const _GondolaPreviewPainter({
    required this.template,
    required this.modo,
    required this.codigo,
    required this.ean,
    required this.descricao,
    required this.cifrao,
    required this.valor,
    required this.unidade,
    required this.promoLinha1,
    required this.promoLinha2,
  });

  // Dimensões e layout — igual ao GondolaPreviewView.kt (minhaloja-kotlin).
  static const double _TW = 746;
  static const double _TH = 335;
  static const double _boxLeft = 361;
  static const double _boxRight = 710;
  static const double _boxCy = 208;
  static const double _boxCx = (_boxLeft + _boxRight) / 2;
  static const double _leftCx = _boxLeft / 2;
  static const double _leftMax = 330;
  static const double _comumMax = 700;
  static const double _boxMax = 325;

  
  double _largura(String text, double size) => (TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr)
        ..layout())
      .width;

  /// Posição X da vírgula de um número alinhado à direita em [rightX].
  double _commaXFromRight(String texto, double rightX, double size) {
    final i = texto.lastIndexOf(',');
    if (i < 0) return rightX - _largura(texto, size) / 2;
    return rightX - _largura(texto.substring(i), size);
  }

  double _ajustarTexto(
      String texto, double maxTam, double minTam, double maxLargura) {
    var tam = maxTam;
    while (tam > minTam) {
      if (_largura(texto, tam) <= maxLargura) return tam;
      tam -= 1;
    }
    return tam;
  }

  double _ajustarValor(String cifrao, String valor, double maxTam,
      double minTam, double maxLargura) {
    var tam = maxTam;
    const gap = 6.0;
    while (tam > minTam) {
      final w = _largura(cifrao, tam) + gap + _largura(valor, tam);
      if (w <= maxLargura) return tam;
      tam -= 1;
    }
    return tam;
  }

  
  void paint(Canvas canvas, Size size) {
    final vw = size.width;
    final vh = size.height;
    if (vw <= 0 || vh <= 0) return;
    final scale = (vw / _TW) < (vh / _TH) ? vw / _TW : vh / _TH;
    final dw = _TW * scale;
    final dh = _TH * scale;
    final ox = (vw - dw) / 2;
    final oy = (vh - dh) / 2;

    canvas.drawImageRect(
        template,
        Rect.fromLTWH(
            0, 0, template.width.toDouble(), template.height.toDouble()),
        Rect.fromLTWH(ox, oy, dw, dh),
        Paint());

    double px(double p) => p * scale;
    double tx(double x) => ox + x * scale;
    double ty(double y) => oy + y * scale;

    void draw(String text, double x, double y, double size, TextAlign align,
        Color color) {
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: px(size),
                fontWeight: FontWeight.bold,
                color: color)),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      final dx = align == TextAlign.center
          ? x - tp.width / 2
          : align == TextAlign.right
              ? x - tp.width
              : x;
      final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, Offset(dx, y - base));
    }

    var valorCommaX = 0.0;

    // Código lateral (SAP) na vertical (promocional: mais ao topo).
    if (codigo.isNotEmpty) {
      final sapY = modo == 1 ? 100.0 : _TH / 2;
      canvas.save();
      canvas.translate(tx(18), ty(sapY));
      canvas.rotate(-1.5708);
      draw(codigo, 0, 0, 22, TextAlign.center, const Color(0xFF000000));
      canvas.restore();
    }

    // EAN
    if (ean.isNotEmpty) {
      draw(ean, tx(_TW / 2), ty(82), 23, TextAlign.center,
          const Color(0xFF000000));
    }
    // Descrição
    if (descricao.isNotEmpty) {
      draw(descricao, tx(_TW / 2), ty(114), 30, TextAlign.center,
          const Color(0xFF000000));
    }

    // Preço à vista (fora da caixa preta)
    if (valor.isNotEmpty) {
      final maxTam = modo == 0 ? 85.0 : 54.0;
      final minTam = modo == 0 ? 40.0 : 26.0;
      final maxLargura = modo == 0 ? _comumMax : _leftMax;
      final tam = _ajustarValor(cifrao, valor, maxTam, minTam, maxLargura);
      final ehDepor = cifrao.startsWith('De R\$');
      final baseline = modo == 0 ? 220.0 : (ehDepor ? _boxCy : 230.0);
      final centroX = modo == 0 ? _TW / 2 : _leftCx;

      if (modo == 1) {
        // R$ perto do SAP (esquerda) e valor grande quase na caixa (direita).
        final temMilhar = valor.contains('.');
        final parteInteira = valor.split(',').first.replaceAll('.', '');
        final maxValor = temMilhar
            ? 60.0
            : (ehDepor || parteInteira.length >= 3 ? 75.0 : 110.0);
        final tamValor = _ajustarTexto(valor, maxValor, 50, 280);
        draw(valor, tx(345), ty(baseline), tamValor, TextAlign.right,
            const Color(0xFF000000));
        valorCommaX = _commaXFromRight(valor, tx(345), px(tamValor));

        final maxCifrao =
            (ehDepor && (temMilhar || parteInteira.length >= 3)) ? 30.0 : 45.0;
        final tamCifrao = _ajustarTexto(cifrao, maxCifrao, 26, 100);
        draw(cifrao, tx(20), ty(baseline), tamCifrao, TextAlign.left,
            const Color(0xFF000000));
      } else {
        final cw = _largura(cifrao, px(tam));
        final vw2 = _largura(valor, px(tam));
        final gap = px(6);
        final total = cw + gap + vw2;
        final startX = tx(centroX) - total / 2;
        draw(cifrao, startX, ty(baseline), tam, TextAlign.left,
            const Color(0xFF000000));
        draw(valor, startX + cw + gap, ty(baseline), tam, TextAlign.left,
            const Color(0xFF000000));
      }
    }

    // R$/PCE + valor unitário (promocional: separados)
    if (unidade.isNotEmpty) {
      if (modo == 1) {
        final idx = unidade.indexOf('R\$/PCE ');
        final numero = idx >= 0 ? unidade.substring(idx + 8).trim() : unidade;
        draw('R\$/PCE', tx(30), ty(262), 15, TextAlign.left,
            const Color(0xFF000000));
        // Alinha a vírgula do valor unitário com a vírgula do valor acima.
        final uAp = numero.contains(',')
            ? numero.substring(numero.lastIndexOf(','))
            : numero;
        final uRight = valorCommaX + _largura(uAp, px(15));
        draw('R\$' + numero, uRight, ty(262), 15, TextAlign.right,
            const Color(0xFF000000));
      } else {
        draw(unidade, tx(_TW / 2), ty(252), 15, TextAlign.center,
            const Color(0xFF000000));
      }
    }

    // Caixa preta (promocional)
    if (modo == 1) {
      if (promoLinha1.isNotEmpty) {
        final tam = _ajustarTexto(promoLinha1, 54, 24, _boxMax);
        draw(promoLinha1, tx(_boxCx), ty(_boxCy), tam, TextAlign.center,
            const Color(0xFFFFE600));
      }
      if (promoLinha2.isNotEmpty) {
        final tam = _ajustarTexto(promoLinha2, 17, 10, _boxMax);
        draw(promoLinha2, tx(_boxCx), ty(252), tam, TextAlign.center,
            const Color(0xFFFFE600));
      }
    }
  }

  
  bool shouldRepaint(covariant _GondolaPreviewPainter old) =>
      old.template != template ||
      old.descricao != descricao ||
      old.valor != valor ||
      old.promoLinha1 != promoLinha1 ||
      old.promoLinha2 != promoLinha2 ||
      old.unidade != unidade ||
      old.cifrao != cifrao ||
      old.codigo != codigo ||
      old.ean != ean ||
      old.modo != modo;
}

class _TemplateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _TemplateHeaderDelegate({required this.child, required this.height});

  
  double get minExtent => height;

  
  double get maxExtent => height;

  
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: height, child: child);
  }

  
  bool shouldRebuild(covariant _TemplateHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}
