import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:barcode/barcode.dart';
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

/// De/Por + Parcelado combinado (mostra "EM ATÉ" acima do parcelamento).
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
  final bool barcode;
  const GondolaEditavelScreen(
      {super.key,
      required this.items,
      required this.printerId,
      this.barcode = false});

  
  State<GondolaEditavelScreen> createState() => _GondolaEditavelScreenState();
}

class _GondolaEditavelScreenState extends State<GondolaEditavelScreen> {
  late List<PrintingData> _items = List.from(widget.items);
  final Set<int> _selecionados = {};
  int _index = 0;

  final _descController = TextEditingController();
  final _eanController = TextEditingController();
  final _sapController = TextEditingController();
  final _precoController = TextEditingController();
  final _precoDeController = TextEditingController();
  final _precoPorController = TextEditingController();
  final _unitarioController = TextEditingController();
  final _qtdController = TextEditingController();
  final _precoPromoController = TextEditingController();
  final _quantoFicaController = TextEditingController();
  final _precoParceladoController = TextEditingController();
  final _parcelasController = TextEditingController();
  final _valorParcelaController = TextEditingController();

  ui.Image? _templateComum;
  ui.Image? _templatePromocional;
  bool _sending = false;

  
  void initState() {
    super.initState();
    _parcelasController.addListener(_recalcularParcela);
    _precoParceladoController.addListener(_recalcularParcela);
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
    _sapController.dispose();
    _precoController.dispose();
    _precoDeController.dispose();
    _precoPorController.dispose();
    _unitarioController.dispose();
    _qtdController.dispose();
    _precoPromoController.dispose();
    _quantoFicaController.dispose();
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
    _sapController.text = d.codSap.isNotEmpty ? d.codSap : d.department;
    if (_ehLeveGanhe(d)) {
      _unitarioController.text = _fmt(d.price?.value ?? 0);
      _qtdController.text = '${d.takeAndWin?.qty ?? 1}';
      _precoPromoController.text = _fmt(d.takeAndWin?.totalValue ?? 0);
      _quantoFicaController.text = _fmt(d.promotionalPrice?.value ?? 0);
    } else if (_ehParcelado(d)) {
      _precoParceladoController.text = _fmt(_precoAtual(d));
      _parcelasController.text =
          '${d.installments?.installmentQuantity ?? 1}';
    } else if (_ehDepor(d)) {
      _precoDeController.text = _fmt(d.price?.value ?? 0);
      _precoPorController.text = _fmt(d.promotionalPrice?.value ?? 0);
    } else {
      _precoController.text = _fmt(d.price?.value ?? 0);
    }
    setState(() {});
  }

  void _recalcularParcela() {
    final parcelas = int.tryParse(_parcelasController.text) ?? 0;
    final preco = _parse(_precoParceladoController.text);
    if (parcelas > 0 && preco > 0) {
      _valorParcelaController.text = _fmt(preco / parcelas);
    }
  }

