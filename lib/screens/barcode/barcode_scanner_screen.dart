import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/lista_store.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
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

    if (!widget.continuo) {
      if (_popped) return;
      _popped = true;
      Navigator.pop(context, raw);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    // Debounce: ignora o mesmo código por 3s e não processa em paralelo.
    if (_processing) return;
    if (raw == _lastCode && now - _lastCodeTime < _debounceMs) return;
    _lastCode = raw;
    _lastCodeTime = now;
    _processar(raw);
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
    final api = _api;
    if (api == null) return;
    final etiquetas = await ListaStore.instance.getEtiquetas();
    if (etiquetas.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta adicionada');
      return;
    }
    try {
      final lista = <PapeletaPrintingData>[];
      final vistos = <String>{};
      for (final et in etiquetas) {
        for (final tipo in [Constants.tipoComum, Constants.tipoPromocional]) {
          try {
            final resp = await api.getPriceSignStandalone(_storeId, tipo,
                ean: et.ean, startDate: _today);
            for (final item in resp.items) {
              final pd = item.printingData;
              if (pd == null) continue;
              if (!vistos.add(item.ean)) continue;
              lista.add(pd.copyWith(quantity: 1, size: Constants.signSize1x1));
            }
          } catch (_) {}
        }
      }
      if (lista.isEmpty) {
        ToastUtils.show(context, 'Dados de papeleta não disponíveis');
        return;
      }
      final tamanhos = ['1×1', '2×1', '4×1', '6×1'];
      final sizes = [
        Constants.signSize1x1,
        Constants.signSize2x1,
        Constants.signSize4x1,
        Constants.signSize6x1,
      ];
      final escolha = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Tamanho da papeleta'),
          children: [
            for (var i = 0; i < tamanhos.length; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, sizes[i]),
                child: Text(tamanhos[i]),
              ),
          ],
        ),
      );
      if (escolha == null || !mounted) return;
      await Navigator.pushNamed(context, '/modelo_editavel', arguments: {
        'items': lista,
        'size': escolha,
        'mostrarCheckboxOverlay': true,
        'modoEditavel': false,
        'modoVencimentos': false,
        'semOverlay': false,
        'apiSemOverlay': true,
        'hideGerarPreview': false,
      });
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro: $e');
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD7193F),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Stack(
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Text(
                  widget.continuo
                      ? 'Escaneie os itens — volte para concluir'
                      : 'Aproxime a câmera do código (use a pinça para zoom)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (_currentZoom > 1.0)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              ),
            if (widget.continuo)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          _added == 1
                              ? '1 item adicionado'
                              : '$_added itens adicionados',
                          style: const TextStyle(
                            color: Color(0xFFD7193F),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _botaoCamera(
                            'ENVIAR IMPRESSÃO', _escolherImpressoraEEnviar),
                        const SizedBox(width: 8),
                        _botaoCamera(
                            'IMPRIMIR PAPELETA', _abrirPreviewPapeleta),
                      ],
                    ),
                  ],
                ),
              ),
          ],
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
