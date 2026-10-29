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
