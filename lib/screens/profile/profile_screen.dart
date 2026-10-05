import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:path_provider/path_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SessionManager _session = SessionManager.instance!;
  final ImagePicker _picker = ImagePicker();
  File? _fotoPerfil;

  @override
  void initState() {
    super.initState();
    _carregarFoto();
  }

  String get _nome => _session.getUserName() ?? 'Usuário';
  String get _email => _session.getUserEmail() ?? 'email@exemplo.com';
  String get _loja => _session.getUserStore();

  late final TextEditingController _ipController =
      TextEditingController(text: _session.getPrinterIp());

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _carregarFoto() {
    final path = _session.getProfilePhoto();
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) setState(() => _fotoPerfil = f);
    }
  }

  Future<void> _escolherFoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final decodificada = img.decodeImage(bytes);
      if (decodificada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar a imagem')),
        );
        return;
      }
      final circular = _aplicarMascaraCircular(decodificada);
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/profile_photo.png');
      await arquivo.writeAsBytes(img.encodePng(circular));
      _session.saveProfilePhoto(arquivo.path);
      setState(() => _fotoPerfil = arquivo);
      LogHelper.d('Profile: foto atualizada');
    } catch (e) {
      LogHelper.d('Profile: erro ao escolher foto: $e');
    }
  }

  void _removerFoto() {
    _session.clearProfilePhoto();
    setState(() => _fotoPerfil = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto removida')),
    );
  }

  img.Image _aplicarMascaraCircular(img.Image bmp) {
    final side = bmp.width < bmp.height ? bmp.width : bmp.height;
    final x0 = (bmp.width - side) ~/ 2;
    final y0 = (bmp.height - side) ~/ 2;
    var copia = img.copyCrop(bmp, x: x0, y: y0, width: side, height: side);
    if (side > 512) {
      copia = img.copyResize(copia, width: 512, height: 512, interpolation: img.Interpolation.cubic);
    }
    final finalSize = copia.width;
    final centro = finalSize / 2;
    for (var y = 0; y < finalSize; y++) {
      for (var x = 0; x < finalSize; x++) {
        final dx = x - centro + 0.5;
        final dy = y - centro + 0.5;
        if (dx * dx + dy * dy > centro * centro) {
          img.drawPixel(
            copia,
            x,
            y,
            img.ColorRgba8(0, 0, 0, 0),
            blend: img.BlendMode.direct,
          );
        }
      }
    }
    return copia;
  }

  void _salvarIp() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o IP da impressora')),
      );
      return;
    }
    _session.savePrinterIp(ip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('IP da impressora salvo: $ip')),
    );
  }

  void _confirmarSaida() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        _session.clearAll();
        LogHelper.d('Profile: logout efetuado');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFDA1C2E);
    const textSecondary = Color(0xFF5F6368);
    const textPrimary = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: brandRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 18),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  children: [
                    // Avatar
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _escolherFoto,
                        onLongPress: _fotoPerfil != null ? _removerFoto : null,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _fotoPerfil != null
                              ? Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: ClipOval(
                                    child: Image.file(
                                      _fotoPerfil!,
                                      width: 112,
                                      height: 112,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.person, color: brandRed, size: 60),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Card de informações
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Nome
                          Text(
                            _nome,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: brandRed,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, color: brandRed, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _email,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Loja
                          Row(
                            children: [
                              const Icon(Icons.store_outlined, color: brandRed, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Loja $_loja',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'IP DA IMPRESSORA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: brandRed,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextField(
                                    controller: _ipController,
                                    style: const TextStyle(
                                        fontSize: 15, color: textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Ex: 10.25.168.24',
                                      hintStyle: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 14),
                                      filled: true,
                                      fillColor: const Color(0xFFF3F4F6),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _salvarIp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'SALVAR',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Usado na impressão via socket (papeletas)',
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Divisor
                          Container(
                            height: 1,
                            color: const Color(0xFFE9EAEE),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botão Sair
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _confirmarSaida,
                              borderRadius: BorderRadius.circular(14),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, color: Colors.white, size: 18),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sair da conta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
