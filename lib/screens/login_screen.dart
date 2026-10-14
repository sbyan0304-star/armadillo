import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'admin_home_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController correoController = TextEditingController();
  final TextEditingController contrasenaController = TextEditingController();

  bool mostrarContrasena = false;
  bool iniciandoSesion = false;
  bool iniciandoGoogle = false;

  @override
  void dispose() {
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  Future<void> iniciarSesion() async {
    if (correoController.text.trim().isEmpty ||
        contrasenaController.text.isEmpty) {
      mostrarMensaje('Completa todos los campos.');
      return;
    }

    setState(() {
      iniciandoSesion = true;
    });

    debugPrint('====================================');
    debugPrint('LOGIN NORMAL');
    debugPrint('Correo: ${correoController.text.trim()}');

    final resultado = await ApiService.login(
      correoController.text.trim(),
      contrasenaController.text,
    );

    debugPrint('Resultado login: $resultado');
    debugPrint('====================================');

    if (!mounted) return;

    setState(() {
      iniciandoSesion = false;
    });

    if (resultado['success'] == true) {
      final String rol =
          resultado['usuario']?['rol']?.toString() ??
          ApiService.rolUsuario ??
          'usuario';

      debugPrint('LOGIN CORRECTO');
      debugPrint('UID: ${ApiService.idUsuario}');
      debugPrint('Nombre: ${ApiService.nombreUsuario}');
      debugPrint('Correo: ${ApiService.correoUsuario}');
      debugPrint('Rol: $rol');

      if (rol == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      mostrarMensaje(
        resultado['message']?.toString() ?? 'No se pudo iniciar sesión.',
      );
    }
  }

  Future<void> iniciarSesionGoogle() async {
    if (iniciandoGoogle) return;

    setState(() {
      iniciandoGoogle = true;
    });

    debugPrint('====================================');
    debugPrint('INICIANDO LOGIN CON GOOGLE');
    debugPrint('====================================');

    try {
      final resultado = await ApiService.loginGoogle();

      debugPrint('====================================');
      debugPrint('RESPUESTA GOOGLE');
      debugPrint('Resultado: $resultado');
      debugPrint('Success: ${resultado['success']}');
      debugPrint('Message: ${resultado['message']}');
      debugPrint('Usuario: ${resultado['usuario']}');
      debugPrint('====================================');

      if (!mounted) return;

      setState(() {
        iniciandoGoogle = false;
      });

      if (resultado['success'] == true) {
        final String rol =
            resultado['usuario']?['rol']?.toString() ??
            ApiService.rolUsuario ??
            'usuario';

        debugPrint('====================================');
        debugPrint('GOOGLE LOGIN CORRECTO');
        debugPrint('UID: ${ApiService.idUsuario}');
        debugPrint('Nombre: ${ApiService.nombreUsuario}');
        debugPrint('Usuario: ${ApiService.usuario}');
        debugPrint('Correo: ${ApiService.correoUsuario}');
        debugPrint('Rol: $rol');
        debugPrint('====================================');

        if (rol == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        final String mensaje =
            resultado['message']?.toString() ??
            'No se pudo iniciar sesión con Google.';

        if (mensaje.isNotEmpty && mensaje != 'Inicio de sesión cancelado.') {
          mostrarMensaje(mensaje);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('ERROR GOOGLE LOGIN');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('====================================');

      if (!mounted) return;

      setState(() {
        iniciandoGoogle = false;
      });

      mostrarMensaje('Error al iniciar sesión con Google.');
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF16D928);
    const Color verdeOscuro = Color(0xFF16A923);

    final bool bloqueado = iniciandoSesion || iniciandoGoogle;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 68,
                      height: 68,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'armadillo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Recetario Regional',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Iniciar sesión',
                    style: GoogleFonts.poppins(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Ingresa a tu cuenta para continuar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Correo electrónico',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  TextField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !bloqueado,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'correo@ejemplo.com',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        size: 19,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: verde,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),

                  Text(
                    'Contraseña',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  TextField(
                    controller: contrasenaController,
                    obscureText: !mostrarContrasena,
                    enabled: !bloqueado,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 19,
                      ),
                      suffixIcon: IconButton(
                        onPressed: bloqueado
                            ? null
                            : () {
                                setState(() {
                                  mostrarContrasena =
                                      !mostrarContrasena;
                                });
                              },
                        icon: Icon(
                          mostrarContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 19,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: verde,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 17),

                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: bloqueado ? null : iniciarSesion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: iniciandoSesion
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Iniciar sesión',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        child: Text(
                          'o continúa con',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: bloqueado
                          ? null
                          : iniciarSesionGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: iniciandoGoogle
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: verdeOscuro,
                              ),
                            )
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google.png',
                                  width: 19,
                                  height: 19,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.account_circle_outlined,
                                      size: 20,
                                    );
                                  },
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  'Continuar con Google',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿No tienes una cuenta? ',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: bloqueado
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RegisterScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          'Regístrate',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: verdeOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
