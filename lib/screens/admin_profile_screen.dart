import 'dart:async';

import 'package:armadillo/screens/admin_recipes_screen.dart';
import 'package:armadillo/screens/login_screen.dart';
import 'package:armadillo/widgets/admin_bottom_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final nombreController = TextEditingController();
  final usuarioController = TextEditingController();
  final correoController = TextEditingController();

  final actualPasswordController = TextEditingController();
  final nuevaPasswordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();

  StreamSubscription<User?>? _sesionSubscription;

  bool cargandoPerfil = true;
  int cantidadRecetas = 0;

  String uidAdmin = '';

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

    actualPasswordController.dispose();
    nuevaPasswordController.dispose();
    confirmarPasswordController.dispose();

    super.dispose();
  }

  void _escucharSesion() {
    _sesionSubscription = auth.authStateChanges().listen((User? usuario) {
      if (!mounted) return;

      if (usuario == null) {
        _irAlLogin();
        return;
      }

      if (uidAdmin != usuario.uid) {
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
      final User? usuarioFirebase = auth.currentUser;

      if (usuarioFirebase == null) {
        if (!mounted) return;

        setState(() {
          cargandoPerfil = false;
        });

        _irAlLogin();
        return;
      }

      final String uid = usuarioFirebase.uid;

      final documento = await firestore.collection('usuarios').doc(uid).get();

      if (!documento.exists) {
        debugPrint('PERFIL ADMIN: no existe usuarios/$uid');

        if (!mounted) return;

        setState(() {
          cargandoPerfil = false;
        });

        _mostrarMensaje('No se encontró el perfil de esta cuenta.', false);

        return;
      }

      final datos = documento.data();

      if (datos == null) {
        if (!mounted) return;

        setState(() {
          cargandoPerfil = false;
        });

        _mostrarMensaje('No se pudieron obtener los datos del perfil.', false);

        return;
      }

      final String rol = datos['rol']?.toString().trim().toLowerCase() ?? '';

      if (rol != 'admin') {
        debugPrint('PERFIL ADMIN: UID $uid tiene rol "$rol"');

        if (!mounted) return;

        setState(() {
          cargandoPerfil = false;
        });

        _mostrarMensaje(
          'La cuenta actual no tiene permisos de administrador.',
          false,
        );

        return;
      }

      uidAdmin = uid;

      nombreController.text = datos['nombre']?.toString() ?? '';

      usuarioController.text = datos['usuario']?.toString() ?? '';

      correoController.text =
          datos['correo']?.toString() ?? usuarioFirebase.email ?? '';

      await _cargarCantidadRecetas(uid);

      if (!mounted) return;

      setState(() {
        cargandoPerfil = false;
      });
    } catch (e) {
      debugPrint('ERROR CARGANDO PERFIL ADMIN: $e');

      if (!mounted) return;

      setState(() {
        cargandoPerfil = false;
      });

      _mostrarMensaje('No se pudo cargar el perfil.', false);
    }
  }

  Future<void> _cargarCantidadRecetas(String uid) async {
    try {
      final snapshot = await firestore
          .collection('recetas')
          .where('id_admin', isEqualTo: uid)
          .get();

      if (!mounted) return;

      setState(() {
        cantidadRecetas = snapshot.docs.length;
      });
    } catch (e) {
      debugPrint('ERROR CARGANDO CANTIDAD DE RECETAS: $e');

      try {
        final snapshot = await firestore.collection('recetas').get();

        int cantidad = 0;

        for (final documento in snapshot.docs) {
          final datos = documento.data();

          final String idAdmin = datos['id_admin']?.toString() ?? '';

          final String uidAdminReceta = datos['uid_admin']?.toString() ?? '';

          if (idAdmin == uid || uidAdminReceta == uid) {
            cantidad++;
          }
        }

        if (!mounted) return;

        setState(() {
          cantidadRecetas = cantidad;
        });
      } catch (error) {
        debugPrint('ERROR OBTENIENDO RECETAS ADMIN: $error');
      }
    }
  }

  Future<void> _guardarPerfil(
    BuildContext dialogContext,
    StateSetter setModalState,
  ) async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _mostrarMensaje('La sesión ya no está disponible.', false);

      _irAlLogin();
      return;
    }

    final String nombre = nombreController.text.trim();

    final String usuario = usuarioController.text.trim();

    final String correo = correoController.text.trim();

    if (nombre.isEmpty || usuario.isEmpty || correo.isEmpty) {
      _mostrarMensaje('Completa todos los campos.', false);
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
      _mostrarMensaje('Ingresa un correo válido.', false);
      return;
    }

    try {
      final documento = await firestore
          .collection('usuarios')
          .doc(usuarioFirebase.uid)
          .get();

      final datos = documento.data();

      if (datos == null ||
          datos['rol']?.toString().trim().toLowerCase() != 'admin') {
        _mostrarMensaje('La cuenta no tiene permisos de administrador.', false);
        return;
      }

      final String correoFirebase = usuarioFirebase.email ?? '';

      if (correo != correoFirebase) {
        await usuarioFirebase.verifyBeforeUpdateEmail(correo);
      }

      await firestore.collection('usuarios').doc(usuarioFirebase.uid).update({
        'nombre': nombre,
        'usuario': usuario,
        'correo': correo,
      });

      if (!mounted) return;

      Navigator.pop(dialogContext);

      _mostrarMensaje(
        correo != correoFirebase
            ? 'Perfil actualizado. Revisa tu nuevo correo para confirmar el cambio.'
            : 'Perfil actualizado correctamente.',
        true,
      );

      await _cargarPerfil();
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR FIREBASE ACTUALIZANDO PERFIL: ${e.code}');

      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'requires-recent-login':
          mensaje =
              'Por seguridad, vuelve a iniciar sesión antes de cambiar el correo.';
          break;

        case 'email-already-in-use':
          mensaje = 'Ese correo ya está asociado a otra cuenta.';
          break;

        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;

        case 'network-request-failed':
          mensaje = 'No hay conexión con Firebase.';
          break;

        default:
          mensaje = 'No se pudo actualizar el perfil.';
      }

      _mostrarMensaje(mensaje, false);

      setModalState(() {});
    } catch (e) {
      debugPrint('ERROR ACTUALIZANDO PERFIL: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo actualizar el perfil.', false);

      setModalState(() {});
    }
  }

  Future<void> _cambiarContrasena(
    BuildContext dialogContext,
    StateSetter setModalState,
  ) async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _mostrarMensaje('La sesión ya no está disponible.', false);

      _irAlLogin();
      return;
    }

    final String actual = actualPasswordController.text;

    final String nueva = nuevaPasswordController.text;

    final String confirmar = confirmarPasswordController.text;

    if (actual.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      _mostrarMensaje('Completa todos los campos.', false);
      return;
    }

    if (nueva.length < 6) {
      _mostrarMensaje(
        'La nueva contraseña debe tener mínimo 6 caracteres.',
        false,
      );
      return;
    }

    if (nueva != confirmar) {
      _mostrarMensaje('Las contraseñas no coinciden.', false);
      return;
    }

    try {
      final String? correo = usuarioFirebase.email;

      if (correo == null || correo.isEmpty) {
        _mostrarMensaje('La cuenta no tiene un correo asociado.', false);
        return;
      }

      final AuthCredential credencial = EmailAuthProvider.credential(
        email: correo,
        password: actual,
      );

      await usuarioFirebase.reauthenticateWithCredential(credencial);

      await usuarioFirebase.updatePassword(nueva);

      if (!mounted) return;

      Navigator.pop(dialogContext);

      actualPasswordController.clear();
      nuevaPasswordController.clear();
      confirmarPasswordController.clear();

      _mostrarMensaje('Contraseña actualizada correctamente.', true);
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR CAMBIANDO CONTRASEÑA: ${e.code}');

      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          mensaje = 'La contraseña actual es incorrecta.';
          break;

        case 'requires-recent-login':
          mensaje = 'Por seguridad, vuelve a iniciar sesión.';
          break;

        case 'weak-password':
          mensaje = 'La nueva contraseña es demasiado débil.';
          break;

        case 'network-request-failed':
          mensaje = 'No hay conexión con Firebase.';
          break;

        default:
          mensaje = 'No se pudo cambiar la contraseña.';
      }

      _mostrarMensaje(mensaje, false);

      setModalState(() {});
    } catch (e) {
      debugPrint('ERROR CAMBIANDO CONTRASEÑA: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo cambiar la contraseña.', false);

      setModalState(() {});
    }
  }

  void _abrirEditarPerfil() {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _mostrarMensaje('La sesión ya no está disponible.', false);

      _irAlLogin();
      return;
    }

    bool guardando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> guardar() async {
              if (guardando) return;

              setModalState(() {
                guardando = true;
              });

              await _guardarPerfil(dialogContext, setModalState);

              if (mounted && Navigator.canPop(dialogContext)) {
                setModalState(() {
                  guardando = false;
                });
              }
            }

            return _construirDialogoPerfil(
              context: context,
              titulo: 'Editar perfil',
              icono: Icons.person_outline,
              hijos: [
                _construirDescripcionDialogo(
                  'Actualiza la información de tu cuenta.',
                ),
                const SizedBox(height: 20),
                _construirCampoDialogo(
                  controller: nombreController,
                  label: 'Nombre',
                  icono: Icons.person_outline,
                  enabled: !guardando,
                ),
                const SizedBox(height: 14),
                _construirCampoDialogo(
                  controller: usuarioController,
                  label: 'Usuario',
                  icono: Icons.alternate_email,
                  enabled: !guardando,
                ),
                const SizedBox(height: 14),
                _construirCampoDialogo(
                  controller: correoController,
                  label: 'Correo electrónico',
                  icono: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !guardando,
                ),
                const SizedBox(height: 24),
                _construirBotonesDialogo(
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
    );
  }

  void _abrirCambiarContrasena() {
    actualPasswordController.clear();
    nuevaPasswordController.clear();
    confirmarPasswordController.clear();

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
            Future<void> cambiar() async {
              if (guardando) return;

              setModalState(() {
                guardando = true;
              });

              await _cambiarContrasena(dialogContext, setModalState);

              if (mounted && Navigator.canPop(dialogContext)) {
                setModalState(() {
                  guardando = false;
                });
              }
            }

            return _construirDialogoPerfil(
              context: context,
              titulo: 'Cambiar contraseña',
              icono: Icons.lock_outline,
              hijos: [
                _construirDescripcionDialogo(
                  'Protege tu cuenta utilizando una contraseña segura.',
                ),
                const SizedBox(height: 20),
                _construirCampoDialogo(
                  controller: actualPasswordController,
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
                _construirCampoDialogo(
                  controller: nuevaPasswordController,
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
                _construirCampoDialogo(
                  controller: confirmarPasswordController,
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
                _construirBotonesDialogo(
                  context: context,
                  onCancel: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  onConfirm: guardando ? null : cambiar,
                  loading: guardando,
                  textoConfirmar: 'Actualizar contraseña',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _construirDialogoPerfil({
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

  Widget _construirDescripcionDialogo(String texto) {
    return Text(
      texto,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.4,
        color: const Color(0xff777777),
      ),
    );
  }

  Widget _construirCampoDialogo({
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

  Widget _construirBotonesDialogo({
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

  Future<void> _cerrarSesion() async {
    try {
      await auth.signOut();

      // authStateChanges() se encargará de
      // detectar que la sesión terminó y
      // enviar al login.
    } catch (e) {
      debugPrint('ERROR CERRANDO SESIÓN: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo cerrar la sesión.', false);
    }
  }

  void _irAlLogin() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _mostrarMensaje(String mensaje, bool correcto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: correcto ? verdeOscuro : const Color(0xffD32F2F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            Icons.admin_panel_settings_outlined,
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
                usuario.isNotEmpty ? '@$usuario' : '@admin',
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
                onTap: _abrirEditarPerfil,
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
            cargandoPerfil ? '—' : cantidadRecetas.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Mis recetas',
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
      onTap: _cerrarSesion,
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

  @override
  Widget build(BuildContext context) {
    final String nombre = nombreController.text.isNotEmpty
        ? nombreController.text
        : 'Administrador';

    final String usuario = usuarioController.text;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: cargandoPerfil
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
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
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
                                  onTap: _abrirEditarPerfil,
                                ),
                                _buildOption(
                                  icon: Icons.restaurant_menu_outlined,
                                  iconBackground: const Color(0xffEDF9EF),
                                  iconColor: verde,
                                  title: 'Mis recetas',
                                  subtitle: 'Administra las recetas publicadas',
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AdminRecipesScreen(),
                                      ),
                                    );

                                    if (!mounted) return;

                                    final User? usuarioFirebase =
                                        auth.currentUser;

                                    if (usuarioFirebase != null) {
                                      await _cargarCantidadRecetas(
                                        usuarioFirebase.uid,
                                      );
                                    }

                                    if (mounted) {
                                      setState(() {});
                                    }
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
                                  onTap: () {
                                    _mostrarMensaje(
                                      'Las notificaciones estarán disponibles próximamente',
                                      false,
                                    );
                                  },
                                ),
                                _buildOption(
                                  icon: Icons.lock_outline_rounded,
                                  iconBackground: const Color(0xffEFFAF0),
                                  iconColor: verdeOscuro,
                                  title: 'Cambiar contraseña',
                                  subtitle:
                                      'Actualiza la seguridad de tu cuenta',
                                  onTap: _abrirCambiarContrasena,
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

          // Barra de navegación flotante
          const Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdminBottomNavigation(currentIndex: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
