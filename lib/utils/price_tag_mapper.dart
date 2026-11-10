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
/// promotionPrice (total) e a linha de unitario usa takeAndWinPrice (cada).
PapeletaPrintingData prepararPreviewLeve(PapeletaPrintingData d) {
  final qty = (d.takeAndWinQuantity ?? 0) > 0 ? d.takeAndWinQuantity! : 0;
  if (qty <= 0) return d;
  final total = (d.promotionPrice ?? 0) > 0
      ? d.promotionPrice!
      : ((d.takeAndWinPrice ?? 0) * qty);
  final cada = (d.takeAndWinPrice ?? 0) > 0
      ? d.takeAndWinPrice!
      : (total / qty);
  return d.copyWith(
    template: Constants.signTemplateLeveGanheTotal,
    promotionPrice: total,
    takeAndWinPrice: cada,
  );
}
