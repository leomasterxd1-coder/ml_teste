import 'dart:convert';
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

class PapeletasDiariasScreen extends StatefulWidget {
  final bool embedded;
  const PapeletasDiariasScreen({super.key, this.embedded = false});

  @override
  State<PapeletasDiariasScreen> createState() => _PapeletasDiariasScreenState();
}

class _PapeletasDiariasScreenState extends State<PapeletasDiariasScreen>
    with BuscarAnimMixin {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final ScrollController _scrollController = ScrollController();

  String _storeId = Constants.defaultStore;

  bool _isLoading = false;
  bool _menuOpen = false;
  bool _expandido = true;
  List<PriceSign> _allItems = [];
  List<PriceSign> _items = [];

  String _currentDate = '';
  String _today = '';

  int _naoImpressas = 0;
  int _impressas = 0;
  int _total = 0;
  int _tomorrowCount = 0;

  List<Department> _departments = [];
  final Set<String> _selectedDepartments = {};

  List<String> _sizes = [];
  String _selectedSize = '2X1';

  static const List<String> _movementOptions = [
    'Todos',
    'De/Por',
    'Leve e Ganhe',
    'Normal'
  ];
  int _movementPos = 0;
  String _selectedMovement = '';

  static const List<String> _typeOptions = [
    'Normal',
    'Promocional',
    'Promocional (Modelo)',
    'Normal (Modelo)'
  ];
  int _typePos = 0;
  bool _usarModeloPersonalizado = false;
  bool _usarModeloComum = false;

  static const List<String> _statusOptions = [
    'Todos os status',
    'Impressas',
    'Não impressas'
  ];
  int _statusPos = 0;
  String _selectedStatus = Constants.statusAll;

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    final now = DateTime.now();
    _today = _toApi(now);
    _currentDate = _today;
    _loadFilters();
  }

  String _toApi(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _pad(int n) => n.toString().padLeft(2, '0');
  DateTime _fromApi(String ymd) {
    final p = ymd.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _toDisplay(String ymd) {
    final p = ymd.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : ymd;
  }

  String get _amanhaDisplay {
    final a = _fromApi(_currentDate).add(const Duration(days: 1));
    return '${a.day.toString().padLeft(2, '0')}/${a.month.toString().padLeft(2, '0')}/${a.year}';
  }

  Future<void> _loadFilters() async {
    setState(() => _isLoading = true);
    var ok = false;
    try {
      final filters = await _api.getPriceSignFilters(_storeId);
      _sizes = [
        Constants.signSize1x1,
        Constants.signSize2x1,
        Constants.signSize4x1,
        Constants.signSize6x1,
      ];
      if (filters.size.isNotEmpty) {
        final merged = <String>{...filters.size, ..._sizes};
        _sizes = merged.toList();
      }
      _selectedSize = _sizes.first;

      final deptFilters = await _api.getPriceTagFilters(_storeId, _currentDate);
      _departments = deptFilters.departments.toList()
        ..removeWhere((d) {
          final id = int.tryParse(d.id) ?? 0;
          return id >= 68 && id <= 98;
        })
        ..sort((a, b) {
          final na = int.tryParse(a.id) ?? 0;
          final nb = int.tryParse(b.id) ?? 0;
          return na.compareTo(nb);
        });

      // Contagem de "amanhã" (dashboard do dia seguinte), igual ao Kotlin.
      try {
        final amanha =
            _toApi(_fromApi(_currentDate).add(const Duration(days: 1)));
        final bytes = await _api.getPriceSignDashboard(_storeId, amanha);
        final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _tomorrowCount =
            (root['promoCardInfo']?['totalAvailable'] as num?)?.toInt() ?? 0;
      } catch (_) {
        _tomorrowCount = 0;
      }
      ok = true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('PapeletasDiarias: erro filtros', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar filtros');
      LogHelper.e('PapeletasDiarias: erro filtros', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    // Igual ao Kotlin: ao abrir, já carrega as papeletas (sem tocar em BUSCAR).
    if (ok && mounted) {
      await _loadSigns();
    }
  }

  Future<void> _loadSigns() async {
    setState(() => _isLoading = true);
    startBuscarAnim();
    try {
      final comum = await _api.getPriceSigns(_storeId, Constants.signTypePapeletaComum,
          size: _selectedSize, status: _selectedStatus, startDate: _currentDate);
      final promo = await _api.getPriceSigns(
          _storeId, Constants.signTypePapeletaPromocional,
          size: _selectedSize, status: _selectedStatus, startDate: _currentDate);
      List<PriceSign> all = [...comum.priceSigns, ...promo.priceSigns];

      if (_selectedMovement.isNotEmpty) {
        if (_selectedMovement == 'Normal') {
          // Igual ao Kotlin ("Comum"): exclui DE/POR/LEVE/GANHE/PROMOCIONAL.
          all = all.where((it) {
            final m = it.movement.toUpperCase();
            return !m.contains('DE') &&
                !m.contains('POR') &&
                !m.contains('LEVE') &&
                !m.contains('GANHE') &&
                !m.contains('PROMOCIONAL');
          }).toList();
        } else {
          all = all.where((it) =>
              it.movement.toLowerCase() ==
              _selectedMovement.toLowerCase()).toList();
        }
      }
      if (_selectedDepartments.isNotEmpty) {
        all = all.where((it) {
          final num = _deptNumber(it.department);
          return num != null && _selectedDepartments.contains(num);
        }).toList();
      }
      all.sort((a, b) => _deptNumber(a.department)
          .toString()
          .compareTo(_deptNumber(b.department).toString()));

      _allItems = all;
      _naoImpressas = all.where((e) => _ehNaoImpressa(e)).length;
      _impressas = all.where((e) => _ehImpressa(e)).length;
      _total = all.length;

      setState(() => _items = all);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('PapeletasDiarias: erro ao carregar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar papeletas');
      LogHelper.e('PapeletasDiarias: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      stopBuscarAnim();
    }
  }

  String? _deptNumber(String department) {
    final num = department.split(' -').first.trim();
    return num.isNotEmpty ? num : null;
  }

  // O status real da API vem como "Impressa"/"Não impressa" (capitalizado,
  // com acento). Normaliza antes de comparar, senão a contagem inverte/zero.
  String _normStatus(String s) {
    const comAcento = 'ÁÀÂÃÉÊÍÓÔÕÚÜÇ';
    const semAcento = 'AAAAEEIOOOUUC';
    var r = s.toUpperCase();
    for (var i = 0; i < comAcento.length; i++) {
      r = r.replaceAll(comAcento[i], semAcento[i]);
    }
    return r;
  }

  bool _ehImpressa(PriceSign t) {
    final s = _normStatus(t.status);
    return s.contains('IMPRESSA') && !s.contains('NAO');
  }

  bool _ehNaoImpressa(PriceSign t) {
    return _normStatus(t.status).contains('NAO');
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

  void _onNextDay() {
    if (_currentDate != _today) return;
    // Igual ao Kotlin: "Amanhã" limpa a lista/contadores e só carrega no BUSCAR.
    setState(() {
      final next = _fromApi(_currentDate).add(const Duration(days: 1));
      _currentDate = _toApi(next);
      _items = [];
      _allItems = [];
      _naoImpressas = 0;
      _impressas = 0;
      _total = 0;
    });
  }

  void _onSelectAll(bool? value) {
    setState(() {
      for (var it in _items) it.checkbox = value ?? false;
    });
  }

  void _onItemCheck(PriceSign item, bool? value) =>
      setState(() => item.checkbox = value ?? false);

  void _onItemQty(PriceSign item, int qty) =>
      setState(() => item.quantity = qty);

  Future<void> _onReport() async {
    setState(() => _isLoading = true);
    try {
      // Igual ao Kotlin: o relatório é sempre do dia de hoje.
      final bytes = await _api.reportFullChanges(_storeId, _today, isPriceTag: false);
      const channel = MethodChannel('minhaloja/pdf');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'relatorio_papeletas_$ts.pdf';
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
      LogHelper.e('PapeletasDiarias: erro relatório', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPrint() async {
    final selected = _items.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos uma papeleta');
      return;
    }

    // Igual ao Kotlin: sem modelo personalizado, envia direto pela API.
    if (!_usarModeloPersonalizado) {
      await _enviarParaImpressaoNormal(selected);
      return;
    }

    final data = <PapeletaPrintingData>[];
    for (final e in selected) {
      final pd = e.printingData;

      String? itemTemplate = pd?.template;
      if (_usarModeloPersonalizado) {
        if (_usarModeloComum) {
          // Fiel ao Kotlin: usa o template ORIGINAL da API (ex: "comum_por").
          // (não força nada; fallback "Normal" se nulo)
          itemTemplate = pd?.template ?? Constants.signTemplateNormal;
        } else {
          final movement = e.movement.toLowerCase();
          final temLeveGanhe = (pd?.takeAndWinQuantity ?? 0) > 0;
          if (temLeveGanhe) {
            itemTemplate = Constants.signTemplateModelo;
          } else {
            // Fiel ao backend: usa o template ORIGINAL do item (ex: "de_por")
            // que a API de preview reconhece.
            itemTemplate = pd?.template ?? (movement == 'de/por'
                ? Constants.signTemplateDepor
                : movement == 'parcelado'
                    ? Constants.signTemplateDeporParcelado
                    : Constants.signTemplateModelo);
          }
        }
      }

      final baseData = pd == null
          ? PapeletaPrintingData(
              template: itemTemplate,
              productName: e.description,
              price: double.tryParse(e.price) ?? 0,
              codSap: e.sap,
              ean: e.ean,
              referenceDate: _currentDate,
              size: _selectedSize,
              quantity: 1,
              unit: '',
            )
          : pd.copyWith(
              template: itemTemplate ?? pd.template,
              size: _selectedSize,
              quantity: 1,
            );

      final qtd = e.quantity > 0 ? e.quantity : 1;
      for (int i = 0; i < qtd; i++) {
        data.add(baseData);
      }
    }

    final r = await Navigator.pushNamed(context, '/modelo_editavel',
        arguments: {
          'items': data,
          'size': _selectedSize,
          'mostrarCheckboxOverlay': true,
          'modoEditavel': _usarModeloComum,
          'usarModeloComum': _usarModeloComum,
        });
    if (r == true) await _loadSigns();
  }

  // Caminho normal de impressão: envia direto pela API (sem modelo personalizado).
  Future<void> _enviarParaImpressaoNormal(List<PriceSign> selected) async {
    setState(() => _isLoading = true);
    try {
      final products = selected
          .where((e) => e.printingData != null)
          .map((e) => e.printingData!.copyWith(
                size: _selectedSize,
                quantity: e.quantity > 0 ? e.quantity : 1,
              ))
          .toList();
      if (products.isEmpty) {
        ToastUtils.show(context, 'Dados de impressão não disponíveis');
        return;
      }
      await _api.sendPriceSigns(
          _storeId, SendPriceSignRequest(products: products));
      final total = products.fold<int>(0, (s, d) => s + (d.quantity ?? 1));
      if (!mounted) return;
      ToastUtils.show(context, '$total papeletas enviadas para impressão!');
      await _loadSigns();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.show(context, '❌ Erro ao enviar para impressão');
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, 'Erro ao enviar para impressão');
      LogHelper.e('PapeletasDiarias: erro enviar impressão', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _allDepartmentsSelected =>
      _departments.isNotEmpty &&
      _selectedDepartments.length == _departments.length;

  void _openDepartmentDialog() async {
    final temp = <String>{..._selectedDepartments};
    final deptsComItens = _departments.where((d) {
      final contagem = _contagemDepartamento(d.id);
      return contagem.$1 > 0 || contagem.$2 > 0;
    }).toList();
    if (deptsComItens.isEmpty) {
      ToastUtils.show(context, 'Nenhum departamento com impressão');
      return;
    }
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
                        onChanged: (v) => setInner(() {
                          if (v == true) {
                            temp.addAll(deptsComItens.map((d) => d.id));
                          } else {
                            temp.clear();
                          }
                        }),
                      ),
                      ...deptsComItens.map((d) {
                        final contagem = _contagemDepartamento(d.id);
                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('${d.id} - ${d.label}'),
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
                          value: temp.contains(d.id),
                          onChanged: (v) => setInner(() {
                            if (v == true) temp.add(d.id); else temp.remove(d.id);
                          }),
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
    const primaryRed = Color(0xFFC61033);

    // Corpo compartilhado (embutido na tela única ou como tela própria).
    final conteudo = SafeArea(
      top: false,
      child: Stack(
        children: [
          Column(
            children: [
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
          'Papeletas de ${isTomorrow ? 'amanhã' : 'hoje'}',
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

  Widget _buildHeader() {
    final isTomorrow = _currentDate != _today;
    final nextDay = _fromApi(_today).add(const Duration(days: 1));
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
                onTap: isTomorrow
                    ? () {
                        _currentDate = _today;
                        _loadSigns();
                      }
                    : null,
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
                ..._menuItem('assets/icons/eti_avulsa.png', 'Etiqueta avulsa', 0),
                _menuDivider(),
                ..._menuItem('assets/icons/pap_avulsa.png', 'Papeleta avulsa', 1),
                _menuDivider(),
                ..._menuItem('assets/icons/eti_diaria.png', 'Etiquetas diárias', 2),
                _menuDivider(),
                ..._menuItem('assets/icons/pap_diaria.png', 'Papeletas diárias', 3),
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
      case 1:
        Navigator.pop(context);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/etiquetas');
        break;
      case 3:
        setState(() {});
        break;
    }
  }

  Widget _buildBody() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (_expandido) SliverToBoxAdapter(child: _buildHeader()),
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
                        _PapeletaContadoresCard(
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
              ],
            ),
          ),
        ),
        if (_isLoading && _items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Column(
                children: [
                  const Icon(Icons.print_disabled, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma papeleta para este período',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tente ajustar os filtros acima.',
                      style: TextStyle(color: Colors.black54)),
                  if (_currentDate == _today && _tomorrowCount > 0) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Você tem $_tomorrowCount papeleta(s) de amanhã ($_amanhaDisplay) para imprimir! Selecione o tipo, os departamentos e o status para começar a imprimir.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC61033),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          // Lazy: só monta os itens visíveis (antes era um Column com TODOS
          // os itens, o que deixava a rolagem pesada em listas grandes).
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final it = _items[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: PapeletaDiariaCard(
                  item: it,
                  onChangedCheckbox: (v) => _onItemCheck(it, v),
                  onChangedQuantity: (q) => _onItemQty(it, q),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    const primaryRed = Color(0xFFC61033);
    const labelGrey = Color(0xFF8C9BA5);
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

  List<Widget> _buildFiltersContent() {
    const primaryRed = Color(0xFFC61033);
    return [
          Row(
            children: [
              Expanded(
                child: _buildDropdownItem(
                  icon: Icons.compare_arrows,
                  label: 'MOVIMENTO',
                  value: _movementOptions[_movementPos],
                  items: List<String>.from(_movementOptions),
                  onChanged: (val) {
                    final pos = _movementOptions.indexOf(val ?? 'Todos');
                    setState(() {
                      _movementPos = pos >= 0 ? pos : 0;
                      _selectedMovement = _movementPos == 0
                          ? ''
                          : _movementOptions[_movementPos];
                    });
                  },
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              Expanded(
                child: _buildDropdownItem(
                  icon: Icons.category,
                  label: 'TIPO',
                  value: _typeOptions[_typePos],
                  items: List<String>.from(_typeOptions),
                  onChanged: (val) {
                    final pos = _typeOptions.indexOf(val ?? 'Normal');
                    setState(() {
                      _typePos = pos >= 0 ? pos : 0;
                      _usarModeloPersonalizado =
                          (_typePos == 2 || _typePos == 3);
                      _usarModeloComum = (_typePos == 3);
                    });
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdownItem(
                  icon: Icons.aspect_ratio,
                  label: 'TAMANHO',
                  value: _selectedSize,
                  items: List<String>.from(_sizes),
                  onChanged: (val) =>
                      setState(() => _selectedSize = val ?? '2X1'),
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              Expanded(
                child: _buildDropdownItem(
                  icon: Icons.filter_list,
                  label: 'STATUS',
                  value: _statusOptions[_statusPos],
                  items: List<String>.from(_statusOptions),
                  onChanged: (val) {
                    final pos = _statusOptions.indexOf(val ?? 'Todos os status');
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
                    onPressed: buscando ? null : _loadSigns,
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

class _PapeletaContadoresCard extends StatelessWidget {
  final int naoImpressas;
  final int impressas;
  final int total;
  const _PapeletaContadoresCard({
    required this.naoImpressas,
    required this.impressas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _counter(naoImpressas.toString(), 'Não\nImpressas',
            const Color(0xFFC61033)),
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

