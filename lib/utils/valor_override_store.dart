import 'package:flutter/material.dart';

/// Overrides de valores apenas para a sessão atual.
class ValorOverrideStore {
  static final instance = ValorOverrideStore._();
  ValorOverrideStore._();

  /// Chave: EAN.
  final Map<String, Map<String, dynamic>> overrides = {};
}

String _txt(num? v) => v == null ? '' : v.toString().replaceAll('.', ',');

String _txtInt(int? v) => v?.toString() ?? '';

double? _parseD(TextEditingController c) {
  final raw = c.text
      .trim()
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(raw);
}

int? _parseI(TextEditingController c) => int.tryParse(c.text.trim());

/// Abre o editor de valores do badge verde.
/// As edições ficam em [ValorOverrideStore] e valem só nesta sessão.
Future<bool> editarValores(
  BuildContext context, {
  required String ean,
  required String tipo,
  double? price,
  double? promotionPrice,
  int? takeAndWinQuantity,
  double? takeAndWinPrice,
  int? installmentQuantity,
  double? installmentPrice,
}) async {
  final store = ValorOverrideStore.instance.overrides;
  final ov = store[ean] ?? const <String, dynamic>{};

  final priceCtrl =
      TextEditingController(text: _txt(ov['price'] ?? price));
  final promoCtrl = TextEditingController(
      text: _txt(ov['promotionPrice'] ?? promotionPrice));
  final takeQtyCtrl = TextEditingController(
      text: _txtInt(ov['takeAndWinQuantity'] ?? takeAndWinQuantity));
  final takePriceCtrl = TextEditingController(
      text: _txt(ov['takeAndWinPrice'] ?? takeAndWinPrice));
  final instQtyCtrl = TextEditingController(
      text: _txtInt(ov['installmentQuantity'] ?? installmentQuantity));
  final instPriceCtrl = TextEditingController(
      text: _txt(ov['installmentPrice'] ?? installmentPrice));

  final fields = <Widget>[];
  void add(String label, TextEditingController c, {bool integer = false}) {
    fields.add(Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: integer
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    ));
  }

  if (tipo == 'Normal') {
    add('Preço', priceCtrl);
  } else if (tipo == 'Leve e Ganhe') {
    add('Quantidade leve', takeQtyCtrl, integer: true);
    add('Valor total promoção', takePriceCtrl);
    add('Valor unitário promoção', promoCtrl);
    add('Valor unitário', priceCtrl);
  } else if (tipo == 'Parcelado') {
    add('Valor anterior', priceCtrl);
    add('Valor promocional', promoCtrl);
    add('Quantidade da parcela', instQtyCtrl, integer: true);
    add('Valor da parcela', instPriceCtrl);
  } else {
    add('Preço', priceCtrl);
    add('Preço promocional', promoCtrl);
  }

  if (tipo == 'Leve e Ganhe') {
    void syncLeve() {
      final q = int.tryParse(takeQtyCtrl.text.trim());
      final total = _parseD(takePriceCtrl);
      if (q != null && q > 0 && total != null && total > 0) {
        promoCtrl.text = (total / q).toStringAsFixed(2).replaceAll('.', ',');
      }
    }

    takeQtyCtrl.addListener(syncLeve);
    takePriceCtrl.addListener(syncLeve);
  } else if (tipo == 'Parcelado') {
    void syncParcela() {
      final q = int.tryParse(instQtyCtrl.text.trim());
      final promo = _parseD(promoCtrl) ?? _parseD(priceCtrl);
      if (q != null && q > 0 && promo != null && promo > 0) {
        instPriceCtrl.text =
            (promo / q).toStringAsFixed(2).replaceAll('.', ',');
      }
    }

    promoCtrl.addListener(syncParcela);
    priceCtrl.addListener(syncParcela);
    instQtyCtrl.addListener(syncParcela);
  }

  final salvar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Editar valores • $tipo'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SALVAR')),
      ],
    ),
  );

  final controllers = [
    priceCtrl,
    promoCtrl,
    takeQtyCtrl,
    takePriceCtrl,
    instQtyCtrl,
    instPriceCtrl,
  ];
  if (salvar != true) {
    for (final c in controllers) {
      c.dispose();
    }
    return false;
  }

  final novo = <String, dynamic>{};
  final p = _parseD(priceCtrl);
  final promo = _parseD(promoCtrl);
  final tq = _parseI(takeQtyCtrl);
  final tp = _parseD(takePriceCtrl);
  final iq = _parseI(instQtyCtrl);
  final ip = _parseD(instPriceCtrl);
  if (p != null) novo['price'] = p;
  if (promo != null) novo['promotionPrice'] = promo;
  if (tq != null) novo['takeAndWinQuantity'] = tq;
  if (tp != null) novo['takeAndWinPrice'] = tp;
  if (iq != null) novo['installmentQuantity'] = iq;
  if (ip != null) novo['installmentPrice'] = ip;
  store[ean] = novo;
  for (final c in controllers) {
    c.dispose();
  }
  return true;
}