  void _salvar() {
    final d = _items[_index];
    final desc = _descController.text.trim();
    final eanEdit = _eanController.text.trim();
    PrintingData novo = d.copyWith(
        description: desc.isNotEmpty ? desc : d.description,
        ean: eanEdit.isNotEmpty ? eanEdit : d.ean,
        codSap: _sapController.text.trim().isNotEmpty
            ? _sapController.text.trim()
            : d.codSap);
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
    if (widget.barcode) {
      novo = novo.copyWith(template: Constants.signTemplateCodigoBarras);
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
    final template = widget.barcode
        ? _templateComum
        : (promocional ? _templatePromocional : _templateComum);

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
                  constraints: const BoxConstraints(),
                  child: AspectRatio(
                    aspectRatio: 746 / 335,
                    child: template == null
                        ? const Center(child: CircularProgressIndicator())
                        : CustomPaint(
                            painter: _GondolaPreviewPainter(
                              template: template,
                              modo: widget.barcode ? 0 : (promocional ? 1 : 0),
                              barcode: widget.barcode,
                              codigo: _sapController.text.trim().isEmpty
                                  ? (d.codSap.isNotEmpty
                                      ? d.codSap
                                      : d.department)
                                  : _sapController.text.trim(),
                              ean: _eanController.text.trim().isEmpty
                                  ? d.ean
                                  : _eanController.text.trim(),
                              descricao: _descController.text.trim().isEmpty
                                  ? d.description
                                  : _descController.text.trim().toUpperCase(),
                              cifrao: _cifrao(d),
                              valor: _valor(d),
                              unidade: 'R\$/PCE ${_fmt(d.unitValue)}',
                              promoLinha0: _promoLinha0(d),
                              promoLinha1: _promoLinha1(d),
                              promoLinha2: _promoLinha2(d),
                              leveGanhe: _ehLeveGanhe(d),
                            ),
                          ),
                  ),
                ),
              ),
              height: 10 + MediaQuery.sizeOf(context).width * 335 / 746,
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
                  _campo('SAP', _sapController,
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
                    _campo('PREÇO (R\$)', _precoParceladoController),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _badge('ANTERIOR',
                          'assets/icons/ic_gondola_previous.svg', _anterior),
                      const SizedBox(width: 12),
                      _badge('AVANÇAR',
                          'assets/icons/ic_gondola_next.svg', _proximo),
                      const SizedBox(width: 12),
                      _badge(
                          _sending ? 'ENVIANDO...' : 'ENVIAR',
                          'assets/icons/ic_gondola_send.svg',
                          _sending ? null : _enviar),
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
    if (_ehDepor(d)) return 'De R\$';
    return 'R\$';
  }

  String _valor(PrintingData d) {
    if (_ehLeveGanhe(d)) {
      final v = _parse(_unitarioController.text);
      return _fmt(v > 0 ? v : (d.price?.value ?? 0));
    }
    if (_ehParcelado(d)) {
      final v = _parse(_precoParceladoController.text);
      return _fmt(v > 0 ? v : _precoAtual(d));
    }
    if (_ehDepor(d)) {
      final v = _parse(_precoDeController.text);
      return _fmt(v > 0 ? v : (d.price?.value ?? 0));
    }
    final v = _parse(_precoController.text);
    return _fmt(v > 0 ? v : (d.price?.value ?? 0));
  }

  String _promoLinha0(PrintingData d) {
    if (_ehDeporParcelado(d) || _ehParcelado(d)) return 'EM ATÉ';
    return '';
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
      final parcelas = int.tryParse(_parcelasController.text) ??
          d.installments?.installmentQuantity ??
          1;
      final valor = _parse(_valorParcelaController.text) > 0
          ? _parse(_valorParcelaController.text)
          : (d.installments?.installmentValue ?? 0);
      return '${parcelas}x de R\$ ${_fmt(valor)}';
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
    if (_ehParcelado(d)) return 'SEM JUROS';
    return '';
  }

