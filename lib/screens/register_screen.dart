import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  bool obscurePassword = true;
  bool creandoCuenta = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> crearCuenta() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final username = usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty || username.isEmpty) {
      mostrarMensaje('Completa todos los campos.');
      return;
    }

    if (creandoCuenta) return;

    setState(() {
      creandoCuenta = true;
    });

    try {
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credencial.user;

      if (user == null) {
        throw Exception('No se pudo crear el usuario.');
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .set({
            'id_usuario': user.uid,
            'nombre': name,
            'usuario': username,
            'correo': email,
            'rol': 'usuario',
            'verificado': false,
            'fecha_registro': FieldValue.serverTimestamp(),
          });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cuenta creada correctamente',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String mensaje;

      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Ya existe una cuenta con este correo.';
          break;

        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;

        case 'weak-password':
          mensaje = 'La contraseña es demasiado débil.';
          break;

        case 'operation-not-allowed':
          mensaje = 'El registro con correo y contraseña no está habilitado.';
          break;

        default:
          mensaje = 'No se pudo crear la cuenta.';
      }

      if (!mounted) return;

      mostrarMensaje(mensaje);
    } catch (e) {
      if (!mounted) return;

      mostrarMensaje('Ocurrió un error al guardar los datos de la cuenta.');
    } finally {
      if (mounted) {
        setState(() {
          creandoCuenta = false;
        });
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.poppins(fontSize: 13)),
      ),
    );
  }

  InputDecoration campoDecoracion({
    String? hintText,
    IconData? icono,
    Widget? suffixIcon,
  }) {
    const Color verde = Color(0xFF16D928);

    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
      prefixIcon: icono != null ? Icon(icono, size: 19) : null,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: verde),
      ),
    );
  }

  Widget tituloCampo(String texto) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF16D928);
    const Color verdeOscuro = Color(0xFF16A923);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
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
                    'Crear cuenta',
                    style: GoogleFonts.poppins(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Crea tu cuenta para comenzar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  tituloCampo('Correo electrónico'),

                  const SizedBox(height: 6),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !creandoCuenta,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: campoDecoracion(
                      hintText: 'correo@ejemplo.com',
                      icono: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 13),

                  tituloCampo('Contraseña'),

                  const SizedBox(height: 6),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enabled: !creandoCuenta,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: campoDecoracion(
                      hintText: '••••••••',
                      icono: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: creandoCuenta
                            ? null
                            : () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),

                  tituloCampo('Nombre'),

                  const SizedBox(height: 6),

                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    enabled: !creandoCuenta,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: campoDecoracion(
                      hintText: 'Tu nombre',
                      icono: Icons.person_outline,
                    ),
                  ),

                  const SizedBox(height: 13),

                  tituloCampo('Nombre de usuario'),

                  const SizedBox(height: 6),

                  TextField(
                    controller: usernameController,
                    enabled: !creandoCuenta,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: campoDecoracion(
                      hintText: 'nombre_usuario',
                      icono: Icons.alternate_email,
                    ),
                  ),

                  const SizedBox(height: 17),

                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: creandoCuenta ? null : crearCuenta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: creandoCuenta
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Crear cuenta',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Ya tienes una cuenta? ',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: creandoCuenta
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          'Inicia sesión',
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
