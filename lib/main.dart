
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es_MX', null);

  runApp(const AlacenaSmart());
}

class AlacenaSmart extends StatelessWidget {
  const AlacenaSmart({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alacena Smart',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF397653),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F2),
          foregroundColor: Color(0xFF234B35),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
