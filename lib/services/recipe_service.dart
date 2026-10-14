import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _recetas =>
      _db.collection('recetas');

  static Future<List<Map<String, dynamic>>> obtenerRecetas() async {
    final snapshot = await _recetas.get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id_receta': int.tryParse(
              data['id_receta']?.toString() ?? doc.id,
            ) ??
            0,
        'nombre': data['nombre']?.toString() ?? '',
        'imagen': data['imagen']?.toString() ?? '',
        'descripcion': data['descripcion']?.toString() ?? '',
        'ingredientes': data['ingredientes']?.toString() ?? '',
        'pasos': data['pasos']?.toString() ?? '',
        'id_admin': int.tryParse(
              data['id_admin']?.toString() ?? '',
            ) ??
            0,
        'fecha_publicacion': data['fecha_publicacion'],
      };
    }).toList();

    lista.sort((a, b) {
      final fechaA = a['fecha_publicacion'];
      final fechaB = b['fecha_publicacion'];

      if (fechaA is Timestamp && fechaB is Timestamp) {
        return fechaB.compareTo(fechaA);
      }

      return 0;
    });

    return lista;
  }

  static Future<Map<String, dynamic>?> obtenerReceta(
    int idReceta,
  ) async {
    final snapshot = await _recetas
        .where('id_receta', isEqualTo: idReceta)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final data = snapshot.docs.first.data();

    return {
      'id_receta': int.tryParse(
            data['id_receta']?.toString() ?? '',
          ) ??
          idReceta,
      'nombre': data['nombre']?.toString() ?? '',
      'imagen': data['imagen']?.toString() ?? '',
      'descripcion': data['descripcion']?.toString() ?? '',
      'ingredientes': data['ingredientes']?.toString() ?? '',
      'pasos': data['pasos']?.toString() ?? '',
      'id_admin': int.tryParse(
            data['id_admin']?.toString() ?? '',
          ) ??
          0,
      'fecha_publicacion': data['fecha_publicacion'],
    };
  }

  static Future<void> crearReceta({
    required int idReceta,
    required String nombre,
    required String imagen,
    required String descripcion,
    required String ingredientes,
    required String pasos,
    required int idAdmin,
  }) async {
    await _recetas.doc(idReceta.toString()).set({
      'id_receta': idReceta,
      'nombre': nombre,
      'imagen': imagen,
      'descripcion': descripcion,
      'ingredientes': ingredientes,
      'pasos': pasos,
      'id_admin': idAdmin,
      'fecha_publicacion': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> editarReceta({
    required int idReceta,
    required String nombre,
    required String imagen,
    required String descripcion,
    required String ingredientes,
    required String pasos,
    required int idAdmin,
  }) async {
    await _recetas.doc(idReceta.toString()).update({
      'nombre': nombre,
      'imagen': imagen,
      'descripcion': descripcion,
      'ingredientes': ingredientes,
      'pasos': pasos,
      'id_admin': idAdmin,
    });
  }

  static Future<void> eliminarReceta(int idReceta) async {
    await _recetas.doc(idReceta.toString()).delete();
  }
}