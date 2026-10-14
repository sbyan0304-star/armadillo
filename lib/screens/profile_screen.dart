import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_navigation.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final nombreController = TextEditingController();
  final usuarioController = TextEditingController();
  final correoController = TextEditingController();

  StreamSubscription<User?>? _sesionSubscription;

  bool cargandoPerfil = true;
  int cantidadFavoritos = 0;
  String uidUsuario = '';

  @override
  void initState() {
    super.initState();
    _escucharSesion();
  }

  @override
  void dispose() {
    _sesionSubscription?.cancel();

    nombreController.dispose();
    usuarioController.dispose();
    correoController.dispose();

    super.dispose();
  }

  void _escucharSesion() {
    _sesionSubscription = auth.authStateChanges().listen((usuarioFirebase) {
      if (usuarioFirebase == null) {
        _irAlLogin();
        return;
      }

      if (uidUsuario != usuarioFirebase.uid) {
        uidUsuario = usuarioFirebase.uid;
        _cargarPerfil();
      }
    });
  }

  Future<void> _cargarPerfil() async {
    if (!mounted) return;

    setState(() {
      cargandoPerfil = true;
    });

    try {
      final usuarioFirebase = auth.currentUser;

      if (usuarioFirebase == null) {
        _irAlLogin();
        return;
      }

      final documento = await firestore
          .collection('usuarios')
          .doc(usuarioFirebase.uid)
          .get();

      if (!documento.exists) {
        if (!mounted) return;

        setState(() {
          cargandoPerfil = false;
        });

        mostrarMensaje(
          'No se encontró la información de tu perfil.',
          error: true,
        );

        return;
      }

      final datos = documento.data() ?? {};

      final String nombre =
          datos['nombre']?.toString().trim().isNotEmpty == true
          ? datos['nombre'].toString()
          : 'Usuario';

      final String usuario =
          datos['usuario']?.toString().trim().isNotEmpty == true
          ? datos['usuario'].toString()
          : 'usuario';

      final String correo =
          datos['correo']?.toString().trim().isNotEmpty == true
          ? datos['correo'].toString()
          : (usuarioFirebase.email ?? '');

      nombreController.text = nombre;
      usuarioController.text = usuario;
      correoController.text = correo;

      await _cargarCantidadFavoritos(usuarioFirebase.uid);

      if (!mounted) return;

      setState(() {
        cargandoPerfil = false;
      });
    } catch (e) {
      debugPrint('ERROR CARGANDO PERFIL: $e');

      if (!mounted) return;

      setState(() {
        cargandoPerfil = false;
      });

      mostrarMensaje('No se pudo cargar el perfil.', error: true);
    }
  }

  Future<void> _cargarCantidadFavoritos(String uid) async {
    try {
      final resultado = await firestore
          .collection('usuarios')
          .doc(uid)
          .collection('favoritos')
          .get();

      if (!mounted) return;

      setState(() {
        cantidadFavoritos = resultado.docs.length;
      });
    } catch (e) {
      debugPrint('ERROR CARGANDO FAVORITOS: $e');

      if (!mounted) return;

      setState(() {
        cantidadFavoritos = 0;
      });
    }
  }

  Future<void> actualizarFavoritos() async {
    final usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) return;

    await _cargarCantidadFavoritos(usuarioFirebase.uid);
  }

  void mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: error ? const Color(0xffD32F2F) : verdeOscuro,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> cerrarSesion() async {
    await auth.signOut();
  }

  Future<void> abrirNotificaciones() async {
    final usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      mostrarMensaje('No se encontró la sesión del usuario.', error: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(idUsuario: usuarioFirebase.uid),
      ),
    );
  }

  void abrirEditarPerfil() {
    final nombreControllerDialog = TextEditingController(
      text: nombreController.text,
    );

    final usuarioControllerDialog = TextEditingController(
      text: usuarioController.text,
    );

    final correoControllerDialog = TextEditingController(
      text: correoController.text,
    );

    bool guardando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> guardar() async {
              final nombre = nombreControllerDialog.text.trim();

              final usuario = usuarioControllerDialog.text.trim();

              final correo = correoControllerDialog.text.trim();

              if (nombre.isEmpty || usuario.isEmpty || correo.isEmpty) {
                mostrarMensaje(
                  'Todos los campos son obligatorios.',
                  error: true,
                );
                return;
              }

              final correoValido = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(correo);

              if (!correoValido) {
                mostrarMensaje(
                  'Ingresa un correo electrónico válido.',
                  error: true,
                );
                return;
              }

              setModalState(() {
                guardando = true;
              });

              try {
                final usuarioFirebase = auth.currentUser;

                if (usuarioFirebase == null) {
                  setModalState(() {
                    guardando = false;
                  });

                  mostrarMensaje(
                    'No se encontró la sesión del usuario.',
                    error: true,
                  );

                  return;
                }

                final documento = await firestore
                    .collection('usuarios')
                    .doc(usuarioFirebase.uid)
                    .get();

                if (!documento.exists) {
                  setModalState(() {
                    guardando = false;
                  });

                  mostrarMensaje('No se encontró tu perfil.', error: true);

                  return;
                }

                final datos = documento.data() ?? {};

                if (datos['rol']?.toString() == 'admin') {
                  setModalState(() {
                    guardando = false;
                  });

                  mostrarMensaje(
                    'Esta cuenta corresponde a un administrador.',
                    error: true,
                  );

                  return;
                }

                final correoAnterior = usuarioFirebase.email ?? '';

                if (correo != correoAnterior) {
                  await usuarioFirebase.verifyBeforeUpdateEmail(correo);
                }

                await firestore
                    .collection('usuarios')
                    .doc(usuarioFirebase.uid)
                    .update({
                      'nombre': nombre,
                      'usuario': usuario,
                      'correo': correo,
                    });

                await usuarioFirebase.updateDisplayName(nombre);

                nombreController.text = nombre;
                usuarioController.text = usuario;
                correoController.text = correo;

                if (!mounted) return;

                Navigator.pop(dialogContext);

                await _cargarPerfil();

                if (!mounted) return;

                mostrarMensaje(
                  correo != correoAnterior
                      ? 'Perfil actualizado. Revisa tu correo para confirmar el cambio.'
                      : 'Perfil actualizado correctamente.',
                );
              } on FirebaseAuthException catch (e) {
                setModalState(() {
                  guardando = false;
                });

                String mensaje = 'No se pudo actualizar el perfil.';

                switch (e.code) {
                  case 'requires-recent-login':
                    mensaje =
                        'Por seguridad, vuelve a iniciar sesión antes de cambiar el correo.';
                    break;

                  case 'email-already-in-use':
                    mensaje = 'Ese correo electrónico ya está en uso.';
                    break;

                  case 'invalid-email':
                    mensaje = 'El correo electrónico no es válido.';
                    break;

                  case 'network-request-failed':
                    mensaje = 'No hay conexión con Firebase.';
                    break;
                }

                mostrarMensaje(mensaje, error: true);
              } catch (e) {
                setModalState(() {
                  guardando = false;
                });

                mostrarMensaje('No se pudo actualizar el perfil.', error: true);
              }
            }

            return construirDialogoPerfil(
              context: context,
              titulo: 'Editar perfil',
              icono: Icons.person_outline,
              hijos: [
                construirDescripcionDialogo(
                  'Actualiza la información de tu cuenta.',
                ),
                const SizedBox(height: 20),
                construirCampoDialogo(
                  controller: nombreControllerDialog,
                  label: 'Nombre',
                  icono: Icons.person_outline,
                  enabled: !guardando,
                ),
                const SizedBox(height: 14),
                construirCampoDialogo(
                  controller: usuarioControllerDialog,
                  label: 'Usuario',
                  icono: Icons.alternate_email,
                  enabled: !guardando,
                ),
                const SizedBox(height: 14),
                construirCampoDialogo(
                  controller: correoControllerDialog,
                  label: 'Correo electrónico',
                  icono: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !guardando,
                ),
                const SizedBox(height: 24),
                construirBotonesDialogo(
                  context: context,
                  onCancel: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  onConfirm: guardando ? null : guardar,
                  loading: guardando,
                  textoConfirmar: 'Guardar cambios',
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nombreControllerDialog.dispose();
      usuarioControllerDialog.dispose();
      correoControllerDialog.dispose();
    });
  }

  void abrirCambiarContrasena() {
    final actualController = TextEditingController();

    final nuevaController = TextEditingController();

    final confirmarController = TextEditingController();

    bool guardando = false;
    bool ocultarActual = true;
    bool ocultarNueva = true;
    bool ocultarConfirmar = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> cambiarContrasena() async {
              final actual = actualController.text;

              final nueva = nuevaController.text;

              final confirmar = confirmarController.text;

              if (actual.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
                mostrarMensaje('Completa todos los campos.', error: true);
                return;
              }

              if (nueva.length < 6) {
                mostrarMensaje(
                  'La nueva contraseña debe tener mínimo 6 caracteres.',
                  error: true,
                );
                return;
              }

              if (nueva != confirmar) {
                mostrarMensaje('Las contraseñas no coinciden.', error: true);
                return;
              }

              setModalState(() {
                guardando = true;
              });

              try {
                final usuarioFirebase = auth.currentUser;

                if (usuarioFirebase == null) {
                  setModalState(() {
                    guardando = false;
                  });

                  mostrarMensaje(
                    'No se encontró la sesión del usuario.',
                    error: true,
                  );

                  return;
                }

                final correo = usuarioFirebase.email;

                if (correo == null || correo.isEmpty) {
                  setModalState(() {
                    guardando = false;
                  });

                  mostrarMensaje(
                    'Tu cuenta no tiene un correo asociado.',
                    error: true,
                  );

                  return;
                }

                final credencial = EmailAuthProvider.credential(
                  email: correo,
                  password: actual,
                );

                await usuarioFirebase.reauthenticateWithCredential(credencial);

                await usuarioFirebase.updatePassword(nueva);

                if (!mounted) return;

                Navigator.pop(dialogContext);

                mostrarMensaje('Contraseña actualizada correctamente.');
              } on FirebaseAuthException catch (e) {
                setModalState(() {
                  guardando = false;
                });

                String mensaje = 'No se pudo cambiar la contraseña.';

                switch (e.code) {
                  case 'wrong-password':
                  case 'invalid-credential':
                    mensaje = 'La contraseña actual es incorrecta.';
                    break;

                  case 'requires-recent-login':
                    mensaje =
                        'Por seguridad, vuelve a iniciar sesión e inténtalo nuevamente.';
                    break;

                  case 'weak-password':
                    mensaje = 'La nueva contraseña es demasiado débil.';
                    break;

                  case 'network-request-failed':
                    mensaje = 'No hay conexión con Firebase.';
                    break;
                }

                mostrarMensaje(mensaje, error: true);
              } catch (e) {
                setModalState(() {
                  guardando = false;
                });

                mostrarMensaje(
                  'No se pudo cambiar la contraseña.',
                  error: true,
                );
              }
            }

            return construirDialogoPerfil(
              context: context,
              titulo: 'Cambiar contraseña',
              icono: Icons.lock_outline,
              hijos: [
                construirDescripcionDialogo(
                  'Protege tu cuenta utilizando una contraseña segura.',
                ),
                const SizedBox(height: 20),
                construirCampoDialogo(
                  controller: actualController,
                  label: 'Contraseña actual',
                  icono: Icons.lock_outline,
                  obscureText: ocultarActual,
                  enabled: !guardando,
                  suffixIcon: IconButton(
                    onPressed: guardando
                        ? null
                        : () {
                            setModalState(() {
                              ocultarActual = !ocultarActual;
                            });
                          },
                    icon: Icon(
                      ocultarActual
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                construirCampoDialogo(
                  controller: nuevaController,
                  label: 'Nueva contraseña',
                  icono: Icons.lock_outline,
                  obscureText: ocultarNueva,
                  enabled: !guardando,
                  suffixIcon: IconButton(
                    onPressed: guardando
                        ? null
                        : () {
                            setModalState(() {
                              ocultarNueva = !ocultarNueva;
                            });
                          },
                    icon: Icon(
                      ocultarNueva
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                construirCampoDialogo(
                  controller: confirmarController,
                  label: 'Confirmar contraseña',
                  icono: Icons.lock_outline,
                  obscureText: ocultarConfirmar,
                  enabled: !guardando,
                  suffixIcon: IconButton(
                    onPressed: guardando
                        ? null
                        : () {
                            setModalState(() {
                              ocultarConfirmar = !ocultarConfirmar;
                            });
                          },
                    icon: Icon(
                      ocultarConfirmar
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                construirBotonesDialogo(
                  context: context,
                  onCancel: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  onConfirm: guardando ? null : cambiarContrasena,
                  loading: guardando,
                  textoConfirmar: 'Actualizar contraseña',
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      actualController.dispose();
      nuevaController.dispose();
      confirmarController.dispose();
    });
  }

  Widget construirDialogoPerfil({
    required BuildContext context,
    required String titulo,
    required IconData icono,
    required List<Widget> hijos,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffE7E7E7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffEAF8EC),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icono, size: 22, color: verdeOscuro),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      titulo,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xffF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 19,
                        color: Color(0xff555555),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...hijos,
            ],
          ),
        ),
      ),
    );
  }

  Widget construirDescripcionDialogo(String texto) {
    return Text(
      texto,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.4,
        color: const Color(0xff777777),
      ),
    );
  }

  Widget construirCampoDialogo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xff888888),
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: verdeOscuro,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icono, size: 20, color: const Color(0xff777777)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xffF8F9F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffE3E3E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffE3E3E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xff8BEA96), width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffE8E8E8)),
        ),
      ),
    );
  }

  Widget construirBotonesDialogo({
    required BuildContext context,
    required VoidCallback? onCancel,
    required VoidCallback? onConfirm,
    required bool loading,
    required String textoConfirmar,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffF5F5F5),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff555555),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onConfirm,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: verde,
                borderRadius: BorderRadius.circular(13),
              ),
              child: loading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      textoConfirmar,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _irAlLogin() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = nombreController.text.isNotEmpty
        ? nombreController.text
        : 'Usuario';

    final usuario = usuarioController.text.isNotEmpty
        ? usuarioController.text
        : 'usuario';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: cargandoPerfil && nombreController.text.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: verde,
                          ),
                        )
                      : RefreshIndicator(
                          color: verde,
                          backgroundColor: Colors.white,
                          onRefresh: _cargarPerfil,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTitle(),
                                const SizedBox(height: 22),
                                _buildProfileHeader(
                                  nombre: nombre,
                                  usuario: usuario,
                                ),
                                const SizedBox(height: 24),
                                _buildStats(),
                                const SizedBox(height: 30),
                                _buildSectionTitle('CUENTA'),
                                const SizedBox(height: 7),
                                _buildOption(
                                  icon: Icons.person_outline,
                                  iconBackground: const Color(0xffE9F9EB),
                                  iconColor: verdeOscuro,
                                  title: 'Editar perfil',
                                  subtitle: 'Actualiza tus datos personales',
                                  onTap: abrirEditarPerfil,
                                ),
                                _buildOption(
                                  icon: Icons.favorite_border_rounded,
                                  iconBackground: const Color(0xffEDF9EF),
                                  iconColor: verde,
                                  title: 'Mis favoritos',
                                  subtitle: 'Recetas que has guardado',
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const FavoritesScreen(),
                                      ),
                                    );

                                    await actualizarFavoritos();
                                  },
                                ),
                                const SizedBox(height: 27),
                                _buildSectionTitle('PREFERENCIAS'),
                                const SizedBox(height: 7),
                                _buildOption(
                                  icon: Icons.notifications_none_rounded,
                                  iconBackground: const Color(0xffE8F8EA),
                                  iconColor: const Color(0xff24B932),
                                  title: 'Notificaciones',
                                  subtitle: 'Administra tus avisos',
                                  onTap: abrirNotificaciones,
                                ),
                                _buildOption(
                                  icon: Icons.lock_outline_rounded,
                                  iconBackground: const Color(0xffEFFAF0),
                                  iconColor: verdeOscuro,
                                  title: 'Cambiar contraseña',
                                  subtitle:
                                      'Actualiza la seguridad de tu cuenta',
                                  onTap: abrirCambiarContrasena,
                                ),
                                const SizedBox(height: 30),
                                _buildLogoutButton(),
                                const SizedBox(height: 14),
                                Center(
                                  child: Text(
                                    'armadillos',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff9A9A9A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Center(
                                  child: Text(
                                    'Recetas de nuestra región',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: const Color(0xffB0B0B0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: BottomNavigation(currentIndex: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 4),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 9),
          Text(
            'armadillo',
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Mi perfil',
      style: GoogleFonts.poppins(
        fontSize: 28,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: Colors.black,
      ),
    );
  }

  Widget _buildProfileHeader({
    required String nombre,
    required String usuario,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            color: Color(0xffEAF8EC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 40,
            color: Color(0xff222222),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '@$usuario',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff777777),
                ),
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: abrirEditarPerfil,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffD8D8D8)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Editar perfil',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xffF8F9F8),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Text(
            cargandoPerfil ? '—' : cantidadFavoritos.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Favoritos',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: const Color(0xff777777),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: const Color(0xff888888),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xffEAEAEA), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xff888888),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xff888888),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: cerrarSesion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xffFFF1F1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xffF4D2D2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 19,
              color: Color(0xffD34B4B),
            ),
            const SizedBox(width: 8),
            Text(
              'Cerrar sesión',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xffD34B4B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
