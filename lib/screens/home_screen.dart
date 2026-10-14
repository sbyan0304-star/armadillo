import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_detail_screen.dart';
import 'notifications_screen.dart';
import '../widgets/bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> recipes = [];

  final Set<String> favoritos = {};
  final Set<String> procesandoFavoritos = {};

  bool cargando = true;
  bool cargandoFavoritos = false;
  bool hayNotificacionesNuevas = false;

  String error = '';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificacionesSubscription;

  @override
  void initState() {
    super.initState();

    cargarDatos();
    escucharNotificaciones();
  }

  @override
  void dispose() {
    _notificacionesSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // CARGAR TODO
  // ============================================================

  Future<void> cargarDatos() async {
    await Future.wait([cargarRecetas(), cargarFavoritos()]);
  }

  // ============================================================
  // ESCUCHAR NOTIFICACIONES EN TIEMPO REAL
  // ============================================================

  void escucharNotificaciones() {
    _notificacionesSubscription?.cancel();

    final User? usuario = _auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        hayNotificacionesNuevas = false;
      });

      return;
    }

    _notificacionesSubscription = _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('notificaciones')
        .snapshots()
        .listen(
          (snapshot) {
            bool hayNoLeidas = false;

            for (final documento in snapshot.docs) {
              final data = documento.data();
              final dynamic leida = data['leida'];

              if (leida is bool && !leida) {
                hayNoLeidas = true;
                break;
              }
            }

            if (!mounted) return;

            setState(() {
              hayNotificacionesNuevas = hayNoLeidas;
            });
          },
          onError: (error) {
            debugPrint('ERROR LISTENER NOTIFICACIONES: $error');

            if (!mounted) return;

            setState(() {
              hayNotificacionesNuevas = false;
            });
          },
        );
  }

  // ============================================================
  // RECETAS
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

        return <String, dynamic>{
          ...data,
          'id_receta': idReceta,
          'uid_receta': idReceta,
          '_documentId': idReceta,
          'nombre': data['nombre']?.toString() ?? '',
          'imagen': data['imagen']?.toString() ?? '',
          'descripcion': data['descripcion']?.toString() ?? '',
          'ingredientes': data['ingredientes']?.toString() ?? '',
          'pasos': data['pasos']?.toString() ?? '',
          'fecha_publicacion': data['fecha_publicacion'],
        };
      }).toList();

      lista.sort((a, b) {
        final fechaA = _obtenerFecha(a['fecha_publicacion']);
        final fechaB = _obtenerFecha(b['fecha_publicacion']);

        return fechaB.compareTo(fechaA);
      });

      if (!mounted) return;

      setState(() {
        recipes = lista;
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE RECETAS: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las recetas';
        cargando = false;
      });
    }
  }

  DateTime _obtenerFecha(dynamic valor) {
    if (valor == null) {
      return DateTime(2000);
    }

    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    final fecha = DateTime.tryParse(valor.toString());

    return fecha ?? DateTime(2000);
  }

  // ============================================================
  // FAVORITOS
  // ============================================================

  Future<void> cargarFavoritos() async {
    if (cargandoFavoritos) {
      return;
    }

    final User? usuario = _auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        favoritos.clear();
        cargandoFavoritos = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      cargandoFavoritos = true;
    });

    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('favoritos')
          .get();

      final Set<String> favoritosFirestore = {};

      for (final doc in snapshot.docs) {
        final String idReceta = doc.id;

        if (idReceta.isNotEmpty) {
          favoritosFirestore.add(idReceta);
        }
      }

      if (!mounted) return;

      setState(() {
        favoritos
          ..clear()
          ..addAll(favoritosFirestore);

        cargandoFavoritos = false;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE FAVORITOS: $e');

      if (!mounted) return;

      setState(() {
        cargandoFavoritos = false;
      });
    }
  }

  // ============================================================
  // CAMBIAR FAVORITO
  // ============================================================

  Future<void> cambiarFavorito(Map<String, dynamic> receta) async {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        receta['_documentId']?.toString() ??
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

    final bool favoritoAnterior = favoritos.contains(idReceta);

    if (!mounted) return;

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
      debugPrint('ERROR ACTUALIZANDO FAVORITO: $e');

      if (!mounted) return;

      setState(() {
        if (favoritoAnterior) {
          favoritos.add(idReceta);
        } else {
          favoritos.remove(idReceta);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el favorito',
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
  // FAVORITO - ESTADO
  // ============================================================

  bool esFavorito(Map<String, dynamic> receta) {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        receta['_documentId']?.toString() ??
        '';

    return favoritos.contains(idReceta);
  }

  bool favoritoProcesandose(Map<String, dynamic> receta) {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        receta['_documentId']?.toString() ??
        '';

    return procesandoFavoritos.contains(idReceta);
  }

  // ============================================================
  // ABRIR DETALLE
  // ============================================================

  void abrirDetalleReceta(Map<String, dynamic> receta) {
    final String idReceta =
        receta['uid_receta']?.toString() ??
        receta['id_receta']?.toString() ??
        receta['_documentId']?.toString() ??
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

  // ============================================================
  // NOTIFICACIONES
  // ============================================================

  Future<void> abrirNotificaciones() async {
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(idUsuario: usuario.uid),
      ),
    );

    if (!mounted) return;

    escucharNotificaciones();
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
          SafeArea(child: _buildContenidoPrincipal()),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: BottomNavigation(currentIndex: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENIDO PRINCIPAL
  // ============================================================

  Widget _buildContenidoPrincipal() {
    if (cargando) {
      return _buildLoading();
    }

    if (error.isNotEmpty) {
      return _buildError();
    }

    if (recipes.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildWelcome()),
          SliverToBoxAdapter(child: _buildFeaturedRecipe()),
          SliverToBoxAdapter(child: _buildSectionTitle()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final recipe = recipes[index];

                return _buildRecipeCard(recipe: recipe);
              }, childCount: recipes.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 20,
                childAspectRatio: 0.70,
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
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: abrirNotificaciones,
                splashRadius: 22,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black,
                  size: 25,
                ),
              ),
              if (hayNotificacionesNuevas)
                Positioned(
                  right: 8,
                  top: 7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xfff60303),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descubre sabores',
            style: GoogleFonts.poppins(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'de nuestra región',
            style: GoogleFonts.poppins(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.8,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Recetas y sabores de Ixmiquilpan, Cardonal y sus alrededores.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xff777777),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECETA DESTACADA
  // ============================================================

  Widget _buildFeaturedRecipe() {
    final recipe = recipes.first;

    final String title = recipe['nombre']?.toString() ?? 'Receta destacada';
    final String imagen = recipe['imagen']?.toString() ?? '';

    final bool favorito = esFavorito(recipe);
    final bool procesando = favoritoProcesandose(recipe);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () {
          abrirDetalleReceta(recipe);
        },
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xfff1f1f1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(imageUrl: imagen, borderRadius: 22),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1.0],
                      colors: [Colors.transparent, Color(0xcc000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'RECETA NUEVA',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: procesando
                        ? null
                        : () {
                            cambiarFavorito(recipe);
                          },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                      ),
                      child: procesando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
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
                              size: 21,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 21,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 43,
                        height: 43,
                        decoration: const BoxDecoration(
                          color: verde,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Recetas para descubrir',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            'Explora',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: verdeOscuro,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECIPE CARD
  // ============================================================

  Widget _buildRecipeCard({required Map<String, dynamic> recipe}) {
    final String title = recipe['nombre']?.toString() ?? 'Sin nombre';
    final String imagen = recipe['imagen']?.toString() ?? '';

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
                  child: _buildImage(imageUrl: imagen, borderRadius: 17),
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

  Widget _buildImage({required String imageUrl, required double borderRadius}) {
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
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(220, 30),
                const SizedBox(height: 7),
                _skeletonBox(175, 30),
                const SizedBox(height: 12),
                _skeletonBox(double.infinity, 15),
                const SizedBox(height: 4),
                _skeletonBox(250, 15),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: AspectRatio(
              aspectRatio: 1,
              child: _skeletonBox(double.infinity, double.infinity, radius: 22),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 17),
            child: _skeletonBox(210, 22),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _skeletonBox(
                      double.infinity,
                      double.infinity,
                      radius: 17,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _skeletonBox(130, 14),
                  const SizedBox(height: 5),
                  _skeletonBox(90, 11),
                ],
              );
            }, childCount: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 20,
              childAspectRatio: 0.70,
            ),
          ),
        ),
      ],
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
    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 130),
        children: [
          _buildHeader(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.58,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
            ),
          ),
        ],
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
      onRefresh: cargarDatos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(),
          const SizedBox(height: 150),
          const Icon(
            Icons.restaurant_menu_outlined,
            size: 55,
            color: Color(0xffaaaaaa),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Todavía no hay recetas',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Text(
              'Pronto encontrarás nuevos sabores para descubrir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff777777),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
