import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/models/models.dart';

PrintingData toPrintingData(SingleLabelPrintingData d) => PrintingData(
      ean: d.ean,
      description: d.description,
      department: d.department,
      displayPrice: d.displayPrice,
      price: d.price,
      promotionalPrice: d.promotionalPrice,
      quantity: d.quantity,
      movementType: d.movementType,
      unit: d.unit,
      unitQty: d.unitQty,
      unitValue: d.unitValue,
      printUnitValue: d.printUnitValue,
      codSap: d.codSap,
      takeAndWin: d.takeAndWin,
      referenceDate: d.referenceDate,
      template: d.template,
      installments: d.installments,
    );

PriceTag singleToPriceTag(SingleLabelItem item) => PriceTag(
      id: item.id,
      sap: item.sap,
      department: item.department,
      ean: item.ean,
      description: item.description,
      startDate: item.startDate,
      endDate: item.endDate,
      duration: item.duration,
      price: item.price,
      movement: item.movement,
      status: item.status,
      checkbox: false,
      quantity: item.quantity,
      printingData:
          item.printingData != null ? toPrintingData(item.printingData!) : null,
    );

/// Normaliza o leve_ganhe_cada para o mesmo conteúdo do promocional
/// (leve_ganhe_total), para o scanner mostrar "Leve X por R$ ..." igual.
PapeletaPrintingData ajustarDadosLeveGanhe(PapeletaPrintingData d) {
  // Mantem o JSON original esperado pela API.
  return d;
}

/// Ajuste apenas para preview: no template, o valor grande usa
/// takeAndWinPrice (total) e a linha de unitario usa promotionPrice (cada).
PapeletaPrintingData prepararPreviewLeve(PapeletaPrintingData d) {
  final qty = (d.takeAndWinQuantity ?? 0) > 0 ? d.takeAndWinQuantity! : 0;
  if (qty <= 0) return d;
  final pp = d.promotionPrice ?? 0;
  final tp = d.takeAndWinPrice ?? 0;
  double total, cada;
  if (pp > 0 && tp > 0) {
    if (pp > tp) {
      total = pp;
      cada = tp;
    } else {
      total = tp;
      cada = pp;
    }
  } else if (pp > 0) {
    total = pp;
    cada = pp / qty;
  } else if (tp > 0) {
    total = tp;
    cada = tp / qty;
  } else {
    return d;
  }
  return d.copyWith(
    template: Constants.signTemplateLeveGanheTotal,
    promotionPrice: cada,
    takeAndWinPrice: total,
  );
}
