import 'dart:typed_data';

import 'package:dio/dio.dart';

class ProductImageResult {
  final String url;
  final String fonte;
  const ProductImageResult(this.url, this.fonte);
}

/// Busca imagem do produto em várias APIs (Americanas, SI5, Bluesoft e Google).
class ProductImageService {
  ProductImageService._();

  static const String _si5Token =
      '367|yrBhfTTRoFVIXtXkekXzeIxAgyfsY6FKZ8H0ft6Y7b4ca508';
  static const String _serpApiKey =
      'f6b852abd4c78277772ea524da2574e68f0623e1179937cbcd76f1117bc942a9';
  static const String _serpApiKeyTextSearch =
      '67902270082286b2ab5ed9467bf3a255afa627572ff5acc1110beeb766802c7d';
  static const String _bluesoftApiKey = 'LFHnNIwZnn7atj61QgyzBA';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static Future<ProductImageResult?> buscarImagem(
    String ean,
    String store, {
    String descricao = '',
  }) async {
    final americanas = await _americanas(ean, store);
    if (americanas != null) {
      return ProductImageResult(americanas, 'Americanas');
    }
    final si5 = await _si5(ean);
    if (si5 != null) return ProductImageResult(si5, 'SI5 Global');

    final bluesoftEan = await _bluesoftEan(ean);
    if (bluesoftEan != null) {
      return ProductImageResult(bluesoftEan, 'Bluesoft');
    }
    if (descricao.isNotEmpty) {
      final bluesoftDesc = await _bluesoftDescricao(descricao);
      if (bluesoftDesc != null) {
        return ProductImageResult(bluesoftDesc, 'Bluesoft');
      }
    }

    final googleImagens = await _googleImagens(ean, descricao);
    if (googleImagens != null) {
      return ProductImageResult(googleImagens, 'Google Imagens');
    }
    final googleShopping = await _googleShopping(ean, descricao);
    if (googleShopping != null) {
      return ProductImageResult(googleShopping, 'Google Shopping');
    }
    return null;
  }

  static Future<Uint8List?> baixarBytes(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) return null;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _americanas(String ean, String store) async {
    if (ean.isEmpty) return null;
    try {
      final response = await _dio.get(
        'https://sl-bff-report.americanas.io/web/price-scanner/store/$store/ean/$ean',
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data is Map) {
        final url = (data['imageUrl'] ?? '').toString().trim();
        if (url.startsWith('http')) return url;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _si5(String ean) async {
    final codigo = ean.replaceAll(RegExp(r'\D'), '');
    if (codigo.isEmpty) return null;
    try {
      final response = await _dio.get(
        'https://global.si5.com.br/api/produtos/$codigo',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_si5Token',
            'Accept': 'application/json',
          },
        ),
      );
      final data = response.data;
      if (data is Map) {
        final url = (data['imagem_url'] ?? '').toString().trim();
        if (url.startsWith('http')) return url;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _bluesoftEan(String ean) async {
    if (ean.isEmpty) return null;
    try {
      final response = await _dio.get(
        'https://api.cosmos.bluesoft.com.br/gtins/$ean',
        options: Options(
          headers: {
            'X-API-KEY': _bluesoftApiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      if (data is Map) return _primeiraImagem(data['images']);
    } catch (_) {}
    return null;
  }

  static Future<String?> _bluesoftDescricao(String descricao) async {
    try {
      final query = Uri.encodeQueryComponent(descricao);
      final response = await _dio.get(
        'https://api.cosmos.bluesoft.com.br/products?query=$query',
        options: Options(
          headers: {
            'X-API-KEY': _bluesoftApiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      if (data is Map) {
        final produtos = data['products'];
        if (produtos is List && produtos.isNotEmpty) {
          final p = produtos.first;
          if (p is Map) return _primeiraImagem(p['images']);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _googleImagens(String ean, String descricao) async {
    final termo = [descricao.trim(), ean]
        .where((e) => e.isNotEmpty)
        .join(' ')
        .trim();
    if (termo.isEmpty) return null;
    try {
      final query = Uri.encodeQueryComponent('$termo produto');
      final response = await _dio.get(
        'https://serpapi.com/search?engine=google&q=$query&tbm=isch&api_key=$_serpApiKey&ijn=0',
      );
      final data = response.data;
      if (data is Map) {
        final imagens = data['images_results'];
        if (imagens is List) {
          for (final img in imagens.take(3)) {
            if (img is! Map) continue;
            var url = (img['original'] ?? '').toString().trim();
            if (url.isEmpty) {
              url = (img['thumbnail'] ?? '').toString().trim();
            }
            if (url.startsWith('http') &&
                !url.contains('placeholder') &&
                !url.contains('default') &&
                !url.contains('no-image')) {
              return url;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _googleShopping(String ean, String descricao) async {
    final termo = descricao.trim().isNotEmpty ? descricao.trim() : ean;
    if (termo.isEmpty) return null;
    try {
      final query = Uri.encodeQueryComponent(termo);
      final response = await _dio.get(
        'https://serpapi.com/search.json?engine=google&q=$query&tbm=shop&api_key=$_serpApiKeyTextSearch&gl=br&hl=pt',
      );
      final data = response.data;
      if (data is Map) {
        final shopping = data['shopping_results'];
        if (shopping is List) {
          for (final item in shopping.take(5)) {
            if (item is! Map) continue;
            final url = (item['thumbnail'] ?? '')
                .toString()
                .trim()
                .replaceAll('http://', 'https://');
            if (url.startsWith('http')) return url;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _primeiraImagem(dynamic images) {
    if (images is! List) return null;
    for (final img in images) {
      final url = (img ?? '').toString().trim();
      if (url.startsWith('http')) {
        return url.replaceAll('http://', 'https://');
      }
    }
    return null;
  }
}
