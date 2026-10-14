import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> probarConexion() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        print('====================================');
        print('FIRESTORE: sin sesión activa');
        print('No se realiza prueba de conexión.');
        print('====================================');
        return;
      }

      final snapshot = await _db.collection('recetas').limit(1).get();

      print('====================================');
      print('FIRESTORE CONECTADO');
      print('UID AUTENTICADO: ${user.uid}');
      print('Documentos encontrados: ${snapshot.docs.length}');

      for (final doc in snapshot.docs) {
        print('ID: ${doc.id}');
        print('DATOS: ${doc.data()}');
      }

      print('====================================');
    } catch (e) {
      print('====================================');
      print('ERROR FIRESTORE');
      print(e);
      print('====================================');
    }
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioPorUid(String uid) async {
    try {
      final documento = await _db.collection('usuarios').doc(uid).get();

      if (!documento.exists) {
        print('USUARIO NO ENCONTRADO EN FIRESTORE');
        print('UID: $uid');
        return null;
      }

      final datos = documento.data();

      if (datos == null) {
        return null;
      }

      return {...datos, 'uid': uid};
    } catch (e) {
      print('ERROR OBTENIENDO USUARIO: $e');
      return null;
    }
  }

  static Future<void> crearUsuario({
    required String uid,
    required String idUsuario,
    required String nombre,
    required String usuario,
    required String correo,
    String rol = 'usuario',
    bool verificado = true,
  }) async {
    await _db.collection('usuarios').doc(uid).set({
      'id_usuario': idUsuario,
      'nombre': nombre,
      'usuario': usuario,
      'correo': correo,
      'rol': rol,
      'verificado': verificado,
      'fecha_registro': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> actualizarUsuario({
    required String uid,
    required String nombre,
    required String usuario,
    required String correo,
  }) async {
    await _db.collection('usuarios').doc(uid).update({
      'nombre': nombre,
      'usuario': usuario,
      'correo': correo,
    });
  }
}
