import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_detail_screen.dart';
import '../widgets/bottom_navigation.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> favoritos = [];

  final Set<String> procesandoFavoritos = {};

  bool cargando = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    cargarFavoritos();
  }

  // ============================================================
  // CARGAR FAVORITOS
  // ============================================================

  Future<void> cargarFavoritos() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = '';
    });

    try {
      final User? usuario = _auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          favoritos = [];
          cargando = false;
          error = 'No se encontró la sesión del usuario';
        });

        return;
      }

      /*
       * Los favoritos pertenecen directamente al usuario:
       *
       * usuarios/{uid}/favoritos/{idReceta}
       */
      final favoritosSnapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('favoritos')
          .get();

      final List<Map<String, dynamic>> lista = [];

      /*
       * Cada documento favorito utiliza como ID
       * el ID del documento de la receta.
       */
      for (final favoritoDoc in favoritosSnapshot.docs) {
        final String idReceta = favoritoDoc.id;

        if (idReceta.isEmpty) {
          continue;
        }

        /*
         * Buscamos directamente la receta mediante
         * su document ID de Firestore.
         */
        final recetaSnapshot = await _firestore
            .collection('recetas')
            .doc(idReceta)
            .get();

        if (!recetaSnapshot.exists) {
          continue;
        }

        final data = recetaSnapshot.data();

        if (data == null) {
          continue;
        }

        lista.add({
          ...data,
          'id_receta': recetaSnapshot.id,
          'uid_receta': recetaSnapshot.id,
          'id_favorito': favoritoDoc.id,
        });
      }

      /*
       * Ordenamos por nombre para mantener
       * una presentación estable.
       */
      lista.sort(
        (a, b) => (a['nombre']?.toString() ?? '').toLowerCase().compareTo(
          (b['nombre']?.toString() ?? '').toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() {
        favoritos = lista;
        cargando = false;
      });
    } catch (e) {
      debugPrint('FIRESTORE FAVORITOS ERROR: $e');

      if (!mounted) return;

      setState(() {
        favoritos = [];
        cargando = false;
        error = 'No se pudieron cargar tus favoritos';
      });
    }
  }

  // ============================================================
  // ELIMINAR FAVORITO
  // ============================================================

  Future<void> eliminarFavorito(Map<String, dynamic> receta) async {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        '';

    if (idReceta.isEmpty) {
      return;
    }

    if (procesandoFavoritos.contains(idReceta)) {
      return;
    }

    final User? usuario = _auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró la sesión del usuario',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      procesandoFavoritos.add(idReceta);
    });

    try {
      /*
       * El documento del favorito tiene el mismo ID
       * que la receta.
       */
      final favoritoRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('favoritos')
          .doc(idReceta);

      final favoritoSnapshot = await favoritoRef.get();

      if (!favoritoSnapshot.exists) {
        if (!mounted) return;

        setState(() {
          favoritos.removeWhere(
            (item) =>
                (item['uid_receta']?.toString() ??
                    item['id_receta']?.toString() ??
                    '') ==
                idReceta,
          );
        });

        return;
      }

      await favoritoRef.delete();

      if (!mounted) return;

      setState(() {
        favoritos.removeWhere(
          (item) =>
              (item['uid_receta']?.toString() ??
                  item['id_receta']?.toString() ??
                  '') ==
              idReceta,
        );
      });
    } catch (e) {
      debugPrint('FIRESTORE ELIMINAR FAVORITO ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar el favorito',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        procesandoFavoritos.remove(idReceta);
      });
    }
  }

  // ============================================================
  // DETALLE
  // ============================================================

  void abrirDetalleReceta(Map<String, dynamic> receta) {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        '';

    if (idReceta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo identificar la receta',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(idReceta: idReceta),
      ),
    );
  }

  bool favoritoProcesandose(Map<String, dynamic> receta) {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        '';

    return procesandoFavoritos.contains(idReceta);
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
                _buildHeader(),
                _buildTitle(),
                Expanded(child: _buildContenido()),
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
                child: BottomNavigation(currentIndex: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

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

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Mis favoritos',
              style: GoogleFonts.poppins(
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: Colors.black,
              ),
            ),
          ),
          if (!cargando && favoritos.isNotEmpty)
            Text(
              '${favoritos.length} ${favoritos.length == 1 ? 'receta' : 'recetas'}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: verdeOscuro,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENIDO
  // ============================================================

  Widget _buildContenido() {
    if (cargando) {
      return _buildLoading();
    }

    if (error.isNotEmpty) {
      return _buildError();
    }

    if (favoritos.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarFavoritos,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 20,
          childAspectRatio: 0.70,
        ),
        itemCount: favoritos.length,
        itemBuilder: (context, index) {
          final receta = favoritos[index];

          return _buildRecipeCard(receta);
        },
      ),
    );
  }

  // ============================================================
  // RECIPE CARD
  // ============================================================

  Widget _buildRecipeCard(Map<String, dynamic> receta) {
    final String title = receta['nombre']?.toString() ?? 'Sin nombre';

    final String imagen = receta['imagen']?.toString() ?? '';

    final bool procesando = favoritoProcesandose(receta);

    return GestureDetector(
      onTap: () {
        abrirDetalleReceta(receta);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f1f1),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImage(imageUrl: imagen),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: GestureDetector(
                    onTap: procesando
                        ? null
                        : () {
                            eliminarFavorito(receta);
                          },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                      ),
                      child: procesando
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: verde,
                              ),
                            )
                          : const Icon(
                              Icons.favorite_rounded,
                              color: verde,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.restaurant_outlined,
                size: 13,
                color: Color(0xff888888),
              ),
              const SizedBox(width: 4),
              Text(
                'Receta regional',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: const Color(0xff888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage({required String imageUrl}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xfff1f1f1),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xffaaaaaa),
          size: 38,
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xfff1f1f1),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_outlined,
            color: Color(0xffaaaaaa),
            size: 38,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xfff1f1f1),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: verde),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 20,
        childAspectRatio: 0.70,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _skeletonBox(double.infinity, double.infinity, radius: 17),
            ),
            const SizedBox(height: 9),
            _skeletonBox(125, 14),
            const SizedBox(height: 5),
            _skeletonBox(90, 11),
          ],
        );
      },
    );
  }

  Widget _skeletonBox(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xffeeeeee),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xfff4f4f4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 32,
                color: Color(0xff777777),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No pudimos cargar tus favoritos',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.4,
                color: const Color(0xff777777),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargarFavoritos,
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Reintentar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarFavoritos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),
          Container(
            width: 75,
            height: 75,
            margin: const EdgeInsets.symmetric(horizontal: 150),
            decoration: const BoxDecoration(
              color: Color(0xfff4f4f4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 36,
              color: Color(0xff999999),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No tienes recetas favoritas',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45),
            child: Text(
              'Guarda las recetas que más te gusten para encontrarlas aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xff777777),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
