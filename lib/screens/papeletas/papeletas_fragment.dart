import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/lista_store.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/buscar_anim.dart';
import 'package:minhaloja/widgets/cards.dart';
import 'package:minhaloja/widgets/action_swipe_card.dart';
import 'package:minhaloja/widgets/buscar_botao.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class PapeletasFragment extends StatefulWidget {
  const PapeletasFragment({super.key});

  @override
  State<PapeletasFragment> createState() => _PapeletasFragmentState();
}

class _PapeletasFragmentState extends State<PapeletasFragment>
    with BuscarAnimMixin {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager _session = SessionManager.instance!;

  late String _store;
  late String _startDate;

  bool _loading = false;
  bool _fabNoLugar = false;
  bool _isGerando = false;
  List<PriceSign> _items = [];
  String? _deletingId;

  String _tipo = 'Promocional'; // Comum / Promocional (default Promocional)
  String _modelo = 'Misto'; // Misto / Promocional / Promocional Editável / Comum / Comum Editável / Vencimentos
  String _buscaTipo = 'EAN'; // EAN / SAP / Descrição
  String _size = '4×1'; // 1×1 / 2×1 / 4×1 / 6×1
  int _selectedSpinnerIndex = -1; // Índice do spinner selecionado (-1 = nenhum)

  final TextEditingController _eanController = TextEditingController();
  String _eanHint = 'Digite o EAN';
  TextInputType _eanKeyboardType = TextInputType.number;
  String _colagem = '';

  @override
  void initState() {
    super.initState();
    _store = _session.getUserStore();
    _startDate = _today();
    _loadSaved();
    _carregarColagem();
  }

  @override
  void dispose() {
    _eanController.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _baseHint {
    switch (_buscaTipo) {
      case 'EAN':
        return 'Digite o EAN';
      case 'SAP':
        return 'Digite o SAP';
      default:
        return 'Descrição do item';
    }
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _items = List<PriceSign>.from(await ListaStore.instance.getPapeletas());
    } catch (e) {
      LogHelper.e('Erro ao carregar papeletas', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.savePapeletas(_items);
  }

  void _delete(PriceSign item) {
    if (_deletingId != null) return;
    setState(() => _deletingId = item.id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
        _deletingId = null;
      });
      ListaStore.instance.removePapeleta(item);
    });
  }

  // ---- Helpers (espelho do Kotlin) ----
  bool get _usarMisto => _modelo == 'Misto';
  bool get _usarModeloEditavel => _modelo == 'Promocional Editável';
  bool get _usarComumEditavel => _modelo == 'Normal Editável';
  bool get _usarComumSimples => _modelo == 'Normal';
  bool get _usarVencimentos => _modelo == 'Vencimentos';
  bool get _isModoEditavel =>
      _modelo == 'Promocional Editável' || _modelo == 'Normal Editável';
  // Misto/Comum/Promocional Editável/Comum Editável/Vencimentos abrem preview
  // (o modo Promocional simples foi removido).
  bool get _abrePreview =>
      _usarMisto || _usarComumSimples || _usarModeloEditavel ||
      _usarComumEditavel || _usarVencimentos;

  static String _templatePorMovimento(String? movement) {
    final m = (movement ?? '').toLowerCase();
    if (m == 'de/por') return Constants.signTemplateDepor;
    if (m == 'parcelado') return Constants.signTemplateDeporParcelado;
    return Constants.signTemplateModeloEditavel;
  }

  PapeletaPrintingData _ajustarDadosLeveGanhe(PapeletaPrintingData d) {
    if (d.template != Constants.signTemplateLeveGanheCada) return d;
    final total = Constants.totalLeveGanhe(
        d.promotionPrice, d.takeAndWinPrice, d.takeAndWinQuantity);
    final qty = d.takeAndWinQuantity ?? 0;
    final unitario = (d.takeAndWinPrice != null && d.takeAndWinPrice! > 0)
        ? d.takeAndWinPrice!
        : (qty > 0 ? total / qty : total);
    return d.copyWith(
      template: Constants.signTemplateLeveGanheTotal,
      promotionPrice: unitario,
      takeAndWinPrice: total,
      installmentPrice: null,
      installmentQuantity: null,
    );
  }

  bool _isItemComum(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    if (d.template == 'por_de_parcelado' ||
        d.template == Constants.signTemplateDeporParcelado) return true;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasPromo || hasTW) return false;
    return true;
  }

  bool _isComumElegivel(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    final hasInst =
        d.installmentQuantity != null && d.installmentQuantity! > 0;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasInst && !hasPromo && !hasTW) return (d.price) > 149.99;
    return true;
  }

  // ---- Busca avulsa (ambos os tipos, comportamento "Misto") ----
  Future<void> _addStandalone() async {
    final c = _eanController.text.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, 'Informe um código');
      return;
    }
    setState(() {
      _loading = true;
      _eanHint = 'BUSCANDO...';
    });
    startBuscarAnim();
    try {
      final results = await Future.wait([
        _api.getPriceSignStandalone(_store, Constants.tipoComum,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: _buscaTipo == 'Descrição' ? c : null,
            startDate: _startDate),
        _api.getPriceSignStandalone(_store, Constants.tipoPromocional,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: _buscaTipo == 'Descrição' ? c : null,
            startDate: _startDate),
      ]);
      for (final r in results) {
        for (final it in r.items) {
          final idx = _items.indexWhere((e) => e.id == it.id);
          if (idx >= 0) {
            _items[idx].quantity += 1;
          } else {
            _items.add(it);
          }
        }
      }
      setState(() {});
      if (!mounted) return;
      // Sem toast no scan: só o badge com o contador (atualizado no setState).
      await _persist();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao buscar papeleta', e);
      ToastUtils.showError(context, 'Erro ao buscar papeleta');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _eanHint = _baseHint;
        });
      }
      stopBuscarAnim();
    }
  }

  Future<void> _addByScan() async {
    final r = await Navigator.pushNamed(context, '/barcode');
    if (r is String && r.isNotEmpty) {
      _eanController.text = r;
      await _salvarColagem(r);
      await _addStandalone();
    }
  }

  Future<void> _carregarColagem() async {
    final code = await ListaStore.instance.getColagem();
    if (!mounted) return;
    setState(() => _colagem = code);
  }

  Future<void> _salvarColagem(String code) async {
    setState(() => _colagem = code);
    await ListaStore.instance.setColagem(code);
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (e) {
      LogHelper.e('PapeletasFragment: erro ao copiar para clipboard', e);
    }
  }

  Future<void> _usarColagem() async {
    final code = _colagem.trim();
    if (code.isEmpty) return;
    _eanController.text = code;
    await _addStandalone();
  }

  Widget _buildColagem() {
    if (_colagem.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _usarColagem,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.content_paste,
                      size: 18, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Área de colagem: $_colagem',
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await ListaStore.instance.setColagem('');
                      setState(() => _colagem = '');
                    },
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFFD32F2F)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Impressão ----
  Future<void> _imprimirItem(PriceSign item, int qty) async {
    final signData = item.printingData;
    if (signData == null) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final tamanhoAtual = _size;

    // Promocional Editável em item comum → bloquear (fiel ao MLoja).
    if (_usarModeloEditavel && _isItemComum(item)) {
      ToastUtils.show(context, 'Esta papeleta é do tipo Comum, selecione o modo Comum');
      return;
    }

    // Comum Editável em item promocional → bloquear.
    if (_usarComumEditavel && !_isItemComum(item)) {
      ToastUtils.show(context, 'Esta papeleta é do tipo Promocional, selecione o modo Promocional');
      return;
    }

    // Quantidade = nº de papeletas (no tamanho escolhido), sem travar no
    // limite da grade — a composição distribui em várias páginas.
    final qtd = qty;
    final lista = List.generate(
        qtd,
        (_) => _ajustarDadosLeveGanhe(signData.copyWith(
              template: signData.template ?? _templatePorMovimento(item.movement),
              quantity: 1,
              size: tamanhoAtual,
            )));

    // Todos os modos atuais (Misto/Comum/Editáveis/Vencimentos) → preview → socket.
    if (_abrePreview) {
      await _openPreview(lista, itemToRemove: item);
      return;
    }

    // Fallback: envio direto via API.
    await _send(lista);
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _persist();
  }

  Future<void> _imprimirTodas() async {
    if (_isGerando) return;
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Nenhuma papeleta para imprimir');
      return;
    }
    setState(() => _isGerando = true);
    try {
    final tamanhoAtual = _size;
    final lista = <PapeletaPrintingData>[];
    for (final item in _items) {
      final ehComum = _isItemComum(item);
      if (!_usarMisto && !_usarVencimentos) {
        if (_tipo == 'Normal' && (!ehComum || !_isComumElegivel(item))) continue;
        if (_tipo == 'Promocional' && ehComum) continue;
      }
      // Comum Editável: somente comums.
      if (_usarComumEditavel && !ehComum) continue;
      // Promocional Editável: somente promocionais.
      if (_usarModeloEditavel && ehComum) continue;
      final signData = item.printingData;
      if (signData == null) continue;
      final qtd = item.quantity;
      for (int i = 0; i < qtd; i++) {
        lista.add(_ajustarDadosLeveGanhe(signData.copyWith(
          template: signData.template ?? _templatePorMovimento(item.movement),
          quantity: 1,
          size: tamanhoAtual,
        )));
      }
    }
    if (lista.isEmpty) {
      ToastUtils.show(context,
          _tipo == 'Normal' ? 'Nenhum item do tipo Normal' : 'Nenhum item do tipo Promocional');
      return;
    }

    // Todos os modos atuais (Misto/Comum/Editáveis/Vencimentos) → preview → socket.
    if (_abrePreview) {
      await _openPreview(lista, clearAll: true);
      return;
    }

    // Fallback: envio direto via API.
    await _send(lista);
    setState(() => _items.clear());
    await _persist();
    } finally {
      if (mounted) setState(() => _isGerando = false);
    }
  }

  Future<void> _send(List<PapeletaPrintingData> lista) async {
    setState(() => _loading = true);
    try {
      await _api.sendPriceSigns(
          _store, SendPriceSignRequest(products: lista));
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Papeletas enviadas para impressora');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao enviar papeletas', e);
      ToastUtils.showError(context, 'Erro ao enviar papeletas');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Abre a tela de pré-visualização multi-item (equivalente à
  // ModeloEditavelActivity do Kotlin), que lista TODOS os itens com
  // checkboxes e envia para a impressora ao confirmar.
  Future<void> _openPreview(List<PapeletaPrintingData> lista,
      {PriceSign? itemToRemove, bool clearAll = false}) async {
    if (lista.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final modoEditavel =
        _usarModeloEditavel || _usarComumEditavel || _usarVencimentos;
    final modoVencimentos = _usarVencimentos;
    final semOverlay = false;
    final apiSemOverlay =
        _usarMisto || _usarModeloEditavel || _usarVencimentos;
    final hideGerarPreview = !_usarMisto;
    final result = await Navigator.pushNamed(context, '/modelo_editavel',
        arguments: {
          'items': lista,
          'size': _size,
          'mostrarCheckbox': true,
          'modoEditavel': modoEditavel,
          'modoVencimentos': modoVencimentos,
          'semOverlay': semOverlay,
          'apiSemOverlay': apiSemOverlay,
          'hideGerarPreview': hideGerarPreview,
          'title': modoVencimentos ? 'PAPELETA DE VENCIMENTOS' : null,
        });
    if (!mounted) return;
    if (result == true) {
      if (clearAll) {
        setState(() => _items.clear());
      } else if (itemToRemove != null) {
        setState(() => _items.removeWhere((e) => e.id == itemToRemove.id));
      }
      await _persist();
    }
  }

  Future<void> _limparLista() async {
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Lista já está vazia');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Lista'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _items.clear());
      await _persist();
      ToastUtils.show(context, 'Lista limpa');
    }
  }

  Widget _spinnerBox({
    required int index,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return _SpinnerBoxWidget(
      index: index,
      value: value,
      items: items,
      isSelected: _selectedSpinnerIndex == index,
      onSelected: (idx) => setState(() => _selectedSpinnerIndex = idx),
      onChanged: (v) {
        setState(() => _selectedSpinnerIndex = index);
        onChanged(v);
      },
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    const primaryRed = Color(0xFFD32F2F);
    const labelGrey = Color(0xFF8C9BA5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: primaryRed, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: labelGrey,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: primaryRed, size: 16),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    onChanged: onChanged,
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    const primaryRed = Color(0xFFD32F2F);
    const borderGrey = Color(0xFFE1E5EB);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGrey, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdownItem(
                            icon: Icons.receipt_long,
                            label: 'PAPELETA',
                            value: _tipo,
                            items: const ['Normal', 'Promocional'],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _tipo = v);
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                        Expanded(
                          child: _buildDropdownItem(
                            icon: Icons.tune,
                            label: 'MODO',
                            value: _modelo,
                            items: const [
                              'Misto',
                              'Promocional Editável',
                              'Normal',
                              'Normal Editável',
                              'Vencimentos'
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _modelo = v;
                                if (v == 'Promocional Editável') _tipo = 'Promocional';
                                if (v == 'Normal Editável') _tipo = 'Normal';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: borderGrey),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdownItem(
                            icon: Icons.qr_code,
                            label: 'TIPO',
                            value: _buscaTipo,
                            items: const ['EAN', 'SAP', 'Descrição'],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _buscaTipo = v;
                                _eanHint = v == 'EAN'
                                    ? 'Digite o EAN'
                                    : v == 'SAP'
                                        ? 'Digite o SAP'
                                        : 'Descrição do item';
                                _eanKeyboardType = v == 'Descrição' ? TextInputType.text : TextInputType.number;
                              });
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                        Expanded(
                          child: _buildDropdownItem(
                            icon: Icons.aspect_ratio,
                            label: 'TAMANHO',
                            value: _size,
                            items: const ['1×1', '2×1', '4×1', '6×1'],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _size = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: borderGrey),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF9AA5B1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: TextField(
                                  controller: _eanController,
                                  keyboardType: _eanKeyboardType,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  decoration: InputDecoration(
                                    hintText: _eanHint,
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onSubmitted: (v) => _addStandalone(),
                                ),
                              ),
                            ),
                            BuscarBotao(
                              porDescricao: _buscaTipo == 'Descrição',
                              buscando: buscando,
                              onPressed: _addStandalone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _limparLista,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('LIMPAR LISTA'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isGerando ? null : _imprimirTodas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('IMPRIMIR TODAS'),
                ),
              ),
            ],
          ),
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${_items.length} ${_items.length == 1 ? 'item' : 'itens'} na lista',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0x1A000000),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/icons/pap_avulsa.png',
                color: const Color(0xFFA0A0A0)),
          ),
          const SizedBox(height: 20),
          Text(
            '${_items.length} ${_items.length == 1 ? 'item' : 'itens'} na lista\n\nEscaneie ou digite\npara adicionar à lista',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildFilterBar(),
            _buildColagem(),
            Expanded(
              child: _items.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                          itemCount: _items.length,
                           itemBuilder: (context, index) {
                             final item = _items[index];
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 4),
                               child: SwipeToTrashItem(
                                 key: Key('papeleta_${item.id}'),
                                 onDismissed: () => _delete(item),
                                 child: ClipRRect(
                                   borderRadius: BorderRadius.circular(16),
                                   child: PapeletaCard(
                                     item: item,
                                     onImprimir: (q) => _imprimirItem(item, q),
                                     onRemover: () => _delete(item),
                                     onChangedQuantity: (q) {
                                       item.quantity = q;
                                       _persist();
                                     },
                                   ),
                                 ),
                               ),
                             );
                           },
                        ),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            // Igual ao MLoja: começa um pouco pro lado; 1º clique volta à
            // posição original, 2º clique abre o scanner.
            offset: _fabNoLugar ? Offset.zero : const Offset(0.6, 0),
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFD32F2F),
              onPressed: () {
                if (!_fabNoLugar) {
                  setState(() => _fabNoLugar = true);
                  return;
                }
                _addByScan();
              },
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpinnerBoxWidget extends StatefulWidget {
  final int index;
  final String value;
  final List<String> items;
  final bool isSelected;
  final ValueChanged<int> onSelected;
  final ValueChanged<String?> onChanged;
  const _SpinnerBoxWidget({
    required this.index,
    required this.value,
    required this.items,
    required this.isSelected,
    required this.onSelected,
    required this.onChanged,
  });
  @override
  State<_SpinnerBoxWidget> createState() => _SpinnerBoxWidgetState();
}

class _SpinnerBoxWidgetState extends State<_SpinnerBoxWidget> {
  @override
  Widget build(BuildContext context) {
    final red = const Color(0xFFD32F2F);
    final isActive = widget.isSelected;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? red : Colors.white,
        border: Border.all(color: isActive ? red : const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: widget.value,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          iconEnabledColor: isActive ? Colors.white : Colors.black,
          selectedItemBuilder: (context) {
            return widget.items.map((e) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(e, style: TextStyle(
                  color: isActive ? Colors.white : Colors.black,
                  fontSize: 14,
                )),
              );
            }).toList();
          },
          items: widget.items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.black)),
                  ))
              .toList(),
          onChanged: (v) {
            widget.onChanged(v);
          },
          onTap: () => widget.onSelected(widget.index),
        ),
      ),
    );
  }
}
