import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'services/api_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Primero recuperar la sesión de Firebase.
  await ApiService.cargarSesion();

  // Inicializar Google después de Firebase.
  await ApiService.inicializarGoogle();

  // Probar Firestore solamente después de recuperar la sesión.
  await FirestoreService.probarConexion();

  runApp(const RecetarioApp());
}

class RecetarioApp extends StatelessWidget {
  const RecetarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget pantallaInicial;

    if (ApiService.usuarioActual == null) {
      pantallaInicial = const LoginScreen();
    } else if (ApiService.rolUsuario == 'admin') {
      pantallaInicial = const AdminHomeScreen();
    } else {
      pantallaInicial = const HomeScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Armadillos',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16D928)),
      ),
      home: pantallaInicial,
    );
  }
}
