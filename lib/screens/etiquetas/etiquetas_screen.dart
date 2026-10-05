import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../network/api_service.dart';
import '../../network/api_client.dart';
import '../../widgets/cards.dart';
import '../../core/session_manager.dart';
import '../../core/constants.dart';
import '../../utils/toast_utils.dart';
import '../../utils/log_helper.dart';
import '../../utils/session_expired_handler.dart';
import '../../utils/buscar_anim.dart';

class EtiquetasScreen extends StatefulWidget {
  final bool embedded;
  const EtiquetasScreen({super.key, this.embedded = false});

  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen>
    with BuscarAnimMixin {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final ScrollController _scrollController = ScrollController();

  String _storeId = Constants.defaultStore;

  bool _isLoading = false;
  bool _menuOpen = false;
  bool _expandido = true;
  List<PriceTag> _items = [];
  List<PriceTag> _allItems = [];

  String _currentDate = '';
  String _today = '';

  int _naoImpressas = 0;
  int _impressas = 0;
  int _total = 0;

  List<TagFilter> _printers = [];
  String _selectedPrinterId = '';
  String _selectedTagId = '';
  bool _modoEdicao = false;

  List<Department> _departments = [];
  final Set<String> _selectedDepartments = {};

  // Itens enviados para impressão recentemente (atualização otimista do
  // contador em tempo real, sem depender do backend refletir na hora).
  final Set<String> _enviados = {};

  String _chaveEnviado(PriceTag t) => '${t.ean}|${t.sap}';

  String _statusEfetivo(PriceTag t) =>
      _enviados.contains(_chaveEnviado(t))
          ? Constants.statusImpressas
          : t.status;

  // O status real da API vem como "Impressa"/"Não impressa" (capitalizado,
  // com acento). Normaliza antes de comparar, senão "NÃO" (com Ã) nunca
  // bate com 'NAO' e tudo conta como impressa.
  String _normStatus(String s) {
    const comAcento = 'ÁÀÂÃÉÊÍÓÔÕÚÜÇ';
    const semAcento = 'AAAAEEIOOOUUC';
    var r = s.toUpperCase();
    for (var i = 0; i < comAcento.length; i++) {
      r = r.replaceAll(comAcento[i], semAcento[i]);
    }
    return r;
  }

  bool _ehImpressa(PriceTag t) {
    final s = _normStatus(_statusEfetivo(t));
    return s.contains('IMPRESSA') && !s.contains('NAO');
  }

  bool _ehNaoImpressa(PriceTag t) {
    return _normStatus(_statusEfetivo(t)).contains('NAO');
  }

  String _selectedStatus = Constants.statusAll;
  static const List<String> _statusLabels = [
    'Todos os status',
    'Impressas',
    'Não impressas'
  ];
  int _statusPos = 0;

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    final now = DateTime.now();
    _today = _toApi(now);
    _currentDate = _today;
    _loadInit();
  }