  Widget _badge(String label, String icon, VoidCallback? onPressed) {
    return Material(
      color: const Color(0xFFC62828),
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(icon, width: 20, height: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
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
  final bool barcode;
  final String codigo;
  final String ean;
  final String descricao;
  final String cifrao;
  final String valor;
  final String unidade;
  final String promoLinha0;
  final String promoLinha1;
  final String promoLinha2;
  final bool leveGanhe;

  const _GondolaPreviewPainter({
    required this.template,
    required this.modo,
    required this.barcode,
    required this.codigo,
    required this.ean,
    required this.descricao,
    required this.cifrao,
    required this.valor,
    required this.unidade,
    required this.promoLinha0,
    required this.promoLinha1,
    required this.promoLinha2,
    this.leveGanhe = false,
  });

  // Dimensões e layout — igual ao GondolaPreviewView.kt (minhaloja-kotlin).
  static const double _TW = 746;
  static const double _TH = 335;
  static const double _boxLeft = 361;
  static const double _boxRight = 710;
  static const double _boxCy = 208;
  static const double _boxCx = (_boxLeft + _boxRight) / 2;
  static const double _leftCx = _boxLeft / 2;
  static const double _boxMax = 325;

  double _largura(String text, double size, {String? fontFamily}) =>
      (TextPainter(
              text: TextSpan(
                  text: text,
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: size,
                      fontWeight: FontWeight.bold)),
              textDirection: TextDirection.ltr)
            ..layout())
          .width;

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
              fontFamily: 'HelveticaNeueCondensed',
              fontSize: px(size),
              fontWeight: FontWeight.bold,
              color: color),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout();
      final left = align == TextAlign.center
          ? x - tp.width / 2
          : (align == TextAlign.right ? x - tp.width : x);
      final base =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, Offset(left, y - base));
    }

    /// Desenha mantendo a altura e comprimindo só a largura se passar de [maxLargura].
    double drawEscalado(String text, double x, double y, double size,
        TextAlign align, Color color, double maxLargura) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: 'HelveticaNeueCondensed',
              fontSize: px(size),
              fontWeight: FontWeight.bold,
              color: color),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout();
      final base =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final sx = tp.width > maxLargura ? maxLargura / tp.width : 1.0;
      final left = align == TextAlign.right
          ? -tp.width
          : (align == TextAlign.center ? -tp.width / 2 : 0.0);
      canvas.save();
      canvas.translate(x, y - base);
      canvas.scale(sx, 1.0);
      tp.paint(canvas, Offset(left, 0));
      canvas.restore();
      return tp.width * sx;
    }

    /// Igual ao drawEscalado, mas desenha a vírgula com 97% do tamanho.
    double drawValor(String text, double x, double y, double size,
        TextAlign align, Color color, double maxLargura) {
      final base = TextStyle(
          fontFamily: 'HelveticaNeueCondensed',
          fontSize: px(size),
          fontWeight: FontWeight.bold,
          color: color);
      final partes = text.split(',');
      final spans = <InlineSpan>[];
      if (partes.length == 2) {
        spans.add(TextSpan(text: partes[0], style: base));
        spans.add(TextSpan(
            text: ',', style: base.copyWith(fontSize: px(size) * 0.90)));
        spans.add(TextSpan(text: partes[1], style: base));
      } else {
        spans.add(TextSpan(text: text, style: base));
      }
      final tp = TextPainter(
        text: TextSpan(children: spans),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout();
      final baseY =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final sx = tp.width > maxLargura ? maxLargura / tp.width : 1.0;
      final left = align == TextAlign.right
          ? -tp.width
          : (align == TextAlign.center ? -tp.width / 2 : 0.0);
      canvas.save();
      canvas.translate(x, y - baseY);
      canvas.scale(sx, 1.0);
      tp.paint(canvas, Offset(left, 0));
      canvas.restore();
      return tp.width * sx;
    }

    var larguraValorPx = 0.0;
    final ehDepor = cifrao.startsWith('De R\$');

    // Os dois valores usam o mesmo tamanho (110) e a mesma largura máxima;
    // se o texto for maior que isso, só ele é comprimido na largura.
    const double valorMaxW = 243.0;
    final porValor =
        ehDepor ? promoLinha1.replaceFirst('Por R\$', '').trim() : '';

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

    var comumValorW = 0.0;
    var comumCifraoX = _TW / 2;

    // Preço à vista
    if (valor.isNotEmpty) {
      final cifraoDraw = cifrao;
      final tam = modo == 0 ? 110.0 : 54.0;
      final baseline =
          modo == 0 ? 240.0 : (ehDepor ? _boxCy + 38 : 230.0);
      final centroX = modo == 0 ? _TW / 2 - 80 : _leftCx;

      if (modo == 1) {
        if (barcode) {
          _desenharBarcode(canvas, tx(_boxLeft + 10), ty(_boxCy - 45), 300.0);
          larguraValorPx = px(300);
        } else {
          larguraValorPx = drawValor(valor, tx(345), ty(baseline), 110.0,
              TextAlign.right, const Color(0xFF000000),
              px(leveGanhe ? 275.0 : valorMaxW));
        }
        final maxCifrao = ehDepor ? 30.0 : 45.0;
        final tamCifrao = _ajustarTexto(cifraoDraw, maxCifrao, 26, 100);
        draw(cifraoDraw, tx(20), ty(baseline), tamCifrao, TextAlign.left,
            const Color(0xFF000000));
      } else {
        final cifraoW = _largura(cifraoDraw, px(tam)) / scale;
        double valorW;
        if (barcode) {
          final bw = _largura(valor, px(tam));
          _desenharBarcode(
              canvas, tx(_TW - 30) - bw, ty(_boxCy - 45), bw);
          valorW = bw / scale;
        } else {
          final valorWpx = drawEscalado(valor, tx(_TW - 30), ty(baseline), tam,
              TextAlign.right, const Color(0xFF000000), px(240));
          valorW = valorWpx / scale;
        }
        final valorLeft = (_TW - 30) - valorW;
        final cifraoCenterMax = valorLeft - 10 - cifraoW / 2;
        final cifraoX = cifraoCenterMax < centroX ? cifraoCenterMax : centroX;
        draw(cifraoDraw, tx(cifraoX), ty(baseline), tam, TextAlign.center,
            const Color(0xFF000000));
        comumValorW = valorW;
        comumCifraoX = cifraoX;
      }
    }

    // R$/PCE + valor unitário (promocional: separados).
    if (unidade.isNotEmpty) {
      if (modo == 1) {
        final numero = unidade.split('R\$/PCE ').last.trim();
        draw('R\$/PCE', tx(20), ty(290), 15, TextAlign.left,
            const Color(0xFF000000));
        draw('R\$' + numero, tx(345) - larguraValorPx / 2, ty(290), 15,
            TextAlign.center, const Color(0xFF000000));
      } else {
        final numero = unidade.split('R\$/PCE ').last.trim();
        draw('R\$/PCE', tx(comumCifraoX), ty(290), 15, TextAlign.center,
            const Color(0xFF000000));
        draw('R\$' + numero, tx(_TW - 30) - comumValorW / 2, ty(290), 15,
            TextAlign.center, const Color(0xFF000000));
      }
    }

    // Caixa preta (promocional)
    if (modo == 1) {
      final ehParc = promoLinha0 == 'EM ATÉ';
      if (promoLinha0.isNotEmpty) {
        final t0 = _ajustarTexto(promoLinha0, 17, 10, _boxMax);
        draw(promoLinha0, tx(_boxCx), ty(_boxCy - 44), t0, TextAlign.center,
            const Color(0xFFFFFFFF));
      }
      if (ehDepor && promoLinha1.isNotEmpty) {
        // "Por R$" no mesmo tamanho do "De R$" e valor no mesmo tamanho do
        // valor do lado amarelo (mesma fonte e mesma largura máxima).
        if (porValor.isNotEmpty) {
          const rotuloTam = 30.0;
          final esquerda = _boxLeft + 12;
          final direita = _boxRight - 10;
          final baseBox = _boxCy + 38;
          drawValor(porValor, tx(direita), ty(baseBox), 110.0,
              TextAlign.right, const Color(0xFFFFFFFF), px(valorMaxW));
          draw('Por R\$', tx(esquerda), ty(baseBox), rotuloTam,
              TextAlign.left, const Color(0xFFFFFFFF));
        }
      } else if (promoLinha1.isNotEmpty) {
        drawEscalado(promoLinha1, tx(_boxCx),
            ty(ehParc ? _boxCy + 22 : _boxCy + 12), 75.0, TextAlign.center,
            const Color(0xFFFFFFFF), px(310));
      }
      if (promoLinha2.isNotEmpty) {
        final t2 = _ajustarTexto(promoLinha2, 17, 10, _boxMax);
        draw(promoLinha2, tx(_boxCx), ty(ehParc ? 268 : 252), t2,
            TextAlign.center, const Color(0xFFFFFFFF));
      }
    }
  }

  void _desenharBarcode(Canvas canvas, double x, double y, double largura) {
    if (ean.isEmpty || largura <= 0) return;
    final elems = Barcode.code128()
        .make(ean, width: largura, height: largura * 90 / 620);
    for (final el in elems) {
      if (el is! BarcodeBar || !el.black) continue;
      canvas.drawRect(
          Rect.fromLTWH(x + el.left, y + el.top, el.width, el.height),
          Paint()..color = const Color(0xFF000000));
    }
  }

  bool shouldRepaint(covariant _GondolaPreviewPainter old) =>
      old.template != template ||
      old.barcode != barcode ||
      old.descricao != descricao ||
      old.valor != valor ||
      old.promoLinha0 != promoLinha0 ||
      old.promoLinha1 != promoLinha1 ||
      old.promoLinha2 != promoLinha2 ||
      old.unidade != unidade ||
      old.cifrao != cifrao ||
      old.codigo != codigo ||
      old.ean != ean ||
      old.leveGanhe != leveGanhe ||
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
