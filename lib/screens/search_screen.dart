import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_detail_screen.dart';
import '../widgets/bottom_navigation.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> recipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];

  final Set<String> favoritos = {};
  final Set<String> procesandoFavoritos = {};

  bool cargando = true;
  String error = '';

  static const Color verde = Color(0xff16D928);

  @override
  void initState() {
    super.initState();

    searchController.addListener(filtrarRecetas);

    cargarDatos();
  }

  Future<void> cargarDatos() async {
    await Future.wait([cargarRecetas(), cargarFavoritos()]);
  }

  // ============================================================
  // RECETAS - FIREBASE
  // ============================================================

  Future<void> cargarRecetas() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = '';
    });

    try {
      final snapshot = await _firestore.collection('recetas').get();

      final lista = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());

        final String idReceta = doc.id;

        data['id_receta'] = idReceta;
        data['uid_receta'] = idReceta;
        data['_documentId'] = idReceta;

        return data;
      }).toList();

      if (!mounted) return;

      setState(() {
        recipes = lista;
        filteredRecipes = lista;
        cargando = false;
      });
    } catch (e) {
      print('ERROR CARGANDO RECETAS FIREBASE: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las recetas';
        cargando = false;
      });
    }
  }

  // ============================================================
  // FAVORITOS - FIREBASE
  // ============================================================

  Future<void> cargarFavoritos() async {
    try {
      final usuario = _auth.currentUser;

      if (usuario == null) {
        return;
      }

      final snapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('favoritos')
          .get();

      final Set<String> favoritosFirestore = {};

      for (final doc in snapshot.docs) {
        favoritosFirestore.add(doc.id);
      }

      if (!mounted) return;

      setState(() {
        favoritos
          ..clear()
          ..addAll(favoritosFirestore);
      });
    } catch (e) {
      print('ERROR CARGANDO FAVORITOS FIREBASE: $e');
    }
  }

  // ============================================================
  // BUSCADOR
  // ============================================================

  void filtrarRecetas() {
    final query = searchController.text.toLowerCase().trim();

    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        filteredRecipes = recipes;
      } else {
        filteredRecipes = recipes.where((recipe) {
          final nombre = recipe['nombre']?.toString().toLowerCase() ?? '';

          final descripcion =
              recipe['descripcion']?.toString().toLowerCase() ?? '';

          final ingredientes =
              recipe['ingredientes']?.toString().toLowerCase() ?? '';

          return nombre.contains(query) ||
              descripcion.contains(query) ||
              ingredientes.contains(query);
        }).toList();
      }
    });
  }

  // ============================================================
  // CAMBIAR FAVORITO
  // ============================================================

  Future<void> cambiarFavorito(Map<String, dynamic> receta) async {
    final String idReceta = receta['_documentId']?.toString() ?? '';

    if (idReceta.isEmpty) {
      return;
    }

    if (procesandoFavoritos.contains(idReceta)) {
      return;
    }

    final usuario = _auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró la sesión del usuario')),
      );

      return;
    }

    final bool favoritoAnterior = favoritos.contains(idReceta);

    setState(() {
      procesandoFavoritos.add(idReceta);

      if (favoritoAnterior) {
        favoritos.remove(idReceta);
      } else {
        favoritos.add(idReceta);
      }
    });

    try {
      final favoritoRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('favoritos')
          .doc(idReceta);

      if (favoritoAnterior) {
        await favoritoRef.delete();
      } else {
        await favoritoRef.set({
          'uid_receta': idReceta,
          'fecha_agregado': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('ERROR ACTUALIZANDO FAVORITO: $e');

      if (mounted) {
        setState(() {
          if (favoritoAnterior) {
            favoritos.add(idReceta);
          } else {
            favoritos.remove(idReceta);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el favorito')),
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        procesandoFavoritos.remove(idReceta);
      });
    }
  }

  bool esFavorito(Map<String, dynamic> receta) {
    final String idReceta = receta['_documentId']?.toString() ?? '';

    return favoritos.contains(idReceta);
  }

  bool favoritoProcesandose(Map<String, dynamic> receta) {
    final String idReceta = receta['_documentId']?.toString() ?? '';

    return procesandoFavoritos.contains(idReceta);
  }

  // ============================================================
  // DETALLE
  // ============================================================

  void abrirDetalleReceta(Map<String, dynamic> recipe) {
    final String idReceta = recipe['_documentId']?.toString() ?? '';

    if (idReceta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar la receta')),
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

  @override
  void dispose() {
    searchController.removeListener(filtrarRecetas);
    searchController.dispose();
    super.dispose();
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
                _buildSearchBar(),
                const SizedBox(height: 18),
                Expanded(child: _buildResultados()),
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
                child: BottomNavigation(currentIndex: 2),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buscar recetas',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Encuentra sabores de nuestra región.',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xff777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(17),
        ),
        child: TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar una receta...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xff888888),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.black,
              size: 23,
            ),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      searchController.clear();
                    },
                    splashRadius: 20,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xff777777),
                      size: 19,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULTADOS
  // ============================================================

  Widget _buildResultados() {
    if (cargando) {
      return _buildLoading();
    }

    if (error.isNotEmpty) {
      return _buildError();
    }

    if (filteredRecipes.isEmpty) {
      return _buildEmptySearch();
    }

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 20,
          childAspectRatio: 0.70,
        ),
        itemCount: filteredRecipes.length,
        itemBuilder: (context, index) {
          final recipe = filteredRecipes[index];

          return _buildRecipeItem(recipe);
        },
      ),
    );
  }

  // ============================================================
  // RECIPE CARD
  // ============================================================

  Widget _buildRecipeItem(Map<String, dynamic> recipe) {
    final String title = recipe['nombre']?.toString() ?? 'Sin nombre';

    final String imageUrl = recipe['imagen']?.toString() ?? '';

    final bool favorito = esFavorito(recipe);

    final bool procesando = favoritoProcesandose(recipe);

    return GestureDetector(
      onTap: () {
        abrirDetalleReceta(recipe);
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
                  child: _buildImage(imageUrl: imageUrl),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: GestureDetector(
                    onTap: procesando
                        ? null
                        : () {
                            cambiarFavorito(recipe);
                          },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
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
                          : Icon(
                              favorito
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: favorito ? verde : Colors.black,
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
              'No pudimos cargar las recetas',
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
              onPressed: cargarDatos,
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
  // EMPTY SEARCH
  // ============================================================

  Widget _buildEmptySearch() {
    final bool estaBuscando = searchController.text.trim().isNotEmpty;

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          Container(
            width: 78,
            height: 78,
            margin: const EdgeInsets.symmetric(horizontal: 150),
            decoration: const BoxDecoration(
              color: Color(0xfff4f4f4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              estaBuscando
                  ? Icons.search_off_rounded
                  : Icons.restaurant_menu_outlined,
              size: 36,
              color: const Color(0xff999999),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              estaBuscando
                  ? 'No encontramos recetas'
                  : 'Todavía no hay recetas',
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
              estaBuscando
                  ? 'Prueba con otro nombre o ingrediente.'
                  : 'Pronto encontrarás nuevos sabores para descubrir.',
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
