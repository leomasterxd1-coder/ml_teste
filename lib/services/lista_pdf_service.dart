import 'dart:io';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Gera um PDF em formato de relatório/tabela com os itens da lista.
/// Colunas: Quantidade, EAN, Descrição e Código de Barras (EAN-13).
/// Depois oferece compartilhamento.
class ListaPdfService {
  ListaPdfService._();

  /// Gera o PDF com os [itens]. Cada item usa a quantidade selecionada.
  static Future<Uint8List> gerarRelatorioEtiquetas(List<PriceTag> itens) async {
    final doc = pw.Document();
    final logoBytes =
        (await rootBundle.load('assets/icons/americanas_logo.png'))
            .buffer
            .asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              children: [
                pw.Image(logo, width: 26, height: 26),
                pw.SizedBox(width: 8),
                pw.Text(
                  'Relatório de Etiquetas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(44),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(190),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red700),
                children: [
                  _celula('Qtd', header: true),
                  _celula('COD EAN', header: true),
                  _celula('DESCRIÇÃO', header: true),
                  _celula('CÓDIGO DE BARRAS', header: true),
                ],
              ),
              for (final t in itens)
                pw.TableRow(
                  children: [
                    _celula(t.quantity.toString()),
                    _celula(t.ean),
                    _celula(t.description),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.SizedBox(
                        width: 175,
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(t.description,
                                style: const pw.TextStyle(fontSize: 9),
                                textAlign: pw.TextAlign.center),
                            pw.SizedBox(height: 2),
                            pw.BarcodeWidget(
                              barcode: _barcodePara(t.ean),
                              data: t.ean,
                              width: 175,
                              height: 34,
                              drawText: false,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(t.ean,
                                style: const pw.TextStyle(fontSize: 9),
                                textAlign: pw.TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total de etiquetas: ${itens.fold<int>(0, (s, t) => s + t.quantity)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Gera o PDF e oferece o compartilhamento do arquivo.
  static Future<void> compartilharRelatorioEtiquetas(
      List<PriceTag> itens) async {
    final bytes = await gerarRelatorioEtiquetas(itens);
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/relatorio_etiquetas_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf');
    await _escreverArquivo(arquivo, bytes);
    await Share.shareXFiles(
      [XFile(arquivo.path, mimeType: 'application/pdf')],
      text: 'Relatório de Etiquetas',
    );
  }

  /// Gera o PDF a partir de itens de papeletas (PriceSign).
  static Future<Uint8List> gerarRelatorioPapeletas(
      List<PriceSign> itens) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Relatório de Papeletas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Quantidade', 'EAN', 'SAP', 'Descrição'],
            data: [
              for (final s in itens)
                [
                  s.quantity.toString(),
                  s.ean,
                  s.sap,
                  s.description,
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.red700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(100),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FlexColumnWidth(),
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total de papeletas: ${itens.fold<int>(0, (s, t) => s + t.quantity)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> compartilharRelatorioPapeletas(
      List<PriceSign> itens) async {
    final bytes = await gerarRelatorioPapeletas(itens);
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/relatorio_papeletas_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf');
    await _escreverArquivo(arquivo, bytes);
    await Share.shareXFiles(
      [XFile(arquivo.path, mimeType: 'application/pdf')],
      text: 'Relatório de Papeletas',
    );
  }

  static pw.Widget _celula(String texto, {bool header = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.center,
          style: header
              ? pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                )
              : const pw.TextStyle(fontSize: 10),
        ),
      );

  /// EAN-13 quando válido; senão CODE_128 (aceita qualquer conteúdo).
  static Barcode _barcodePara(String ean) {
    if (_ean13Valido(ean)) return Barcode.ean13();
    return Barcode.code128();
  }

  static bool _ean13Valido(String ean) {
    if (!RegExp(r'^\d{13}$').hasMatch(ean)) return false;
    var soma = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(ean[i]);
      soma += (i.isEven) ? d : d * 3;
    }
    final dv = (10 - (soma % 10)) % 10;
    return dv == int.parse(ean[12]);
  }

  static Future<void> _escreverArquivo(File arquivo, Uint8List bytes) async {
    await arquivo.writeAsBytes(bytes, flush: true);
  }
}
