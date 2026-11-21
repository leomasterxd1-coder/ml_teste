String formatBrlNumber(num value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final inteiro = (int.tryParse(fixed[0]) ?? 0).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  return '${buf.toString()},${fixed[1]}';
}

String formatBrl(num value) => 'R\$ ${formatBrlNumber(value)}';
