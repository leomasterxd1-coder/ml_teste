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
import 'package:minhaloja/utils/price_tag_mapper.dart';
import 'package:minhaloja/screens/barcode/barcode_scanner_screen.dart';
import 'package:minhaloja/widgets/cards.dart';
import 'package:minhaloja/widgets/action_swipe_card.dart';
import 'package:minhaloja/widgets/buscar_botao.dart';
import 'package:minhaloja/services/lista_pdf_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

  String _formatToday() {
    final d = DateTime.now();
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

class EtiquetasFragment extends StatefulWidget {
  const EtiquetasFragment({super.key});

  @override
  State<EtiquetasFragment> createState() => _EtiquetasFragmentState();
}

class _EtiquetasFragmentState extends State<EtiquetasFragment>
    with BuscarAnimMixin {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());

  late final String _storeId;
  late final String _today;

  List<PriceTag> _tags = [];

  bool _loading = false;
  bool _fabNoLugar = false;

  final TextEditingController _eanController = TextEditingController();
  final FocusNode _eanFocus = FocusNode();
  String _buscaTipo = 'EAN';
   String _eanHint = 'Digite um EAN';
  TextInputType _eanKeyboardType = TextInputType.number;
   String _printer = 'Zebra 1';
   String _modo = 'Normal';
   bool _imprimindo = false;
   bool _limpando = false;
   String? _deletingId;
  String _colagem = '';

  String get _baseHint {
    switch (_buscaTipo) {
      case 'EAN':
        return 'Digite um EAN';
      case 'SAP':
        return 'Digite um SAP';
      default:
        return 'Descrição do item';
    }
  }

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    _today = _formatToday();
    _loadSaved();
    _carregarColagem();
    // Ao focar o campo, limpa o código escaneado para digitação manual.
    _eanFocus.addListener(() {
      if (_eanFocus.hasFocus && _eanController.text.isNotEmpty) {
        _eanController.clear();
      }
    });
  }

  @override
  void dispose() {
    _eanFocus.dispose();
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _tags = List<PriceTag>.from(await ListaStore.instance.getEtiquetas());
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.saveEtiquetas(_tags);
  }

  void _deleteTag(PriceTag tag) {
    if (_deletingId != null) return;
    setState(() => _deletingId = tag.id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _tags.removeWhere((e) => e.id == tag.id);
        _deletingId = null;
      });
      ListaStore.instance.removeEtiqueta(tag);
    });
  }

  Future<void> _addByScan() async {
    // Scanner contínuo: adiciona os itens direto na lista, com bip; ao voltar,
    // recarrega a lista salva (sem sair da câmera a cada leitura).
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(continuo: true)),
    );
    await _loadSaved();
    await _carregarColagem();
  }

  Future<void> _carregarColagem() async {
    final code = await ListaStore.instance.getColagem();
    if (!mounted) return;
    setState(() => _colagem = code);
  }

  Future<void> _salvarColagem(String code) async {
    setState(() => _colagem = code);
    await ListaStore.instance.setColagem(code);
    // Copia para a área de transferência, como no app Kotlin.
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao copiar para clipboard', e);
    }
  }

  Future<void> _usarColagem() async {
    final code = _colagem.trim();
    if (code.isEmpty) return;
    _eanController.text = code;
    await _fetchAndAdd(code);
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

  Future<void> _fetchAndAdd(String code) async {
    final c = code.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, 'Digite um código');
      return;
    }
    setState(() {
      _loading = true;
      _eanHint = 'BUSCANDO...';
    });
    startBuscarAnim();
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: _buscaTipo == 'EAN' ? c : null,
        sapId: _buscaTipo == 'SAP' ? c : null,
        description: _buscaTipo == 'Descrição' ? c : null,
        startDate: _today,
      );
      if (!mounted) return;
      if (resp.items.isEmpty) {
        ToastUtils.showInfo(context, 'Nenhuma etiqueta encontrada');
        setState(() {
          _loading = false;
          _eanHint = _baseHint;
        });
        return;
      }
      int added = 0;
      int incremented = 0;
      for (final item in resp.items) {
        final idx = _tags.indexWhere((t) => t.ean == item.ean);
        if (idx >= 0) {
          _tags[idx].quantity += 1;
          incremented++;
        } else {
          _tags.add(singleToPriceTag(item));
          added++;
        }
      }
      setState(() {});
      await _persist();
      ToastUtils.showSuccess(
          context, '$added adicionado(s) | $incremented incrementado(s)');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao adicionar', e);
      ToastUtils.showError(context, 'Erro ao buscar etiqueta');
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

  Future<void> _sendToPrinter() async {
    final selected = _tags.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }
    if (_modo == 'Edição') {
      await _abrirEdicao(selected);
      return;
    }
    final printingDataList = <PrintingData>[];
    for (final t in selected) {
      final pd = t.printingData;
      if (pd == null) continue;
      final template = pd.takeAndWin != null
          ? Constants.signTemplateModelo
          : Constants.templateNormalizado(pd.template);
      for (int i = 0; i < t.quantity; i++) {
        printingDataList
            .add(pd.copyWith(quantity: 1, template: template));
      }
    }
    if (printingDataList.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    setState(() => _loading = true);
    try {
      await api.sendPriceTagsToPrinter(
        _storeId,
        printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: printingDataList),
      );
      if (!mounted) return;
      setState(() {
        for (final t in selected) {
          _tags.removeWhere((e) => e.id == t.id);
        }
      });
      await _persist();
      ToastUtils.showSuccess(context, 'Enviado para impressão');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao enviar', e);
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _imprimirItem(PriceTag tag) async {
    setState(() => tag.checkbox = true);
    await _sendToPrinter();
  }

  Future<void> _abrirEdicao(List<PriceTag> selected,
      {bool barcode = false}) async {
    final lista = <PrintingData>[];
    for (final t in selected) {
      final pd = t.printingData;
      if (pd == null) continue;
      final template = pd.takeAndWin != null
          ? Constants.signTemplateModelo
          : Constants.templateNormalizado(pd.template);
      lista.add(pd.copyWith(quantity: 1, template: template));
    }
    if (lista.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    await Navigator.pushNamed(context, '/gondola_editavel',
        arguments: {
          'items': lista,
          'printerId': printerId,
          'barcode': barcode,
        });
  }

  Future<void> _imprimirTodas() async {
    if (_tags.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta para imprimir');
      return;
    }
    setState(() => _imprimindo = true);
    for (final t in _tags) {
      t.checkbox = true;
    }
    setState(() {});
    await _sendToPrinter();
    setState(() => _imprimindo = false);
  }

  Future<void> _limparLista() async {
    if (_tags.isEmpty) {
      ToastUtils.show(context, 'Lista já está vazia');
      return;
    }
    setState(() => _limpando = true);
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
    setState(() => _limpando = false);
    if (ok == true) {
      setState(() => _tags.clear());
      await _persist();
      ToastUtils.show(context, 'Lista limpa');
    }
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
                    icon: const Icon(Icons.keyboard_arrow_down, color: primaryRed, size: 16),
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
          // 1. FILTRO UNIFICADO (spinners + busca)
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
                    // Spinners
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          // Spinner 1: Impressora
                          Expanded(
                            child: _buildDropdownItem(
                              icon: Icons.print,
                              label: 'IMPRESSORA',
                              value: _printer,
                              items: ['Zebra 1', 'Zebra 2'],
                              onChanged: (val) => setState(() => _printer = val!),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                          // Spinner 2: Tipo
                          Expanded(
                            child: _buildDropdownItem(
                              icon: Icons.qr_code,
                              label: 'TIPO',
                              value: _buscaTipo,
                              items: ['EAN', 'SAP', 'Descrição'],
                              onChanged: (val) => setState(() {
                                _buscaTipo = val!;
                                _eanHint = val == 'EAN'
                                    ? 'Digite um EAN'
                                    : val == 'SAP'
                                        ? 'Digite um SAP'
                                        : 'Descrição do item';
                                _eanKeyboardType = val == 'Descrição'
                                    ? TextInputType.text
                                    : TextInputType.number;
                              }),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                          // Spinner 3: Modo
                          Expanded(
                            child: _buildDropdownItem(
                              icon: Icons.tune,
                              label: 'MODO',
                              value: _modo,
                              items: ['Normal', 'Edição'],
                              onChanged: (val) => setState(() => _modo = val!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Linha divisora cinza
                    Container(height: 1, color: Color(0xFFE1E5EB)),
                    // Busca
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
                                    focusNode: _eanFocus,
                                    keyboardType: _eanKeyboardType,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintText: _eanHint,
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                    ),
                                  ),
                                ),
                              ),
                              BuscarBotao(
                                porDescricao: _buscaTipo == 'Descrição',
                                buscando: buscando,
                                onPressed: () => _fetchAndAdd(_eanController.text),
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
          const SizedBox(height: 2),


         // 3. BOTÕES INFERIORES (só aparece quando há etiquetas)
         if (_tags.isNotEmpty)
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 8),
             child: ConstrainedBox(
               constraints: const BoxConstraints(maxWidth: 480),
               child: Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: _limpando ? null : _limparLista,
                       style: OutlinedButton.styleFrom(
                         side: const BorderSide(color: primaryRed, width: 1.5),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         padding: const EdgeInsets.symmetric(vertical: 14),
                       ),
                       icon: _limpando
                           ? const SizedBox(
                               width: 16,
                               height: 16,
                               child: CircularProgressIndicator(
                                 strokeWidth: 2,
                                 valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                               ),
                             )
                           : const Icon(Icons.cleaning_services_outlined,
                               size: 18, color: primaryRed),
                       label: const Text(
                         'LIMPAR LISTA',
                         style: TextStyle(
                           color: primaryRed,
                           fontWeight: FontWeight.bold,
                           fontSize: 12,
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: ElevatedButton.icon(
                       onPressed: _imprimindo ? null : _imprimirTodas,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: primaryRed,
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         elevation: 0,
                       ),
                       icon: _imprimindo
                           ? const SizedBox(
                               width: 16,
                               height: 16,
                               child: CircularProgressIndicator(
                                 strokeWidth: 2,
                                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                               ),
                             )
                           : const Icon(Icons.print,
                               size: 18, color: Colors.white),
                       label: const Text(
                         'IMPRIMIR TODAS',
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           fontSize: 12,
                         ),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ),
if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '${_tags.length} ${_tags.length == 1 ? 'item' : 'itens'} na lista',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _gerarPdfEtiquetas,
                      tooltip: 'Gerar PDF da lista',
                      icon: const Icon(Icons.picture_as_pdf,
                          color: Color(0xFFD32F2F), size: 26),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

  bool _gerandoPdf = false;

  Future<void> _gerarPdfEtiquetas() async {
    if (_gerandoPdf || _tags.isEmpty) return;
    setState(() => _gerandoPdf = true);
    try {
      await ListaPdfService.compartilharRelatorioEtiquetas(_tags);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao gerar PDF', e);
      ToastUtils.showError(context, 'Erro ao gerar o PDF');
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
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
            child: Image.asset('assets/icons/ic_etiqueta.png',
                color: const Color(0xFFA0A0A0)),
          ),
          const SizedBox(height: 20),
          const Text(
            '0 item(a) na lista\n\nEscaneie ou digite\npara adicionar à lista',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999999), fontSize: 14),
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
              child: _tags.isEmpty
                  ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                          itemCount: _tags.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 0),
                            itemBuilder: (_, i) {
                              final tag = _tags[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: SwipeToTrashItem(
                                  key: ValueKey(tag.id),
                                  onDismissed: () => _deleteTag(tag),
                                  child: EtiquetaCard(
                                    tag: tag,
                                    onImprimir: (q) {
                                      tag.quantity = q;
                                      _imprimirItem(tag);
                                    },
                                    onRemover: () => _deleteTag(tag),
                                    onChangedQuantity: (q) {
                                      tag.quantity = q;
                                      _persist();
                                    },
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
