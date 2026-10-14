import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String idReceta;

  const RecipeDetailScreen({super.key, required this.idReceta});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? receta;

  bool cargando = true;
  String? error;

  bool favorito = false;
  bool procesandoFavorito = false;

  User? usuarioActual;
  bool esAdmin = false;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = null;
    });

    usuarioActual = _auth.currentUser;

    await cargarUsuario();
    await cargarReceta();

    if (usuarioActual != null && !esAdmin) {
      await cargarEstadoFavorito();
    }

    if (!mounted) return;

    setState(() {
      cargando = false;
    });
  }

  Future<void> cargarUsuario() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        usuarioActual = null;
        esAdmin = false;
      });

      return;
    }

    usuarioActual = user;

    try {
      final documento = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!documento.exists) {
        setState(() {
          esAdmin = false;
        });

        return;
      }

      final data = documento.data();

      final String rol = data?['rol']?.toString().toLowerCase().trim() ?? '';

      setState(() {
        esAdmin = rol == 'admin';
      });
    } catch (e) {
      debugPrint('ERROR AL OBTENER USUARIO: $e');

      if (!mounted) return;

      setState(() {
        esAdmin = false;
      });
    }
  }

  Future<void> cargarReceta() async {
    try {
      if (widget.idReceta.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          receta = null;
          error = 'No se encontró el identificador de la receta';
        });

        return;
      }

      final documento = await _firestore
          .collection('recetas')
          .doc(widget.idReceta)
          .get();

      if (!mounted) return;

      if (!documento.exists) {
        setState(() {
          receta = null;
          error = 'No se encontró la receta';
        });

        return;
      }

      final data = documento.data();

      if (data == null) {
        setState(() {
          receta = null;
          error = 'La receta no contiene información';
        });

        return;
      }

      setState(() {
        receta = {...data, 'uid_receta': documento.id};
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE DETALLE RECETA: $e');

      if (!mounted) return;

      setState(() {
        receta = null;
        error = 'No se pudo cargar la receta';
      });
    }
  }

  Future<void> cargarEstadoFavorito() async {
    final User? user = _auth.currentUser;

    if (user == null || esAdmin) {
      return;
    }

    try {
      final favoritoDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .collection('favoritos')
          .doc(widget.idReceta)
          .get();

      if (!mounted) return;

      setState(() {
        favorito = favoritoDoc.exists;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR FAVORITO: $e');
    }
  }

  Future<void> cambiarFavorito() async {
    if (procesandoFavorito) return;

    final User? user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes iniciar sesión para guardar favoritos',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    if (esAdmin) return;

    if (widget.idReceta.trim().isEmpty) {
      return;
    }

    setState(() {
      procesandoFavorito = true;
    });

    try {
      final referencia = _firestore
          .collection('usuarios')
          .doc(user.uid)
          .collection('favoritos')
          .doc(widget.idReceta);

      if (favorito) {
        await referencia.delete();

        if (!mounted) return;

        setState(() {
          favorito = false;
          procesandoFavorito = false;
        });
      } else {
        await referencia.set({
          'uid_receta': widget.idReceta,
          'fecha_agregado': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          favorito = true;
          procesandoFavorito = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR AL CAMBIAR FAVORITO: $e');

      if (!mounted) return;

      setState(() {
        procesandoFavorito = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el favorito',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: verde, strokeWidth: 2.5),
      );
    }

    if (error != null) {
      return _buildError();
    }

    if (receta == null) {
      return Center(
        child: Text(
          'No se encontró la receta',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    final String nombre = receta!['nombre']?.toString() ?? 'Sin nombre';

    final String descripcion = receta!['descripcion']?.toString() ?? '';

    final String ingredientes = receta!['ingredientes']?.toString() ?? '';

    final String pasos = receta!['pasos']?.toString() ?? '';

    final String imagen = receta!['imagen']?.toString().trim() ?? '';

    return RefreshIndicator(
      color: verde,
      onRefresh: cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecipeImage(imagen),
            const SizedBox(height: 18),
            _buildRecipeHeader(nombre),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 11),
              Text(
                descripcion,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 27),
            _buildSectionTitle(
              icon: Icons.shopping_basket_outlined,
              title: 'Ingredientes',
            ),
            const SizedBox(height: 12),
            _buildIngredients(ingredientes),
            const SizedBox(height: 30),
            _buildSectionTitle(
              icon: Icons.restaurant_outlined,
              title: 'Preparación',
            ),
            const SizedBox(height: 12),
            _buildSteps(pasos),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 65,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
            const SizedBox(width: 12),
            Image.asset('assets/images/logo.png', width: 40, height: 40),
            const SizedBox(width: 7),
            Text(
              'armadillo',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String imagenUrl) {
    if (imagenUrl.isEmpty) {
      return _buildImageError();
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          imagenUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ERROR IMAGEN RECETA: $imagenUrl\n$error');

            return _buildImageError();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              color: const Color(0xfff3f3f3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: verde,
                  strokeWidth: 2.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 42),
        ),
      ),
    );
  }

  Widget _buildRecipeHeader(String nombre) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            nombre,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.7,
            ),
          ),
        ),
        if (!esAdmin) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: cambiarFavorito,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: favorito
                    ? const Color(0xffe9faeb)
                    : const Color(0xfff5f5f5),
                shape: BoxShape.circle,
              ),
              child: procesandoFavorito
                  ? const Center(
                      child: SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          color: verde,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Icon(
                      favorito ? Icons.favorite : Icons.favorite_border,
                      color: favorito ? verdeOscuro : Colors.black87,
                      size: 23,
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: const BoxDecoration(
            color: Color(0xffe9faeb),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: verdeOscuro, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredients(String texto) {
    if (texto.trim().isEmpty) {
      return Text(
        'No hay ingredientes registrados.',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
      );
    }

    final ingredientes = texto
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (ingredientes.length <= 1) {
      return _buildSingleTextBlock(texto);
    }

    return Column(
      children: List.generate(ingredientes.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xfffafafa),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffeeeeee)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: verde,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    ingredientes[index],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSteps(String texto) {
    if (texto.trim().isEmpty) {
      return Text(
        'No hay instrucciones registradas.',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
      );
    }

    final pasos = texto
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (pasos.length <= 1) {
      return _buildSingleTextBlock(texto);
    }

    return Column(
      children: List.generate(pasos.length, (index) {
        final numero = (index + 1).toString().padLeft(2, '0');

        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: index == 0 ? verde : const Color(0xffe9faeb),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  numero,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: index == 0 ? Colors.white : verdeOscuro,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xfffafafa),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xffeeeeee)),
                  ),
                  child: Text(
                    pasos[index],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSingleTextBlock(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xffeeeeee)),
      ),
      child: Text(
        texto,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.black87,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: const BoxDecoration(
                color: Color(0xffffeeee),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No pudimos cargar la receta',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              error ?? 'Ocurrió un error inesperado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: cargarDatos,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: verde,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Intentar nuevamente',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
