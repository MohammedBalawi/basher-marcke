import 'package:bashar_market/shared_pref/shared.dart';
import 'package:flutter/material.dart';
import 'launch_screen/launch_screen.dart';
import 'login_screen/login_screen.dart';
import 'read_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefController().initPreferences();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/launch_screen',
      routes: {
        '/barcode_scanner_page': (context) => const BarcodeScannerPage(),
        '/launch_screen': (context) => const LaunchScreen(),
        '/login_screen': (context) => const LoginScreen(),
      },
    );
  }
}
