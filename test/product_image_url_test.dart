import 'package:flutter_test/flutter_test.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/services/product_image_service.dart';

void main() {
  test('URL do pedido vira imagem grande e https', () {
    const entrada =
        'https://americanas.vteximg.com.br/arquivos/ids/37706410-88-88/7622210674050_1.jpg?v=639234347947600000';
    expect(
      ProductImageService.normalizarUrl(entrada),
      'https://americanas.vteximg.com.br/arquivos/ids/37706410-1000-1000/7622210674050_1.jpg?v=639234347947600000',
    );
    expect(
      ProductImageService.normalizarUrl(
          'http://americanas.vteximg.com.br/arquivos/ids/1-88-88/a.jpg'),
      'https://americanas.vteximg.com.br/arquivos/ids/1-1000-1000/a.jpg',
    );
  });

  test('urlImagem do pedido e lida no item e no _printingData', () {
    const url =
        'https://americanas.vteximg.com.br/arquivos/ids/37706410-88-88/7622210674050_1.jpg?v=639234347947600000';
    final tag = PriceTag.fromJson({'ean': '7622210674050', 'urlImagem': url});
    final nested = PriceTag.fromJson({
      'ean': '7622210674050',
      '_printingData': {'urlImagem': url},
    });
    final avulsa =
        SingleLabelItem.fromJson({'ean': '7622210674050', 'urlImagem': url});
    expect(tag.urlImagem, url);
    expect(nested.urlImagem, url);
    expect(avulsa.urlImagem, url);
  });
}
