import 'package:flutter/services.dart';

/// Bip curto via ToneGenerator nativo (canal `minhaloja/beep`).
class Beep {
  static const MethodChannel _ch = MethodChannel('minhaloja/beep');

  /// Leitura ok / item adicionado.
  static Future<void> success() async {
    try {
      await _ch.invokeMethod('success');
    } catch (_) {}
  }

  /// Item não encontrado / falha.
  static Future<void> error() async {
    try {
      await _ch.invokeMethod('error');
    } catch (_) {}
  }
}
