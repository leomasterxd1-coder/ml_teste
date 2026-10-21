import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/lista_store.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/beep.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/price_tag_mapper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  /// Modo contínuo (etiquetas): fica na câmera adicionando itens à lista.
  final bool continuo;

  const BarcodeScannerScreen({super.key, this.continuo = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _popped = false;
  bool _torchOn = false;
  double _scaleStart = 1.0;
  double _currentZoom = 1.0;

  // ---- Modo contínuo ----
  static const int _debounceMs = 3000;
  ApiService? _api;
  String _storeId = Constants.defaultStore;
  String _today = '';
  bool _processing = false;
  String _lastCode = '';
  int _lastCodeTime = 0;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    if (widget.continuo) {
      _api = ApiService(ApiClient.instance.getSlApiService());
      _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
      final d = DateTime.now();
      _today =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  void _onDetect(BarcodeCapture capture) {
    String? raw;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw == null) return;
    final codigo = _normalizar(raw);

    if (!widget.continuo) {
      if (_popped) return;
      _popped = true;
      Navigator.pop(context, codigo);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    // Debounce: ignora o mesmo código por 3s e não processa em paralelo.
    if (_processing) return;
    if (codigo == _lastCode && now - _lastCodeTime < _debounceMs) return;
    _lastCode = codigo;
    _lastCodeTime = now;
    _processar(codigo);
  }

  /// Códigos que iniciam com "0" (ex.: EAN-13 de UPC-A) — ignora o(s) zero(s)
  /// inicial(is) e lê a partir do primeiro dígito diferente de zero.
  String _normalizar(String raw) {
    if (!raw.startsWith('0')) return raw;
    final semZeros = raw.replaceFirst(RegExp(r'^0+'), '');
    return semZeros.isEmpty ? raw : semZeros;
  }

  Future<void> _processar(String ean) async {
    final api = _api;
    if (api == null) return;
    setState(() => _processing = true);
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: ean,
        startDate: _today,
      );
      if (!mounted) return;
      if (resp.items.isEmpty) {
        Beep.error();
        return;
      }
      final lista = await ListaStore.instance.getEtiquetas();
      for (final item in resp.items) {
        final idx = lista.indexWhere((t) => t.ean == item.ean);
        if (idx >= 0) {
          lista[idx].quantity += 1;
        } else {
          lista.add(singleToPriceTag(item));
        }
      }
      await ListaStore.instance.saveEtiquetas(lista);
      await ListaStore.instance.setColagem(ean);
      if (!mounted) return;
      setState(() => _added += resp.items.length);
      Beep.success();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        Beep.error();
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      Beep.error();
    } catch (e) {
      LogHelper.e('BarcodeScanner: erro na leitura contínua', e);
      Beep.error();
    } finally {
      _processing = false;
    }
  }

  Future<void> _escolherImpressoraEEnviar() async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Enviar impressão'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, Constants.printerZebra1),
            child: const Text('Zebra 1'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, Constants.printerZebra2),
            child: const Text('Zebra 2'),
          ),
        ],
      ),
    );
    if (escolha == null || !mounted) return;
    await _enviarImpressao(escolha);
  }

  Future<void> _enviarImpressao(String printerId) async {
    final api = _api;
    if (api == null) return;
    final etiquetas = await ListaStore.instance.getEtiquetas();
    if (etiquetas.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta adicionada');
      return;
    }
    final lista = <PrintingData>[];
    for (final item in etiquetas) {
      final pd = item.printingData;
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
    try {
      await api.sendPriceTagsToPrinter(
        _storeId,
        printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: lista),
      );
      if (!mounted) return;
      ToastUtils.show(
          context, '${lista.length} etiqueta(s) enviada(s) para impressão!');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao enviar: $e');
    }
  }

  Future<void> _abrirPreviewPapeleta() async {
    final etiquetas = await ListaStore.instance.getEtiquetas();
    if (!mounted) return;
    if (etiquetas.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta adicionada');
      return;
    }
    // O diálogo abre na hora (só usa a lista local); a busca dos PriceSign
    // acontece depois, em paralelo, com indicador de carregamento.
    final escolha = await _mostrarDialogoPapeleta(etiquetas);
    if (escolha == null || !mounted) return;
    final qtds = (escolha['qtds'] as Map).cast<String, int>();
    final size = escolha['size'] as String;
    final selecionados =
        (escolha['selecionados'] as Map).cast<String, bool>();
    final itensSel =
        etiquetas.where((e) => selecionados[e.ean] ?? true).toList();
    if (itensSel.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final lista = await _carregarPapeletas(itensSel, qtds, size);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (lista.isEmpty) {
        ToastUtils.show(context, 'Dados de papeleta não disponíveis');
        return;
      }
      await Navigator.pushNamed(context, '/modelo_editavel', arguments: {
        'items': lista,
        'size': size,
        'mostrarCheckboxOverlay': true,
        'modoEditavel': false,
        'modoVencimentos': false,
        'semOverlay': false,
        'apiSemOverlay': true,
        'hideGerarPreview': false,
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ToastUtils.showError(context, 'Erro: $e');
    }
  }

  Future<Map<String, dynamic>?> _mostrarDialogoPapeleta(
      List<PriceTag> itens) {
    // Quantidade inicial = quantas vezes o item foi escaneado.
    final qtds = <String, int>{
      for (final it in itens) it.ean: it.quantity < 1 ? 1 : it.quantity,
    };
    final selecionados = <String, bool>{for (final it in itens) it.ean: true};
    var size = Constants.signSize1x1;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final maxH = MediaQuery.of(ctx).size.height * 0.45;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IMPRIMIR PAPELETA',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                      'Escolha quantas vezes repetir cada item e o tamanho',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final it in itens)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selecionados[it.ean] ?? true,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (v) => setSheet(() =>
                                      selecionados[it.ean] = v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          it.description.isEmpty
                                              ? it.ean
                                              : it.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      Text(it.ean,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                _qtdSelector(
                                    qtds[it.ean] ?? 1,
                                    (v) =>
                                        setSheet(() => qtds[it.ean] = v),
                                    enabled: selecionados[it.ean] ?? true),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tamanho',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in const {
                        '1×1': Constants.signSize1x1,
                        '2×1': Constants.signSize2x1,
                        '4×1': Constants.signSize4x1,
                        '6×1': Constants.signSize6x1,
                      }.entries)
                        ChoiceChip(
                          label: Text(e.key),
                          selected: size == e.value,
                          onSelected: (_) => setSheet(() => size = e.value),
                          showCheckmark: false,
                          backgroundColor: const Color(0xFFF1F5F9),
                          selectedColor: const Color(0xFFD7193F),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                            color: size == e.value
                                ? Colors.white
                                : const Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          avatar: size == e.value
                              ? Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF9B0015),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 13, color: Colors.white),
                                )
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, {
                        'qtds': qtds,
                        'size': size,
                        'selecionados': selecionados,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('GERAR PREVIEW',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _qtdSelector(int value, ValueChanged<int> onChanged,
      {bool enabled = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: enabled && value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Center(
            child: Text('$value',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: enabled ? null : Colors.grey)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed:
              enabled && value < 30 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Future<PapeletaStandaloneResponse?> _fetchPapeleta(
      ApiService api, String ean, String tipo) async {
    try {
      return await api.getPriceSignStandalone(_storeId, tipo,
          ean: ean, startDate: _today);
    } catch (_) {
      return null;
    }
  }

  Future<List<PapeletaPrintingData>> _carregarPapeletas(
      List<PriceTag> etiquetas, Map<String, int> qtds, String size) async {
    final api = _api;
    if (api == null) return const [];
    final refs = <String>[];
    final futures = <Future<PapeletaStandaloneResponse?>>[];
    for (final et in etiquetas) {
      for (final tipo in [Constants.tipoComum, Constants.tipoPromocional]) {
        refs.add(et.ean);
        futures.add(_fetchPapeleta(api, et.ean, tipo));
      }
    }
    final respostas = await Future.wait(futures);
    final vistos = <String>{};
    final lista = <PapeletaPrintingData>[];
    for (var i = 0; i < respostas.length; i++) {
      final resp = respostas[i];
      if (resp == null) continue;
      final qtd = qtds[refs[i]] ?? 1;
      for (final item in resp.items) {
        final pd = item.printingData;
        if (pd == null) continue;
        if (!vistos.add(item.ean)) continue;
        for (var c = 0; c < qtd; c++) {
          lista.add(pd.copyWith(quantity: 1, size: size));
        }
      }
    }
    return lista;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_scaleStart * details.scale).clamp(1.0, 8.0);
    if (newZoom != _currentZoom) {
      _currentZoom = newZoom;
      _controller.setZoomScale((_currentZoom - 1) / 7);
      setState(() {});
    }
  }

  Widget _botaoCamera(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD7193F),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _botaoCameraBranco(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Color(0xFFD7193F),
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _digitarEanManual() async {
    final ctrl = TextEditingController();
    final ean = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar EAN'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite o EAN'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    final codigo = _normalizar((ean ?? '').trim());
    if (codigo.isEmpty) return;
    _processar(codigo);
  }

  Future<void> _toggleLanterna() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final vfWidth = w * 0.85;
            const vfHeight = 200.0;
            final vfRect = Rect.fromLTWH((w - vfWidth) / 2,
                (h - vfHeight) / 2 - 30, vfWidth, vfHeight);
            return Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.pop(context);
                    });
                    return const Center(
                      child: Text(
                        'Não foi possível acessar a câmera',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
                CustomPaint(
                  size: Size(w, h),
                  painter: _DimHolePainter(vfRect, 16),
                ),
                Positioned.fromRect(
                  rect: vfRect,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: vfRect.top - 30,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Escanear código de barras',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: vfRect.bottom + 8,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Centralize o código para escanear',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
                if (widget.continuo)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 32,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    _added == 1
                                        ? '1 item adicionado'
                                        : '$_added itens adicionados',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFD7193F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _botaoCameraBranco(
                                  'DIGITAR EAN', _digitarEanManual),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _botaoCamera('ENVIAR IMPRESSÃO',
                                  _escolherImpressoraEEnviar),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _botaoCamera(
                                  'IMPRIMIR PAPELETA', _abrirPreviewPapeleta),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: (w - vfWidth) / 2,
                  bottom: widget.continuo ? 128 : 32,
                  child: SizedBox(
                    width: vfWidth,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _toggleLanterna,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor:
                            _torchOn ? Colors.white : Colors.transparent,
                      ),
                      child: Text(
                        'Lanterna',
                        style: TextStyle(
                          color: _torchOn ? Colors.black : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_currentZoom > 1.0)
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _DimHolePainter extends CustomPainter {
  final Rect hole;
  final double radius;
  _DimHolePainter(this.hole, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter old) =>
      old.hole != hole || old.radius != radius;
}
