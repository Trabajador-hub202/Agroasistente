import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'plant_detector_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgroasistenteApp());
}

class AgroasistenteApp extends StatelessWidget {
  const AgroasistenteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agroasistente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde Agrónomo
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const PlantDetectorScreen(),
    );
  }
}
