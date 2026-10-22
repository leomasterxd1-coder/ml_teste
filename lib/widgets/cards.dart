import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';

const Color _greenCheckbox = Color(0xFF1B5E20);
const Color _red = Color(0xFFD32F2F);
const Color _redBrand = Color(0xFFD81B3A);
const Color _primary = Color(0xFFD7193F);
const Color _cardBorder = Color(0xFFCCCCCC);
const Color _qtyGray = Color(0xFFEDEFF2);
const Color _descDark = Color(0xFF1A1A1A);
const Color _descDark2 = Color(0xFF212121);
const Color _eanGray = Color(0xFF666666);
const Color _eanGray2 = Color(0xFF757575);
const Color _green = Color(0xFF4CAF50);

void _copiarEan(BuildContext context, String ean) {
  Clipboard.setData(ClipboardData(text: ean));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('EAN copiado: $ean'),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
const Color _greenDark = Color(0xFF2E7D32);
const Color _orange = Color(0xFFFF9800);
const Color _grayBadge = Color(0xFF9E9E9E);

String _brl(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final dec = parts[1];
  final grouped = intPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return 'R\$ $grouped,$dec';
}

// Número pt-BR sem símbolo (ex: 63,33), espelha o "%.2f" do Kotlin.
String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

/// Card da home (EtiquetasFragment) -> item_etiqueta.xml
class EtiquetaCard extends StatefulWidget {
  final PriceTag tag;
  final ValueChanged<int> onImprimir;
  final VoidCallback onRemover;
  final ValueChanged<int> onChangedQuantity;
  const EtiquetaCard({
    super.key,
    required this.tag,
    required this.onImprimir,
    required this.onRemover,
    required this.onChangedQuantity,
  });

  @override
  State<EtiquetaCard> createState() => _EtiquetaCardState();
}

class _EtiquetaCardState extends State<EtiquetaCard> {
  late TextEditingController _qty;
  double? _saldo;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.tag.quantity.toString());
    _carregarSaldo();
  }

  Future<void> _carregarSaldo() async {
    try {
      final api = ApiService(ApiClient.instance.getSlApiService());
      final store = ApiClient.instance.sessionManager.getUserStore() ??
          Constants.defaultStore;
      final s = await api.getProductStock(store, ean: widget.tag.ean);
      if (mounted) setState(() => _saldo = s);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant EtiquetaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _qty.text = widget.tag.quantity.toString();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leveGanhe, String? deporValor, String? deporBadge}) _price() {
    final pd = widget.tag.printingData;
    final precoNormal = pd?.price?.value ?? 0.0;
    final precoPromo = pd?.promotionalPrice?.value;
    final take = pd?.takeAndWin;
    final movement = widget.tag.movement.toUpperCase();
    if (take != null && take.qty > 0 && take.totalValue > 0) {
      final totalLeve = (pd?.template == Constants.signTemplateLeveGanheCada &&
                  precoPromo != null && precoPromo > 0)
              ? precoPromo
              : take.totalValue;
      return (leveGanhe: 'Leve ${take.qty} por ${_brl(totalLeve)} | ${_brl(precoNormal)}', deporValor: null, deporBadge: null);
    }
    final inst = pd?.installments;
    final qtdParc = (inst != null && inst.installmentQuantity > 0) ? inst.installmentQuantity : null;
    final valorParc = (inst != null && inst.installmentValue > 0)
        ? inst.installmentValue
        : (pd != null && pd.displayPrice > 0)
            ? pd.displayPrice
            : (pd != null && pd.unitValue > 0)
                ? pd.unitValue
                : (pd != null && pd.unitQty > 0)
                    ? pd.unitQty
                    : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);
    // De/Por + Parcelado: badge combinado (De R$X|Por R$Y|Nx de R$Z).
    if (qtdParc != null && precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De R\$${_num(precoNormal)}|Por R\$${_num(precoPromo)}|${qtdParc}x de R\$${_num(valorParc)}',
        deporBadge: 'parcelado'
      );
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        deporBadge: 'de por'
      );
    }
    // Parcelado só com DADOS de parcela (igual à tela de entrada);
    // movement="Parcelado" sem installments abre como de por.
    if (qtdParc != null) {
      return (
        leveGanhe: null,
        deporValor:
            '${precoNormal > 0 ? _brl(precoNormal) : widget.tag.price} | ${qtdParc}x de R\$${_num(valorParc)}',
        deporBadge: 'parcelado'
      );
    }
    final valor = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
    return (leveGanhe: null, deporValor: valor, deporBadge: 'normal');
  }

  @override
  Widget build(BuildContext context) {
    final p = _price();
    final deptNum = widget.tag.department.split(' -').first.trim();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, (v) => widget.onChangedQuantity(v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.tag.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
                ),
                IconButton(
                  onPressed: () => widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: Image.asset('assets/icons/printer.png',
                      width: 22, height: 22, color: _green),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _copiarEan(context, widget.tag.ean),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 10, color: _eanGray2),
                            children: [
                              TextSpan(
                                  text:
                                      'DEP: $deptNum | EAN: ${widget.tag.ean} / SAP: ${widget.tag.sap}'),
                              if (_saldo != null)
                                TextSpan(
                                  text: ' | SALDO: ${_saldo!.toInt()}',
                                  style: TextStyle(
                                    color:
                                        _saldo! < 0 ? _redBrand : _greenDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (p.leveGanhe != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.leveGanhe!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 6),
                              Container(
                                height: 28,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  border: Border.all(color: _green, width: 1),
                                ),
                                child: const Text('leve e ganhe',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _greenDark)),
                              ),
                            ],
                          ),
                        ),
                      ] else if (p.deporValor != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(p.deporValor!,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                              SizedBox(width: p.deporBadge == 'parcelado' ? 10 : 8),
                              Container(
                                height: 28,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  border: Border.all(color: _green, width: 1),
                                ),
                                child: Text(p.deporBadge!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: (p.deporBadge == 'de por' ||
                                                p.deporBadge == 'parcelado')
                                            ? _orange
                                            : _grayBadge)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card da home (PapeletasFragment) -> item_papeleta.xml
class PapeletaCard extends StatefulWidget {
  final PriceSign item;
  final ValueChanged<int> onImprimir;
  final VoidCallback onRemover;
  final ValueChanged<int> onChangedQuantity;
  const PapeletaCard({
    super.key,
    required this.item,
    required this.onImprimir,
    required this.onRemover,
    required this.onChangedQuantity,
  });

  @override
  State<PapeletaCard> createState() => _PapeletaCardState();
}

class _PapeletaCardState extends State<PapeletaCard> {
  late TextEditingController _qty;
  double? _saldo;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.item.quantity.toString());
    _carregarSaldo();
  }

  Future<void> _carregarSaldo() async {
    try {
      final api = ApiService(ApiClient.instance.getSlApiService());
      final store = ApiClient.instance.sessionManager.getUserStore() ??
          Constants.defaultStore;
      final s = await api.getProductStock(store, ean: widget.item.ean);
      if (mounted) setState(() => _saldo = s);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant PapeletaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _qty.text = widget.item.quantity.toString();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leveGanhe, String? deporValor, String? deporBadge}) _price() {
    final pd = widget.item.printingData;
    final precoNormal = pd?.price ?? 0.0;
    final precoPromo = pd?.promotionPrice;
    final takeQty = (pd?.takeAndWinQuantity != null && pd!.takeAndWinQuantity! > 0)
        ? pd!.takeAndWinQuantity!
        : null;
    final takePrice = (pd?.takeAndWinPrice != null && pd!.takeAndWinPrice! > 0)
        ? pd!.takeAndWinPrice!
        : null;
    final movement = widget.item.movement.toUpperCase();
    if (takeQty != null && takePrice != null) {
      final totalLeve = Constants.totalLeveGanhePorTemplate(
          pd?.template, precoPromo, takePrice, takeQty);
      return (
        leveGanhe: 'Leve $takeQty por ${_brl(totalLeve)} | ${_brl(precoNormal)}',
        deporValor: null,
        deporBadge: null
      );
    }
    final qtdParc = (pd?.installmentQuantity != null && pd!.installmentQuantity! > 0)
        ? pd!.installmentQuantity!
        : null;
    final valorParc = (pd?.installmentPrice != null && pd!.installmentPrice! > 0)
        ? pd!.installmentPrice!
        : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);
    // De/Por + Parcelado: badge combinado.
    if (qtdParc != null && precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De R\$${_num(precoNormal)}|Por R\$${_num(precoPromo)}|${qtdParc}x de R\$${_num(valorParc)}',
        deporBadge: 'parcelado'
      );
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        deporBadge: 'de por'
      );
    }
    // Parcelado só com DADOS de parcela (igual à tela de entrada);
    // movement="Parcelado" sem installments abre como de por.
    if (qtdParc != null) {
      return (
        leveGanhe: null,
        deporValor:
            '${precoNormal > 0 ? _brl(precoNormal) : widget.item.price} | ${qtdParc}x de R\$${_num(valorParc)}',
        deporBadge: 'parcelado'
      );
    }
    final valor = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
    return (leveGanhe: null, deporValor: valor, deporBadge: 'normal');
  }

  @override
  Widget build(BuildContext context) {
    final p = _price();
    final deptNum = widget.item.department.split(' -').first.trim();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, (v) => widget.onChangedQuantity(v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF212121))),
                ),
                IconButton(
                  onPressed: () => widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: Image.asset('assets/icons/printer.png',
                      width: 22, height: 22, color: _green),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _copiarEan(context, widget.item.ean),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 10, color: _eanGray2),
                            children: [
                              TextSpan(
                                  text:
                                      'DEP: $deptNum | EAN: ${widget.item.ean} / SAP: ${widget.item.sap}'),
                              if (_saldo != null)
                                TextSpan(
                                  text: ' | SALDO: ${_saldo!.toInt()}',
                                  style: TextStyle(
                                    color:
                                        _saldo! < 0 ? _redBrand : _greenDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (p.leveGanhe != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.leveGanhe!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 6),
                              Container(
                                height: 28,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  border: Border.all(color: _green, width: 1),
                                ),
                                child: const Text('leve e ganhe',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _greenDark)),
                              ),
                            ],
                          ),
                        ),
                      ] else if (p.deporValor != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(p.deporValor!,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                              SizedBox(width: p.deporBadge == 'parcelado' ? 10 : 8),
                              Container(
                                height: 28,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  border: Border.all(color: _green, width: 1),
                                ),
                                child: Text(p.deporBadge!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: (p.deporBadge == 'de por' ||
                                                p.deporBadge == 'parcelado')
                                            ? _orange
                                            : _grayBadge)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _qtyBox(TextEditingController c, ValueChanged<int> onChange) {
  return SizedBox(
    width: 28,
    height: 28,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _red, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _descDark2),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
        onChanged: (v) {
          if (v.isEmpty) return;
          final n = int.tryParse(v);
          if (n != null) onChange(n.clamp(1, 99));
        },
      ),
    ),
  );
}

