import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.102/armadillo';

  static const String serverClientId =
      '1022530717821-ac98soig9p5rkq9pdtiprul66hnd1ucr.apps.googleusercontent.com';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static bool _googleInicializado = false;

  static Map<String, dynamic>? usuarioActual;

  static String? get idUsuario => usuarioActual?['id_usuario']?.toString();

  static String? get nombreUsuario => usuarioActual?['nombre']?.toString();

  static String? get usuario => usuarioActual?['usuario']?.toString();

  static String? get correoUsuario => usuarioActual?['correo']?.toString();

  static String? get rolUsuario => usuarioActual?['rol']?.toString();

  // ============================================================
  // INICIALIZAR GOOGLE
  // ============================================================

  static Future<void> inicializarGoogle() async {
    if (_googleInicializado) return;

    try {
      debugPrint('====================================');
      debugPrint('GOOGLE: inicializando');
      debugPrint('====================================');

      await _googleSignIn.initialize(serverClientId: serverClientId);

      _googleInicializado = true;

      debugPrint('GOOGLE: inicialización correcta');
    } catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('ERROR AL INICIALIZAR GOOGLE');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('====================================');

      rethrow;
    }
  }

  // ============================================================
  // GOOGLE LOGIN - FIREBASE AUTH + FIRESTORE
  // ============================================================

  static Future<Map<String, dynamic>> loginGoogle() async {
    try {
      await inicializarGoogle();

      debugPrint('====================================');
      debugPrint('INICIANDO LOGIN CON GOOGLE');
      debugPrint('====================================');

      debugPrint('GOOGLE: iniciando authenticate()');

      final GoogleSignInAccount cuenta = await _googleSignIn.authenticate();

      debugPrint('GOOGLE: cuenta obtenida');
      debugPrint('GOOGLE: email = ${cuenta.email}');
      debugPrint('GOOGLE: nombre = ${cuenta.displayName}');

      final GoogleSignInAuthentication autenticacion = cuenta.authentication;

      final String? idToken = autenticacion.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('GOOGLE: ID TOKEN NULL O VACÍO');

        return {
          'success': false,
          'message':
              'Google no proporcionó un ID Token. Revisa la configuración de Firebase.',
        };
      }

      debugPrint('GOOGLE: ID Token obtenido');

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      debugPrint('FIREBASE: iniciando signInWithCredential()');

      final UserCredential resultado = await _auth.signInWithCredential(
        credential,
      );

      final User? user = resultado.user;

      if (user == null) {
        debugPrint('FIREBASE: usuario NULL');

        return {
          'success': false,
          'message':
              'Firebase no devolvió un usuario después del inicio de sesión.',
        };
      }

      debugPrint('FIREBASE: autenticación correcta');
      debugPrint('FIREBASE UID: ${user.uid}');
      debugPrint('FIREBASE EMAIL: ${user.email}');
      debugPrint('FIREBASE NOMBRE: ${user.displayName}');

      final DocumentReference usuarioRef = _firestore
          .collection('usuarios')
          .doc(user.uid);

      debugPrint('FIRESTORE: buscando usuarios/${user.uid}');

      final DocumentSnapshot usuarioDoc = await usuarioRef.get();

      if (!usuarioDoc.exists) {
        debugPrint('FIRESTORE: usuario no existe, creando documento');

        final String correo = user.email ?? cuenta.email;

        final String nombre =
            user.displayName ?? cuenta.displayName ?? 'Usuario';

        String usuario = correo
            .split('@')
            .first
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9._-]'), '');

        if (usuario.isEmpty) {
          usuario = 'usuario';
        }

        await usuarioRef.set({
          'nombre': nombre,
          'usuario': usuario,
          'correo': correo,
          'rol': 'usuario',
          'verificado': true,
          'foto': user.photoURL ?? cuenta.photoUrl ?? '',
          'fecha_registro': FieldValue.serverTimestamp(),
        });

        debugPrint('FIRESTORE: usuario creado correctamente');

        usuarioActual = {
          'id_usuario': user.uid,
          'nombre': nombre,
          'usuario': usuario,
          'correo': correo,
          'rol': 'usuario',
          'verificado': true,
          'foto': user.photoURL ?? cuenta.photoUrl ?? '',
        };
      } else {
        debugPrint('FIRESTORE: usuario encontrado');

        final Map<String, dynamic> datos =
            usuarioDoc.data() as Map<String, dynamic>;

        usuarioActual = {'id_usuario': user.uid, ...datos};

        debugPrint('FIRESTORE: rol = ${usuarioActual?['rol']}');
      }

      await _guardarSesion();

      debugPrint('====================================');
      debugPrint('GOOGLE LOGIN COMPLETADO');
      debugPrint('UID: ${user.uid}');
      debugPrint('CORREO: ${user.email}');
      debugPrint('ROL: ${usuarioActual?['rol']}');
      debugPrint('====================================');

      return {
        'success': true,
        'message': 'Inicio de sesión correcto.',
        'usuario': usuarioActual,
      };
    } on GoogleSignInException catch (e) {
      debugPrint('====================================');
      debugPrint('ERROR GOOGLE SIGN IN');
      debugPrint('CODE: ${e.code}');
      debugPrint('CODE NAME: ${e.code.name}');
      debugPrint('DESCRIPTION: ${e.description}');
      debugPrint('DETAILS: ${e.details}');
      debugPrint('====================================');

      String mensaje;

      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          mensaje = 'Inicio de sesión cancelado.';

        case GoogleSignInExceptionCode.interrupted:
          mensaje = 'El inicio de sesión de Google fue interrumpido.';

        case GoogleSignInExceptionCode.clientConfigurationError:
          mensaje =
              'Error de configuración de Google Sign-In. Revisa el SHA-1/SHA-256, el paquete Android y el Client ID.';

        case GoogleSignInExceptionCode.providerConfigurationError:
          mensaje = 'Google Play Services no está configurado correctamente.';

        case GoogleSignInExceptionCode.uiUnavailable:
          mensaje =
              'No se pudo abrir la ventana de inicio de sesión de Google.';

        case GoogleSignInExceptionCode.userMismatch:
          mensaje =
              'La cuenta de Google actual no coincide con la cuenta esperada.';

        case GoogleSignInExceptionCode.unknownError:
          mensaje =
              'Google devolvió un error desconocido: ${e.description ?? 'sin descripción'}';
      }

      return {'success': false, 'message': mensaje};
    } on FirebaseAuthException catch (e) {
      debugPrint('====================================');
      debugPrint('ERROR FIREBASE AUTH');
      debugPrint('CODE: ${e.code}');
      debugPrint('MESSAGE: ${e.message}');
      debugPrint('====================================');

      return {
        'success': false,
        'message': e.message ?? 'Firebase rechazó el inicio de sesión.',
      };
    } on FirebaseException catch (e) {
      debugPrint('====================================');
      debugPrint('ERROR FIREBASE');
      debugPrint('PLUGIN: ${e.plugin}');
      debugPrint('CODE: ${e.code}');
      debugPrint('MESSAGE: ${e.message}');
      debugPrint('DETAILS: ${e.message}');
      debugPrint('====================================');

      return {'success': false, 'message': 'Firebase: ${e.code}'};
    } catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('ERROR GOOGLE GENERAL');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('====================================');

      return {
        'success': false,
        'message': 'Error inesperado al iniciar sesión con Google.',
      };
    }
  }

  // ============================================================
  // LOGIN NORMAL - FIREBASE AUTH + FIRESTORE
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String correo,
    String contrasena,
  ) async {
    try {
      debugPrint('====================================');
      debugPrint('INICIANDO LOGIN NORMAL');
      debugPrint('CORREO: ${correo.trim()}');
      debugPrint('====================================');

      final UserCredential resultado = await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );

      final User? user = resultado.user;

      if (user == null) {
        return {'success': false, 'message': 'No se pudo iniciar sesión.'};
      }

      debugPrint('FIREBASE UID: ${user.uid}');

      final DocumentSnapshot usuarioDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!usuarioDoc.exists) {
        return {
          'success': false,
          'message': 'El usuario no tiene un perfil registrado en Firestore.',
        };
      }

      final Map<String, dynamic> datos =
          usuarioDoc.data() as Map<String, dynamic>;

      usuarioActual = {'id_usuario': user.uid, ...datos};

      await _guardarSesion();

      debugPrint('LOGIN CORRECTO - ROL: ${usuarioActual?['rol']}');

      return {
        'success': true,
        'message': 'Inicio de sesión correcto.',
        'usuario': usuarioActual,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR LOGIN FIREBASE: ${e.code}');

      String mensaje = 'No se pudo iniciar sesión.';

      if (e.code == 'invalid-credential') {
        mensaje = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'user-not-found') {
        mensaje = 'No existe una cuenta con ese correo.';
      } else if (e.code == 'wrong-password') {
        mensaje = 'La contraseña es incorrecta.';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo electrónico no es válido.';
      } else if (e.code == 'too-many-requests') {
        mensaje = 'Demasiados intentos. Intenta nuevamente más tarde.';
      }

      return {'success': false, 'message': mensaje};
    } on FirebaseException catch (e) {
      debugPrint('ERROR FIRESTORE: ${e.code}');
      debugPrint('MENSAJE: ${e.message}');

      return {'success': false, 'message': 'Error de Firebase: ${e.code}'};
    } catch (e) {
      return {'success': false, 'message': 'Error al iniciar sesión.'};
    }
  }

  // ============================================================
  // REGISTRO - FIREBASE AUTH + FIRESTORE
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String nombre,
    required String usuario,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final UserCredential resultado = await _auth
          .createUserWithEmailAndPassword(
            email: correo.trim(),
            password: contrasena,
          );

      final User? user = resultado.user;

      if (user == null) {
        return {'success': false, 'message': 'No se pudo crear la cuenta.'};
      }

      await user.updateDisplayName(nombre.trim());

      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre.trim(),
        'usuario': usuario.trim(),
        'correo': correo.trim(),
        'rol': 'usuario',
        'verificado': false,
        'foto': '',
        'fecha_registro': FieldValue.serverTimestamp(),
      });

      usuarioActual = {
        'id_usuario': user.uid,
        'nombre': nombre.trim(),
        'usuario': usuario.trim(),
        'correo': correo.trim(),
        'rol': 'usuario',
        'verificado': false,
        'foto': '',
      };

      await _guardarSesion();

      return {
        'success': true,
        'message': 'Cuenta creada correctamente.',
        'usuario': usuarioActual,
      };
    } on FirebaseAuthException catch (e) {
      String mensaje = 'No se pudo crear la cuenta.';

      if (e.code == 'email-already-in-use') {
        mensaje = 'Ya existe una cuenta con ese correo.';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña es demasiado débil.';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo electrónico no es válido.';
      }

      return {'success': false, 'message': mensaje};
    } on FirebaseException catch (e) {
      return {'success': false, 'message': 'Error de Firebase: ${e.code}'};
    } catch (e) {
      return {'success': false, 'message': 'Error al registrar usuario.'};
    }
  }

  // ============================================================
  // CARGAR SESIÓN
  // ============================================================
  static Future<void> cargarSesion() async {
    try {
      final User? firebaseUser = _auth.currentUser;

      if (firebaseUser == null) {
        usuarioActual = null;

        final SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.remove('id_usuario');
        await prefs.remove('nombre');
        await prefs.remove('usuario');
        await prefs.remove('correo');
        await prefs.remove('rol');

        return;
      }

      final DocumentSnapshot usuarioDoc = await _firestore
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .get();

      if (!usuarioDoc.exists) {
        usuarioActual = null;
        return;
      }

      final Map<String, dynamic> datos =
          usuarioDoc.data() as Map<String, dynamic>;

      usuarioActual = {'id_usuario': firebaseUser.uid, ...datos};

      await _guardarSesion();

      debugPrint('SESIÓN FIREBASE CARGADA');
      debugPrint('UID: ${firebaseUser.uid}');
      debugPrint('ROL: ${usuarioActual?['rol']}');
    } catch (e) {
      debugPrint('ERROR AL CARGAR SESIÓN: $e');
      usuarioActual = null;
    }
  }

  // ============================================================
  // GUARDAR SESIÓN
  // ============================================================

  static Future<void> _guardarSesion() async {
    if (usuarioActual == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'id_usuario',
      usuarioActual!['id_usuario']?.toString() ?? '',
    );

    await prefs.setString('nombre', usuarioActual!['nombre']?.toString() ?? '');

    await prefs.setString(
      'usuario',
      usuarioActual!['usuario']?.toString() ?? '',
    );

    await prefs.setString('correo', usuarioActual!['correo']?.toString() ?? '');

    await prefs.setString(
      'rol',
      usuarioActual!['rol']?.toString() ?? 'usuario',
    );
  }

  // ============================================================
  // PERFIL
  // ============================================================

  static Future<Map<String, dynamic>?> obtenerPerfil() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) return null;

      final DocumentSnapshot doc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final Map<String, dynamic> datos = doc.data() as Map<String, dynamic>;

      usuarioActual = {'id_usuario': user.uid, ...datos};

      await _guardarSesion();

      return usuarioActual;
    } catch (e) {
      debugPrint('ERROR OBTENER PERFIL: $e');

      return null;
    }
  }

  static Future<Map<String, dynamic>> editarPerfil({
    required String nombre,
    required String usuario,
  }) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'No hay una sesión activa.'};
      }

      await _firestore.collection('usuarios').doc(user.uid).update({
        'nombre': nombre.trim(),
        'usuario': usuario.trim(),
      });

      await user.updateDisplayName(nombre.trim());

      usuarioActual ??= {};

      usuarioActual!['id_usuario'] = user.uid;

      usuarioActual!['nombre'] = nombre.trim();

      usuarioActual!['usuario'] = usuario.trim();

      await _guardarSesion();

      return {'success': true, 'message': 'Perfil actualizado correctamente.'};
    } on FirebaseException catch (e) {
      debugPrint('ERROR EDITAR PERFIL: ${e.code}');

      return {'success': false, 'message': 'No se pudo actualizar el perfil.'};
    } catch (e) {
      return {'success': false, 'message': 'No se pudo actualizar el perfil.'};
    }
  }

  // ============================================================
  // CAMBIAR CONTRASEÑA
  // ============================================================

  static Future<Map<String, dynamic>> cambiarContrasena({
    required String nuevaContrasena,
  }) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'No hay una sesión activa.'};
      }

      await user.updatePassword(nuevaContrasena);

      return {
        'success': true,
        'message': 'Contraseña actualizada correctamente.',
      };
    } on FirebaseAuthException catch (e) {
      String mensaje = e.message ?? 'No se pudo cambiar la contraseña.';

      if (e.code == 'requires-recent-login') {
        mensaje =
            'Por seguridad, vuelve a iniciar sesión antes de cambiar la contraseña.';
      }

      return {'success': false, 'message': mensaje};
    } catch (e) {
      return {'success': false, 'message': 'No se pudo cambiar la contraseña.'};
    }
  }

  // ============================================================
  // FAVORITOS
  // ============================================================

  static Future<List<int>> obtenerFavoritos() async {
    try {
      final String? id = idUsuario;

      if (id == null || id.isEmpty) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/favoritos/listar.php?id_usuario=$id'),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      if (data is Map && data['success'] == true && data['favoritos'] is List) {
        return (data['favoritos'] as List)
            .map((e) => int.tryParse(e['id_receta'].toString()) ?? 0)
            .where((id) => id > 0)
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('ERROR OBTENER FAVORITOS: $e');

      return [];
    }
  }

  static Future<int> obtenerCantidadFavoritos() async {
    try {
      final favoritos = await obtenerFavoritos();

      return favoritos.length;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  static Future<void> cerrarSesion() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _auth.signOut();
    } catch (_) {}

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove('id_usuario');
    await prefs.remove('nombre');
    await prefs.remove('usuario');
    await prefs.remove('correo');
    await prefs.remove('rol');

    usuarioActual = null;
  }
}
