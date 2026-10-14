import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_detail_screen.dart';
import '../widgets/admin_bottom_navigation.dart';

class AdminSearchScreen extends StatefulWidget {
  const AdminSearchScreen({super.key});

  @override
  State<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends State<AdminSearchScreen> {
  final TextEditingController buscadorController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> recetas = [];
  List<Map<String, dynamic>> resultados = [];

  bool cargando = true;
  String error = '';

  static const Color verde = Color(0xff16D928);

  @override
  void initState() {
    super.initState();

    buscadorController.addListener(_buscarRecetas);
    cargarRecetas();
  }

  Future<void> cargarRecetas() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = '';
    });

    try {
      final snapshot = await _firestore.collection('recetas').get();

      final lista = snapshot.docs.map((doc) {
        final data = doc.data();

        // El ID oficial de la receta es el ID del documento
        // de Firestore.
        return <String, dynamic>{
          ...data,
          'id_receta': doc.id,
          '_documentId': doc.id,
        };
      }).toList();

      lista.sort((a, b) {
        final fechaA = a['fecha_publicacion'];
        final fechaB = b['fecha_publicacion'];

        DateTime? convertirFecha(dynamic fecha) {
          if (fecha is Timestamp) {
            return fecha.toDate();
          }

          if (fecha is DateTime) {
            return fecha;
          }

          return DateTime.tryParse(fecha?.toString() ?? '');
        }

        final aFecha = convertirFecha(fechaA);
        final bFecha = convertirFecha(fechaB);

        if (aFecha == null && bFecha == null) {
          return 0;
        }

        if (aFecha == null) {
          return 1;
        }

        if (bFecha == null) {
          return -1;
        }

        return bFecha.compareTo(aFecha);
      });

      if (!mounted) return;

      setState(() {
        recetas = lista;
        resultados = _filtrarRecetas(lista, buscadorController.text);
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE BUSCAR RECETAS: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las recetas.';
      });
    }
  }

  List<Map<String, dynamic>> _filtrarRecetas(
    List<Map<String, dynamic>> lista,
    String texto,
  ) {
    final busqueda = texto.toLowerCase().trim();

    if (busqueda.isEmpty) {
      return lista;
    }

    return lista.where((receta) {
      final nombre = receta['nombre']?.toString().toLowerCase() ?? '';

      final descripcion = receta['descripcion']?.toString().toLowerCase() ?? '';

      final ingredientes =
          receta['ingredientes']?.toString().toLowerCase() ?? '';

      return nombre.contains(busqueda) ||
          descripcion.contains(busqueda) ||
          ingredientes.contains(busqueda);
    }).toList();
  }

  void _buscarRecetas() {
    if (!mounted) return;

    setState(() {
      resultados = _filtrarRecetas(recetas, buscadorController.text);
    });
  }

  void _abrirDetalleReceta(Map<String, dynamic> receta) {
    // El ID de la receta ahora es String porque
    // corresponde al ID del documento de Firestore.
    final String idReceta =
        receta['_documentId']?.toString() ??
        receta['id_receta']?.toString() ??
        '';

    if (idReceta.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo identificar la receta.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
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

  @override
  void dispose() {
    buscadorController.removeListener(_buscarRecetas);
    buscadorController.dispose();
    super.dispose();
  }

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
                child: AdminBottomNavigation(currentIndex: 2),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buscar recetas',
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
            'Encuentra y consulta las recetas publicadas.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xff777777),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final bool tieneTexto = buscadorController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(17),
        ),
        child: TextField(
          controller: buscadorController,
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
            suffixIcon: tieneTexto
                ? IconButton(
                    onPressed: () {
                      buscadorController.clear();
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

  Widget _buildResultados() {
    if (cargando) {
      return _buildLoading();
    }

    if (error.isNotEmpty) {
      return _buildError();
    }

    if (resultados.isEmpty) {
      return _buildEmptySearch();
    }

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarRecetas,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 20,
          childAspectRatio: 0.70,
        ),
        itemCount: resultados.length,
        itemBuilder: (context, index) {
          return _buildRecipeItem(resultados[index]);
        },
      ),
    );
  }

  Widget _buildRecipeItem(Map<String, dynamic> receta) {
    final String title = receta['nombre']?.toString().trim().isNotEmpty == true
        ? receta['nombre'].toString().trim()
        : 'Sin nombre';

    final String imageUrl = receta['imagen']?.toString().trim() ?? '';

    return GestureDetector(
      onTap: () {
        _abrirDetalleReceta(receta);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xfff1f1f1),
                borderRadius: BorderRadius.circular(17),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildImage(imageUrl: imageUrl),
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

  Widget _buildImage({required String imageUrl}) {
    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('ERROR IMAGEN BUSQUEDA: $imageUrl\n$error');

        return _buildImagePlaceholder();
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

  Widget _buildImagePlaceholder() {
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
              onPressed: cargarRecetas,
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

  Widget _buildEmptySearch() {
    final bool estaBuscando = buscadorController.text.trim().isNotEmpty;

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarRecetas,
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
