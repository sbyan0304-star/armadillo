import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/admin_bottom_navigation.dart';
import 'admin_create_recipe_screen.dart';

class AdminRecipesScreen extends StatefulWidget {
  const AdminRecipesScreen({super.key});

  @override
  State<AdminRecipesScreen> createState() => _AdminRecipesScreenState();
}

class _AdminRecipesScreenState extends State<AdminRecipesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color verde = Color(0xFF16D928);
  static const Color verdeOscuro = Color(0xFF16A923);

  bool _cargando = true;
  bool _esAdmin = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _recetas = [];

  @override
  void initState() {
    super.initState();
    _cargarRecetas();
  }

  // ============================================================
  // CARGAR RECETAS DEL ADMINISTRADOR
  // ============================================================

  Future<void> _cargarRecetas() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
    });

    try {
      final User? usuario = _auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          _esAdmin = false;
          _recetas = [];
          _cargando = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // VERIFICAR PERFIL
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> perfil = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (!perfil.exists) {
        throw Exception('No existe el perfil del administrador.');
      }

      final Map<String, dynamic>? datosPerfil = perfil.data();

      final String rol =
          datosPerfil?['rol']?.toString().toLowerCase().trim() ?? '';

      if (rol != 'admin') {
        if (!mounted) return;

        setState(() {
          _esAdmin = false;
          _recetas = [];
          _cargando = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // CARGAR RECETAS DEL ADMIN
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('recetas')
          .where('uid_admin', isEqualTo: usuario.uid)
          .get();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> recetas =
          List.from(snapshot.docs);

      // ----------------------------------------------------------
      // ORDENAR POR FECHA
      // ----------------------------------------------------------

      recetas.sort((a, b) {
        final dynamic fechaA = a.data()['fecha_publicacion'];
        final dynamic fechaB = b.data()['fecha_publicacion'];

        if (fechaA is Timestamp && fechaB is Timestamp) {
          return fechaB.compareTo(fechaA);
        }

        if (fechaA is Timestamp) {
          return -1;
        }

        if (fechaB is Timestamp) {
          return 1;
        }

        return 0;
      });

      if (!mounted) return;

      setState(() {
        _esAdmin = true;
        _recetas = recetas;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR CARGANDO MIS RECETAS: $e');

      if (!mounted) return;

      setState(() {
        _recetas = [];
        _cargando = false;
      });

      _mostrarMensaje('No se pudieron cargar tus recetas.', error: true);
    }
  }

  // ============================================================
  // CREAR RECETA
  // ============================================================

  Future<void> _crearReceta() async {
    final bool? resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateRecipeScreen()),
    );

    if (resultado == true) {
      await _cargarRecetas();
    }
  }

  // ============================================================
  // EDITAR RECETA
  // ============================================================

  Future<void> _editarReceta(
    QueryDocumentSnapshot<Map<String, dynamic>> receta,
  ) async {
    final Map<String, dynamic> datos = {...receta.data(), '_docId': receta.id};

    final bool? resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminCreateRecipeScreen(receta: datos)),
    );

    if (resultado == true) {
      await _cargarRecetas();
    }
  }

  // ============================================================
  // ELIMINAR RECETA
  // ============================================================

  Future<void> _eliminarReceta(
    QueryDocumentSnapshot<Map<String, dynamic>> receta,
  ) async {
    final String nombre = receta.data()['nombre']?.toString() ?? 'esta receta';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Eliminar receta',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "$nombre"?',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Eliminar',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await _firestore.collection('recetas').doc(receta.id).delete();

      if (!mounted) return;

      _mostrarMensaje('Receta eliminada correctamente.');

      await _cargarRecetas();
    } on FirebaseException catch (e) {
      debugPrint(
        'ERROR FIREBASE ELIMINANDO RECETA: '
        '${e.code} - ${e.message}',
      );

      if (!mounted) return;

      _mostrarMensaje(
        e.code == 'permission-denied'
            ? 'Firebase no permite eliminar esta receta.'
            : 'No se pudo eliminar la receta.',
        error: true,
      );
    } catch (e) {
      debugPrint('ERROR ELIMINANDO RECETA: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo eliminar la receta.', error: true);
    }
  }

  // ============================================================
  // TARJETA DE RECETA
  // ============================================================

  Widget _tarjetaReceta(QueryDocumentSnapshot<Map<String, dynamic>> receta) {
    final Map<String, dynamic> data = receta.data();

    final String nombre = data['nombre']?.toString().trim() ?? 'Sin nombre';

    final String descripcion = data['descripcion']?.toString().trim() ?? '';

    final String imagen = data['imagen']?.toString().trim() ?? '';

    final int idReceta = int.tryParse(data['id_receta']?.toString() ?? '') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // IMAGEN
          // ------------------------------------------------------
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 1,
              child: imagen.isNotEmpty
                  ? Image.network(
                      imagen,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: verde,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                          'ERROR IMAGEN RECETA '
                          '$idReceta: $error',
                        );

                        return _imagenError();
                      },
                    )
                  : _imagenError(),
            ),
          ),

          // ------------------------------------------------------
          // INFORMACIÓN
          // ------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _editarReceta(receta);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(
                          'Editar',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton(
                      onPressed: () {
                        _eliminarReceta(receta);
                      },
                      tooltip: 'Eliminar',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLACEHOLDER DE IMAGEN
  // ============================================================

  Widget _imagenError() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 42,
          color: Colors.black26,
        ),
      ),
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: error ? Colors.red : verdeOscuro,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ------------------------------------------------
                // HEADER
                // ------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mis recetas',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _esAdmin ? _crearReceta : null,
                        tooltip: 'Nueva receta',
                        icon: Icon(
                          Icons.add_rounded,
                          size: 28,
                          color: _esAdmin ? verdeOscuro : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------------------------------------
                // CONTENIDO
                // ------------------------------------------------
                Expanded(
                  child: RefreshIndicator(
                    color: verdeOscuro,
                    onRefresh: _cargarRecetas,
                    child: _cargando
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ],
                          )
                        : !_esAdmin
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 130),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.65,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 52,
                                          color: Colors.black26,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Acceso no disponible',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          'Esta sección requiere una sesión de administrador.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _recetas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 130),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.65,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.restaurant_menu_outlined,
                                          size: 54,
                                          color: Colors.black26,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Aún no tienes recetas',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          'Publica tu primera receta para comenzar.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: _crearReceta,
                                          icon: const Icon(Icons.add_rounded),
                                          label: Text(
                                            'Nueva receta',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: verde,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                            itemCount: _recetas.length,
                            itemBuilder: (context, index) {
                              return _tarjetaReceta(_recetas[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // NAVEGACIÓN FLOTANTE
          // ------------------------------------------------------
          const Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdminBottomNavigation(currentIndex: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