/// Card (EtiquetasActivity) -> item_price_tag.xml
class PriceTagCard extends StatefulWidget {
  final PriceTag tag;
  final ValueChanged<bool> onChangedCheckbox;
  final ValueChanged<int> onChangedQuantity;
  const PriceTagCard({
    super.key,
    required this.tag,
    required this.onChangedCheckbox,
    required this.onChangedQuantity,
  });

  @override
  State<PriceTagCard> createState() => _PriceTagCardState();
}

class _PriceTagCardState extends State<PriceTagCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.tag.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant PriceTagCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _qty.text = widget.tag.quantity.toString();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String badge, Color badgeColor, String? promo, String? price}) _badge() {
    final pd = widget.tag.printingData;
    final precoNormal = pd?.price?.value ?? 0.0;
    final precoPromo = pd?.promotionalPrice?.value;
    final take = pd?.takeAndWin;
    final movement = widget.tag.movement.toUpperCase();
    if (movement.contains('LEVE') || movement.contains('GANHE')) {
      String? promo;
      if (take != null && take.qty > 0 && take.totalValue > 0) {
        final totalLeve = (pd?.template == Constants.signTemplateLeveGanheCada &&
                    precoPromo != null && precoPromo > 0)
                ? precoPromo
                : take.totalValue;
        promo = 'Leve ${take.qty} por ${_brl(totalLeve)} | ${_brl(precoNormal)}';
      }
      final price = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
      return (badge: 'LEVE E GANHE', badgeColor: _green, promo: promo, price: price);
    }
    final inst = pd?.installments;
    final qtdParc = (inst != null && inst.installmentQuantity > 0) ? inst.installmentQuantity : null;
    final valorParc = (inst != null && inst.installmentValue > 0)
        ? inst.installmentValue
        : (pd != null && pd.displayPrice > 0)
            ? pd.displayPrice
            : (pd != null && pd.unitValue > 0)
                ? pd.unitValue
                : (pd != null && pd.unitQty > 0)
                    ? pd.unitQty
                    : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);
    // De/Por + Parcelado: badge combinado.
    if (qtdParc != null && precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        badge: 'PARCELADO',
        badgeColor: _orange,
        promo: 'De R\$${_num(precoNormal)}|Por R\$${_num(precoPromo)}|${qtdParc}x de R\$${_num(valorParc)}',
        price: null
      );
    }
    if (movement.contains('DE') ||
        movement.contains('POR') ||
        movement.contains('PROMOCIONAL')) {
      String? promo;
      if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
        promo = 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}';
      }
      return (badge: 'DE/POR', badgeColor: _orange, promo: promo, price: null);
    }
    // Parcelado só com DADOS de parcela (igual à tela de entrada);
    // movement="Parcelado" sem installments abre como de por.
    if (qtdParc != null) {
      return (
        badge: 'PARCELADO',
        badgeColor: _orange,
        promo:
            '${precoNormal > 0 ? _brl(precoNormal) : widget.tag.price} | ${qtdParc}x de R\$${_num(valorParc)}',
        price: null
      );
    }
    final price = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
    return (badge: 'NORMAL', badgeColor: _grayBadge, promo: null, price: price);
  }

  Widget _statusBadge() {
    final s = widget.tag.status.toUpperCase();
    if (s == 'IMPRESSA') return _Badge('IMPRESSA', _green);
    if (s == 'NÃO IMPRESSA' || s == 'NAO IMPRESSA')
      return _Badge('NÃO IMPRESSA', _redBrand);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final b = _badge();
    final showPrice = b.price != null;
    final showPromo = b.promo != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.tag.checkbox,
                  activeColor: _greenCheckbox,
                  onChanged: (v) => widget.onChangedCheckbox(v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.tag.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _descDark)),
                ),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _qtyGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _qty,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: _descDark),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                      onChanged: (v) {
                        if (v.isEmpty) return;
                        final n = int.tryParse(v);
                        if (n != null) widget.onChangedQuantity(n.clamp(1, 99));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _copiarEan(context, widget.tag.ean),
                    child: Text(
                      'EAN: ${widget.tag.ean} • Dep: ${widget.tag.department}',
                      style: const TextStyle(fontSize: 10, color: _eanGray),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(),
              ],
            ),
            if (showPromo || showPrice) ...[
              const SizedBox(height: 4),
              Container(
                height: 28,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(showPromo ? b.promo! : b.price!,
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12)),
                        border: Border.all(color: _green, width: 1),
                      ),
                      child: Text(b.badge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.badgeColor)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Container(
                height: 28,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.badge,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card (PapeletasDiariasActivity) -> item_papeleta_diaria.xml
class PapeletaDiariaCard extends StatefulWidget {
  final PriceSign item;
  final ValueChanged<bool> onChangedCheckbox;
  final ValueChanged<int> onChangedQuantity;
  const PapeletaDiariaCard({
    super.key,
    required this.item,
    required this.onChangedCheckbox,
    required this.onChangedQuantity,
  });

  @override
  State<PapeletaDiariaCard> createState() => _PapeletaDiariaCardState();
}

class _PapeletaDiariaCardState extends State<PapeletaDiariaCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant PapeletaDiariaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qty.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String badge, Color badgeColor, String? promo, String? price}) _badge() {
    final pd = widget.item.printingData;
    final precoNormal = pd?.price ?? 0.0;
    final precoPromo = pd?.promotionPrice;
    final takeQty = (pd?.takeAndWinQuantity != null && pd!.takeAndWinQuantity! > 0)
        ? pd!.takeAndWinQuantity!
        : null;
    final takePrice = (pd?.takeAndWinPrice != null && pd!.takeAndWinPrice! > 0)
        ? pd!.takeAndWinPrice!
        : null;
    final movement = widget.item.movement.toUpperCase();
    if (movement.contains('LEVE') || movement.contains('GANHE')) {
      String? promo;
      if (takeQty != null && takePrice != null) {
        final totalLeve = Constants.totalLeveGanhePorTemplate(
            pd?.template, precoPromo, takePrice, takeQty);
        promo = 'Leve $takeQty por ${_brl(totalLeve)} | ${_brl(precoNormal)}';
      }
      final price = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
      return (badge: 'LEVE E GANHE', badgeColor: _green, promo: promo, price: price);
    }
    final qtdParc = (pd?.installmentQuantity != null && pd!.installmentQuantity! > 0)
        ? pd!.installmentQuantity!
        : null;
    final valorParc = (pd?.installmentPrice != null && pd!.installmentPrice! > 0)
        ? pd!.installmentPrice!
        : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);
    // De/Por + Parcelado: badge combinado.
    if (qtdParc != null && precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        badge: 'PARCELADO',
        badgeColor: _orange,
        promo:
            'De R\$${_num(precoNormal)}|Por R\$${_num(precoPromo)}|${qtdParc}x de R\$${_num(valorParc)}',
        price: null
      );
    }
    if (movement.contains('DE') ||
        movement.contains('POR') ||
        movement.contains('PROMOCIONAL')) {
      String? promo;
      if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
        promo = 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}';
      }
      return (badge: 'DE/POR', badgeColor: _orange, promo: promo, price: null);
    }
    // Parcelado só com DADOS de parcela (igual à tela de entrada);
    // movement="Parcelado" sem installments abre como de por.
    if (qtdParc != null) {
      final por = (precoPromo != null && precoPromo > 0) ? precoPromo : null;
      String? promo;
      if (por != null && valorParc > 0) {
        promo = 'R\$${_num(por)} | ${qtdParc}x de R\$${_num(valorParc)}';
      } else {
        promo =
            '${precoNormal > 0 ? _brl(precoNormal) : widget.item.price} | ${qtdParc}x de R\$${_num(valorParc)}';
      }
      return (badge: 'PARCELADO', badgeColor: _orange, promo: promo, price: null);
    }
    final price = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
    return (badge: 'COMUM', badgeColor: _grayBadge, promo: null, price: price);
  }

  Widget _statusBadge() {
    final s = widget.item.status.toUpperCase();
    if (s == 'IMPRESSA') return _Badge('IMPRESSA', _green);
    if (s == 'NÃO IMPRESSA' || s == 'NAO IMPRESSA')
      return _Badge('NÃO IMPRESSA', _redBrand);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final b = _badge();
    final showPrice = b.price != null;
    final showPromo = b.promo != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.item.checkbox,
                  activeColor: _greenCheckbox,
                  onChanged: (v) => widget.onChangedCheckbox(v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.item.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _descDark)),
                ),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _qtyGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _qty,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: _descDark),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                      onChanged: (v) {
                        if (v.isEmpty) return;
                        final n = int.tryParse(v);
                        if (n != null) widget.onChangedQuantity(n.clamp(1, 99));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _copiarEan(context, widget.item.ean),
                    child: Text(
                      'EAN: ${widget.item.ean} • Dep: ${widget.item.department}',
                      style: const TextStyle(fontSize: 10, color: _eanGray),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(),
              ],
            ),
            if (showPromo || showPrice) ...[
              const SizedBox(height: 4),
              Container(
                height: 28,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(showPromo ? b.promo! : b.price!,
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12)),
                        border: Border.all(color: _green, width: 1),
                      ),
                      child: Text(b.badge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.badgeColor)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Container(
                height: 28,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.badge,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