  String _toApi(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  String _toDisplay(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[2]}/${parts[1]}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  DateTime _fromApi(String ymd) {
    final parts = ymd.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Future<void> _loadInit() async {
    setState(() => _isLoading = true);
    try {
      final filters = await _api.getPriceTagFilters(_storeId, _currentDate);
      _printers = (filters.tags)
          .where((t) => (t.printerId).toUpperCase().contains('ZEBRA'))
          .toList();
      _departments = filters.departments.toList()
        ..removeWhere((d) {
          final id = int.tryParse(d.id) ?? 0;
          return id >= 68 && id <= 98;
        })
        ..sort((a, b) {
          final na = int.tryParse(a.id) ?? 0;
          final nb = int.tryParse(b.id) ?? 0;
          return na.compareTo(nb);
        });
      if (_printers.isNotEmpty) {
        _selectedPrinterId = _printers.first.printerId;
        _selectedTagId = _printers.first.tagId;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao carregar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar etiquetas');
      LogHelper.e('EtiquetasScreen: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    startBuscarAnim();
    try {
      final resp = await _api.getPriceTagsByStatus(_storeId, _selectedStatus,
          startDate: _currentDate);
      List<PriceTag> list = resp.priceTags;
      if (_selectedDepartments.isNotEmpty) {
        final deptNums = _selectedDepartments
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toSet();
        if (deptNums.isNotEmpty) {
          list = list.where((it) {
            final num = int.tryParse(_deptNumber(it.department) ?? '');
            return num != null && deptNums.contains(num);
          }).toList();
        }
      }
      list.sort((a, b) => _deptNumber(a.department)
          .toString()
          .compareTo(_deptNumber(b.department).toString()));
      _allItems = list;
      _naoImpressas = list.where((e) => _ehNaoImpressa(e)).length;
      _impressas = list.where((e) => _ehImpressa(e)).length;
      _total = list.length;
      setState(() => _items = list);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao buscar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao buscar etiquetas');
      LogHelper.e('EtiquetasScreen: erro ao buscar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      stopBuscarAnim();
    }
  }

  String? _deptNumber(String department) {
    final num = department.split(' -').first.trim();
    return num.isNotEmpty ? num : null;
  }

  (int, int) _contagemDepartamento(String id) {
    final deptNum = int.tryParse(id) ?? -1;
    var pendente = 0;
    var impressas = 0;
    for (final it in _allItems) {
      final n = int.tryParse(_deptNumber(it.department) ?? '') ?? -1;
      if (n == deptNum) {
        if (_ehImpressa(it)) {
          impressas++;
        } else {
          pendente++;
        }
      }
    }
    return (pendente, impressas);
  }

  String _printerLabel(String label) {
    final match =
        RegExp(r'Zebra\s*\d+', caseSensitive: false).firstMatch(label);
    if (match != null) {
      final raw = match.group(0)!;
      return 'Zebra ${raw.replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return label;
  }

  bool get _allDepartmentsSelected =>
      _departments.isNotEmpty &&
      _selectedDepartments.length == _departments.length;

  void _onNextDay() {
    if (_currentDate != _today) return;
    setState(() {
      final next = _fromApi(_currentDate).add(const Duration(days: 1));
      _currentDate = _toApi(next);
    });
    _loadTags();
  }

  void _onSelectAll(bool? value) {
    setState(() {
      for (var it in _items) {
        it.checkbox = value ?? false;
      }
    });
  }

  void _onItemCheck(PriceTag item, bool? value) {
    setState(() => item.checkbox = value ?? false);
  }

  void _onItemQty(PriceTag item, int qty) {
    setState(() => item.quantity = qty);
  }

  Future<void> _onPrint() async {
    if (_selectedPrinterId.isEmpty) {
      ToastUtils.show(context, 'Selecione uma impressora');
      return;
    }
    final selected = _items.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }
    if (_modoEdicao) {
      await _abrirEdicao(selected);
      return;
    }
    final data = selected.map((e) {
      final pd = e.printingData;
      if (pd == null) {
        return PrintingData(
          ean: e.ean,
          description: e.description,
          department: e.department,
          displayPrice: double.tryParse(e.price) ?? 0,
          quantity: e.quantity,
          movementType: e.movement,
          unit: '',
          unitQty: 0,
          unitValue: 0,
          printUnitValue: false,
          codSap: e.sap,
          referenceDate: _currentDate,
        );
      }
      // Fiel ao app Kotlin: mantém o referenceDate vindo do backend.
      // Se vier vazio, usa a data atual como fallback.
      final ref = pd.referenceDate.isEmpty ? _currentDate : pd.referenceDate;
      return PrintingData(
        ean: pd.ean,
        description: pd.description,
        department: pd.department,
        displayPrice: pd.displayPrice,
        price: pd.price,
        promotionalPrice: pd.promotionalPrice,
        quantity: e.quantity,
        movementType: pd.movementType,
        unit: pd.unit,
        unitQty: pd.unitQty,
        unitValue: pd.unitValue,
        printUnitValue: pd.printUnitValue,
        codSap: pd.codSap,
        takeAndWin: pd.takeAndWin,
        referenceDate: ref,
        template: pd.template,
        productName: pd.productName,
        promotionPrice: pd.promotionPrice,
        takeAndWinQuantity: pd.takeAndWinQuantity,
        takeAndWinPrice: pd.takeAndWinPrice,
        takeAndWinPercent: pd.takeAndWinPercent,
        installments: pd.installments,
      );
    }).toList();

    setState(() => _isLoading = true);
    try {
      await _api.sendPriceTagsToPrinter(
        _storeId,
        _selectedPrinterId,
        _selectedTagId,
        SendPriceTagsRequest(products: data),
      );
      ToastUtils.showSuccess(context, 'Enviado para impressão');
      // Atualização otimista do contador (tempo real): os enviados contam
      // como impressos imediatamente, sem esperar o backend.
      for (final t in selected) {
        _enviados.add(_chaveEnviado(t));
        t.checkbox = false;
      }
      if (mounted) setState(() {});
      await _loadTags();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao enviar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
      LogHelper.e('EtiquetasScreen: erro ao enviar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirEdicao(List<PriceTag> selected) async {
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
    await Navigator.pushNamed(context, '/gondola_editavel',
        arguments: {'items': lista, 'printerId': _selectedPrinterId});
  }

  Future<void> _onReport() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await _api.reportFullChanges(_storeId, _currentDate, isPriceTag: true);
      const channel = MethodChannel('minhaloja/pdf');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'relatorio_etiquetas_$ts.pdf';
      await channel.invokeMethod('saveToDownloadsAndOpen', {
        'fileName': fileName,
        'bytes': bytes,
        'mime': 'application/pdf',
      });
      if (!mounted) return;
      ToastUtils.show(context, 'Relatório salvo e aberto');
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao baixar relatório');
      LogHelper.e('EtiquetasScreen: erro relatório', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDepartmentDialog() async {
    // Só mostra os departamentos com alteração no dia (como no Kotlin).
    final deptsComItens = _departments
        .where((d) {
          final c = _contagemDepartamento(d.id);
          return c.$1 > 0 || c.$2 > 0;
        })
        .toList();
    if (deptsComItens.isEmpty) {
      ToastUtils.show(context, 'Nenhum departamento com impressão');
      return;
    }
    final temp = <String>{..._selectedDepartments};
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Selecione os departamentos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(),
              Flexible(
                child: StatefulBuilder(
                  builder: (c, setInner) => ListView(
                    shrinkWrap: true,
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          'Todos os departamentos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: temp.length == deptsComItens.length,
                        onChanged: (v) {
                          setInner(() {
                            if (v == true) {
                              temp.addAll(deptsComItens.map((d) => d.id));
                            } else {
                              temp.clear();
                            }
                          });
                        },
                      ),
                      ...deptsComItens.map((d) {
                        final id = d.id;
                        final contagem = _contagemDepartamento(id);
                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('$id - ${d.label}'),
                              ),
                              if (contagem.$1 > 0)
                                Text('${contagem.$1}',
                                    style: const TextStyle(
                                      color: Color(0xFFDA1C2E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    )),
                              if (contagem.$1 > 0 && contagem.$2 > 0)
                                const SizedBox(width: 8),
                              if (contagem.$2 > 0)
                                Text('${contagem.$2}',
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    )),
                            ],
                          ),
                          value: temp.contains(id),
                          onChanged: (v) {
                            setInner(() {
                              if (v == true) temp.add(id); else temp.remove(id);
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedDepartments
                        ..clear()
                        ..addAll(temp));
                      Navigator.pop(ctx);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _selectedCount => _items.where((e) => e.checkbox).length;

  @override
  Widget build(BuildContext context) {
    final isTomorrow = _currentDate != _today;
    final nextDay = _fromApi(_today).add(const Duration(days: 1));
    const primaryRed = Color(0xFFC61033);

    // Corpo compartilhado (embutido na tela única ou como tela própria).
    final conteudo = SafeArea(
      top: false,
      child: Stack(
        children: [
          Column(
            children: [
              if (_expandido) _buildHeader(isTomorrow, nextDay),
              Expanded(
                child: _buildBody(),
              ),
              _buildBottomBar(),
            ],
          ),
          if (_menuOpen) _buildMenuOverlay(),
        ],
      ),
    );

    if (widget.embedded) return conteudo;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        title: Text(
          'Etiquetas de ${isTomorrow ? 'amanhã' : 'hoje'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _menuOpen = !_menuOpen),
        ),
        actions: [
          IconButton(
            icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _expandido = !_expandido),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
        elevation: 0,
      ),
      body: conteudo,
    );
  }

  Widget _buildHeader(bool isTomorrow, DateTime nextDay) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (isTomorrow) {
                    _currentDate = _today;
                    _loadTags();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !isTomorrow
                        ? const Color(0xFFA5D6A7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Hoje ${_toDisplay(_today)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: isTomorrow ? null : _onNextDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isTomorrow
                        ? const Color(0xFFA5D6A7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Amanhã ${_toDisplay(_toApi(nextDay))}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = false),
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.only(top: 8, left: 4),
            width: 280,
            padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE5093A),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._menuItem('assets/icons/eti_avulsa.png', 'ETIQUETA AVULSA', 0),
                _menuDivider(),
                ..._menuItem('assets/icons/pap_avulsa.png', 'PAPELETA AVULSA', 1),
                _menuDivider(),
                ..._menuItem('assets/icons/eti_diaria.png', 'ETIQUETAS DIÁRIAS', 2),
                _menuDivider(),
                ..._menuItem('assets/icons/pap_diaria.png', 'PAPELETAS DIÁRIAS', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _menuItem(String icon, String label, int index) {
    return [
      InkWell(
        onTap: () {
          setState(() => _menuOpen = false);
          _onMenuTap(index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Image.asset(icon, width: 24, height: 24, fit: BoxFit.contain, color: Colors.white),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _menuDivider() => Container(height: 0.5, color: Colors.white.withOpacity(0.15));

  void _onMenuTap(int index) {
    switch (index) {
      case 0:
        Navigator.pop(context);
        break;
      case 1:
        Navigator.pop(context);
        break;
      case 2:
        setState(() {});
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/papeletas_diarias');
        break;
    }
  }

  Widget _buildBody() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_expandido)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ContadoresCard(
                          naoImpressas: _naoImpressas,
                          impressas: _impressas,
                          total: _total,
                        ),
                        const Divider(height: 18),
                        ..._buildFiltersContent(),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Checkbox(
                      value:
                          _items.isNotEmpty && _items.every((e) => e.checkbox),
                      onChanged: _onSelectAll,
                    ),
                    const Text('Selecionar todos',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('($_selectedCount) selecionados',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                if (_currentDate != _today)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text(
                      'Atenção: A impressão será efetuada para o dia seguinte.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_isLoading && _items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      children: const [
                        Icon(Icons.print_disabled, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhuma etiqueta para este período',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Tente ajustar os filtros acima.',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  )
                else
                  ..._items.map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: PriceTagCard(
                          tag: it,
                          onChangedCheckbox: (v) => _onItemCheck(it, v),
                          onChangedQuantity: (q) => _onItemQty(it, q),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFiltersContent() {
    const primaryRed = Color(0xFFC61033);
    return [
          Row(
            children: [
              _buildDropdownItem(
                icon: Icons.print,
                label: 'IMPRESSORA',
                value: _selectedPrinterId.isEmpty
                    ? 'Nenhuma'
                    : _printerLabel(_printers
                        .firstWhere((p) => p.printerId == _selectedPrinterId)
                        .label),
                items: _printers.map((p) => _printerLabel(p.label)).toList(),
                onChanged: (val) {
                  final p = _printers
                      .firstWhere((e) => _printerLabel(e.label) == val);
                  setState(() {
                    _selectedPrinterId = p.printerId;
                    _selectedTagId = p.tagId;
                  });
                },
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              _buildDropdownItem(
                icon: Icons.filter_list,
                label: 'STATUS',
                value: _statusLabels[_statusPos],
                items: List<String>.from(_statusLabels),
                onChanged: (val) {
                  final pos = _statusLabels.indexOf(val ?? 'Todos os status');
                  setState(() {
                    _statusPos = pos >= 0 ? pos : 0;
                    _selectedStatus = [
                      Constants.statusAll,
                      Constants.statusImpressas,
                      Constants.statusNaoImpressas
                    ][_statusPos];
                  });
                },
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              _buildDropdownItem(
                icon: Icons.tune,
                label: 'MODO',
                value: _modoEdicao ? 'Edição' : 'Normal',
                items: ['Normal', 'Edição'],
                onChanged: (val) =>
                    setState(() => _modoEdicao = val == 'Edição'),
              ),
            ],
          ),
          const Divider(height: 18),
          // DEPARTAMENTOS + BUSCAR
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openDepartmentDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(
                        _selectedDepartments.isEmpty
                            ? 'Departamentos'
                            : _allDepartmentsSelected
                                ? 'Todos'
                                : '${_selectedDepartments.length} selecionado(s)',
                        style: TextStyle(
                          color: _selectedDepartments.isEmpty
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: ElevatedButton.icon(
                    onPressed: buscando ? null : _loadTags,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(buscando ? buscandoLabel : 'BUSCAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final primaryRed = Color(0xFFC61033);
    final labelGrey = Color(0xFF8C9BA5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: primaryRed, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
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

  Widget _buildBottomBar() {
    const primaryRed = Color(0xFFC61033);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _onReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryRed,
                side: const BorderSide(color: primaryRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('RELATÓRIO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _onPrint,
              icon: const Icon(Icons.print),
              label: const Text('IMPRIMIR',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _ContadoresCard extends StatelessWidget {
  final int naoImpressas;
  final int impressas;
  final int total;
  const _ContadoresCard({
    required this.naoImpressas,
    required this.impressas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _counter(
            naoImpressas.toString(), 'Não\nImpressas', const Color(0xFFC61033)),
          Container(width: 1, height: 28, color: Colors.grey[200]),
          _counter(impressas.toString(), 'Impressas', const Color(0xFF388E3C)),
          Container(width: 1, height: 28, color: Colors.grey[200]),
          _counter(total.toString(), 'Total', const Color(0xFF1976D2)),
        ],
      );
  }

  Widget _counter(String number, String label, Color color) {
    return Row(
      children: [
        Text(number,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w300, color: color)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.black54, height: 1.2)),
      ],
    );
  }
}

