import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/session_manager.dart';
import 'core/lista_store.dart';
import 'models/models.dart';
import 'network/api_client.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/login_webview_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/etiquetas/etiquetas_screen.dart';
import 'screens/etiquetas/gondola_editavel_screen.dart';
import 'screens/papeletas/papeletas_diarias_screen.dart';
import 'screens/pdf/pdf_viewer_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/modelo/modelo_editavel_screen.dart';
import 'screens/barcode/barcode_scanner_screen.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = await SessionManager.getInstance();
  await sessionManager.getToken();
  ApiClient.instance.init(sessionManager);

  runApp(
    MultiProvider(
      providers: [
        Provider<SessionManager>.value(value: sessionManager),
        Provider<ListaStore>.value(value: ListaStore.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ML Flutter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/etiquetas': (context) => const EtiquetasScreen(),
        '/papeletas_diarias': (context) => const PapeletasDiariasScreen(),
        '/pdf_viewer': (context) => const PdfViewerScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/modelo_editavel': (context) => const ModeloEditavelScreen(),
        '/gondola_editavel': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return GondolaEditavelScreen(
            items: (args?['items'] as List?)?.cast<PrintingData>() ?? [],
            printerId: args?['printerId'] as String? ?? 'ZEBRA_1',
          );
        },
        '/barcode': (context) => const BarcodeScannerScreen(),
      },
    );
  }
}
