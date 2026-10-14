import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../widgets/admin_bottom_navigation.dart';

class AdminCreateRecipeScreen extends StatefulWidget {
  final Map<String, dynamic>? receta;

  const AdminCreateRecipeScreen({super.key, this.receta});

  @override
  State<AdminCreateRecipeScreen> createState() =>
      _AdminCreateRecipeScreenState();
}

class _AdminCreateRecipeScreenState extends State<AdminCreateRecipeScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController ingredientesController = TextEditingController();
  final TextEditingController pasosController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  XFile? imagenSeleccionada;
  Uint8List? imagenBytes;

  bool guardando = false;

  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);
  static const Color grisTexto = Color(0xff777777);
  static const Color grisClaro = Color(0xfff1f1f1);

  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String cloudName = 'xpfpcclr';
  static const String uploadPreset = 'armadillos_recetas';

  // ============================================================
  // DATOS DE EDICIÓN
  // ============================================================

  bool get editando => widget.receta != null;

  String get imagenActual {
    return widget.receta?['imagen']?.toString().trim() ?? '';
  }

  String get documentoActual {
    return widget.receta?['_docId']?.toString().trim() ?? '';
  }

  @override
  void initState() {
    super.initState();

    if (editando) {
      final receta = widget.receta!;

      nombreController.text = receta['nombre']?.toString() ?? '';
      descripcionController.text = receta['descripcion']?.toString() ?? '';
      ingredientesController.text = receta['ingredientes']?.toString() ?? '';
      pasosController.text = receta['pasos']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    descripcionController.dispose();
    ingredientesController.dispose();
    pasosController.dispose();
    super.dispose();
  }

  // ============================================================
  // SELECCIONAR IMAGEN
  // ============================================================

  Future<void> seleccionarImagen() async {
    if (guardando) return;

    try {
      final XFile? imagen = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (imagen == null) return;

      final Uint8List bytes = await imagen.readAsBytes();

      if (!mounted) return;

      setState(() {
        imagenSeleccionada = imagen;
        imagenBytes = bytes;
      });
    } catch (e) {
      debugPrint('ERROR SELECCIONANDO IMAGEN: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo seleccionar la imagen', esError: true);
    }
  }

  // ============================================================
  // SUBIR IMAGEN A CLOUDINARY
  // ============================================================

  Future<String> subirImagenCloudinary(int idReceta) async {
    if (imagenBytes == null || imagenSeleccionada == null) {
      throw Exception('No se seleccionó ninguna imagen');
    }

    final String nombreArchivo =
        'receta_${idReceta}_${DateTime.now().millisecondsSinceEpoch}';

    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final http.MultipartRequest request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['public_id'] = nombreArchivo;
    request.fields['folder'] = 'recetas';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imagenBytes!,
        filename: imagenSeleccionada!.name,
      ),
    );

    final http.StreamedResponse response = await request.send();

    final String responseBody = await response.stream.bytesToString();

    debugPrint('CLOUDINARY STATUS: ${response.statusCode}');
    debugPrint('CLOUDINARY RESPONSE: $responseBody');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String mensaje = 'No se pudo subir la imagen a Cloudinary';

      try {
        final Map<String, dynamic> errorData =
            jsonDecode(responseBody) as Map<String, dynamic>;

        final dynamic error = errorData['error'];

        if (error is Map<String, dynamic> && error['message'] != null) {
          mensaje = error['message'].toString();
        }
      } catch (_) {}

      throw Exception(mensaje);
    }

    final Map<String, dynamic> data =
        jsonDecode(responseBody) as Map<String, dynamic>;

    final String secureUrl = data['secure_url']?.toString().trim() ?? '';

    if (secureUrl.isEmpty) {
      throw Exception('Cloudinary no devolvió la URL de la imagen');
    }

    return secureUrl;
  }

  // ============================================================
  // OBTENER SIGUIENTE ID DE RECETA
  // ============================================================

  Future<int> obtenerSiguienteIdReceta() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection('recetas')
        .get();

    int mayorId = 0;

    for (final documento in snapshot.docs) {
      final data = documento.data();

      final int id = int.tryParse(data['id_receta']?.toString() ?? '') ?? 0;

      if (id > mayorId) {
        mayorId = id;
      }
    }

    return mayorId + 1;
  }

  // ============================================================
  // OBTENER PERFIL DEL ADMINISTRADOR
  // ============================================================

  Future<DocumentSnapshot<Map<String, dynamic>>> obtenerPerfilAdmin(
    User usuario,
  ) async {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .get();
  }

  // ============================================================
  // CREAR NOTIFICACIONES PARA LOS USUARIOS
  // ============================================================

  Future<void> crearNotificacionesNuevaReceta({
    required String recetaId,
    required String nombre,
    required String descripcion,
    required String imagen,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    debugPrint('====================================');
    debugPrint('INICIANDO CREACIÓN DE NOTIFICACIONES');
    debugPrint('RECETA ID: $recetaId');
    debugPrint('RECETA: $nombre');
    debugPrint('====================================');

    final QuerySnapshot<Map<String, dynamic>> usuariosSnapshot = await firestore
        .collection('usuarios')
        .where('rol', isEqualTo: 'usuario')
        .get();

    debugPrint('USUARIOS ENCONTRADOS: ${usuariosSnapshot.docs.length}');

    if (usuariosSnapshot.docs.isEmpty) {
      debugPrint('NO HAY USUARIOS CON ROL usuario');
      return;
    }

    final WriteBatch batch = firestore.batch();

    int contador = 0;

    for (final usuario in usuariosSnapshot.docs) {
      final String uidUsuario = usuario.id;

      final DocumentReference<Map<String, dynamic>> notificacionRef = firestore
          .collection('usuarios')
          .doc(uidUsuario)
          .collection('notificaciones')
          .doc();

      batch.set(notificacionRef, {
        // IMPORTANTE:
        // Este es el ID DEL DOCUMENTO de recetas.
        'id_receta': recetaId,

        'nombre': nombre,
        'descripcion': descripcion,
        'imagen': imagen,

        'leida': false,

        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      contador++;

      debugPrint('NOTIFICACIÓN PREPARADA PARA USUARIO: $uidUsuario');
    }

    await batch.commit();

    debugPrint('====================================');
    debugPrint('NOTIFICACIONES CREADAS CORRECTAMENTE: $contador');
    debugPrint('====================================');
  }

  // ============================================================
  // GUARDAR RECETA
  // ============================================================

  Future<bool> guardarReceta() async {
    final bool camposVacios =
        nombreController.text.trim().isEmpty ||
        descripcionController.text.trim().isEmpty ||
        ingredientesController.text.trim().isEmpty ||
        pasosController.text.trim().isEmpty;

    if (camposVacios) {
      _mostrarMensaje('Completa todos los campos', esError: true);
      return false;
    }

    if (!editando && (imagenSeleccionada == null || imagenBytes == null)) {
      _mostrarMensaje('Selecciona una imagen', esError: true);
      return false;
    }

    if (editando && documentoActual.isEmpty) {
      _mostrarMensaje(
        'No se encontró el documento de la receta',
        esError: true,
      );
      return false;
    }

    final User? usuarioFirebase = FirebaseAuth.instance.currentUser;

    if (usuarioFirebase == null) {
      _mostrarMensaje('No hay una sesión activa', esError: true);
      return false;
    }

    if (guardando) return false;

    setState(() {
      guardando = true;
    });

    try {
      // ----------------------------------------------------------
      // VERIFICAR SESIÓN Y PERFIL DEL ADMIN
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> perfilAdmin =
          await obtenerPerfilAdmin(usuarioFirebase);

      if (!perfilAdmin.exists) {
        throw Exception('No existe el perfil del administrador en Firestore');
      }

      final Map<String, dynamic>? datosAdmin = perfilAdmin.data();

      if (datosAdmin == null) {
        throw Exception('No se pudieron obtener los datos del administrador');
      }

      final String rol =
          datosAdmin['rol']?.toString().toLowerCase().trim() ?? '';

      if (rol != 'admin') {
        throw Exception('El usuario actual no tiene permisos de administrador');
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final String uidAdmin = usuarioFirebase.uid;

      final String nombreAdmin = datosAdmin['nombre']?.toString().trim() ?? '';

      final String correoAdmin =
          datosAdmin['correo']?.toString().trim() ??
          usuarioFirebase.email ??
          '';

      // ----------------------------------------------------------
      // EDITAR RECETA
      // ----------------------------------------------------------

      if (editando) {
        String imagenUrl = imagenActual;

        final int idReceta =
            int.tryParse(widget.receta?['id_receta']?.toString() ?? '') ?? 0;

        if (idReceta <= 0) {
          throw Exception('ID de receta inválido');
        }

        // Si seleccionó una nueva imagen, la subimos.
        if (imagenSeleccionada != null && imagenBytes != null) {
          debugPrint('SUBIENDO NUEVA IMAGEN DE RECETA $idReceta');

          imagenUrl = await subirImagenCloudinary(idReceta);

          debugPrint('NUEVA IMAGEN SUBIDA CORRECTAMENTE');
        }

        await firestore.collection('recetas').doc(documentoActual).update({
          'nombre': nombreController.text.trim(),
          'descripcion': descripcionController.text.trim(),
          'ingredientes': ingredientesController.text.trim(),
          'pasos': pasosController.text.trim(),
          'imagen': imagenUrl,
          'id_admin': uidAdmin,
          'uid_admin': uidAdmin,
          'nombre_admin': nombreAdmin,
          'correo_admin': correoAdmin,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });

        debugPrint('RECETA ACTUALIZADA CORRECTAMENTE');
      }
      // ----------------------------------------------------------
      // CREAR RECETA
      // ----------------------------------------------------------
      else {
        final int idReceta = await obtenerSiguienteIdReceta();

        debugPrint('====================================');
        debugPrint('NUEVO ID DE RECETA: $idReceta');
        debugPrint('====================================');

        debugPrint('SUBIENDO IMAGEN A CLOUDINARY...');

        final String imagenUrl = await subirImagenCloudinary(idReceta);

        debugPrint('IMAGEN SUBIDA CORRECTAMENTE');

        // --------------------------------------------------------
        // AQUÍ ESTÁ EL CAMBIO IMPORTANTE
        // --------------------------------------------------------
        // Guardamos la referencia del documento creado
        // para obtener su ID de Firestore.
        final DocumentReference<Map<String, dynamic>> recetaRef =
            await firestore.collection('recetas').add({
              'id_receta': idReceta,
              'nombre': nombreController.text.trim(),
              'descripcion': descripcionController.text.trim(),
              'ingredientes': ingredientesController.text.trim(),
              'pasos': pasosController.text.trim(),
              'imagen': imagenUrl,
              'id_admin': uidAdmin,
              'uid_admin': uidAdmin,
              'nombre_admin': nombreAdmin,
              'correo_admin': correoAdmin,
              'fecha_publicacion': FieldValue.serverTimestamp(),
            });

        // Este es el ID que necesita la
        // NotificationsScreen.
        final String idDocumentoReceta = recetaRef.id;

        debugPrint('====================================');
        debugPrint('RECETA CREADA CORRECTAMENTE');
        debugPrint('DOCUMENT ID: $idDocumentoReceta');
        debugPrint('ID NUMÉRICO: $idReceta');
        debugPrint('====================================');

        // --------------------------------------------------------
        // CREAR NOTIFICACIONES
        // --------------------------------------------------------
        // Solamente se crean cuando es una NUEVA receta.
        //
        // Si falla la creación de notificaciones,
        // NO eliminamos la receta.
        try {
          await crearNotificacionesNuevaReceta(
            recetaId: idDocumentoReceta,
            nombre: nombreController.text.trim(),
            descripcion: descripcionController.text.trim(),
            imagen: imagenUrl,
          );

          debugPrint('NOTIFICACIONES GENERADAS CORRECTAMENTE');
        } catch (e) {
          debugPrint('====================================');
          debugPrint('ERROR CREANDO NOTIFICACIONES');
          debugPrint('$e');
          debugPrint('LA RECETA SE CONSERVA EN FIRESTORE');
          debugPrint('====================================');
        }
      }

      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        'ERROR FIREBASE GUARDANDO RECETA: '
        '${e.code} - ${e.message}',
      );

      if (!mounted) return false;

      String mensaje = 'No se pudo guardar la receta';

      if (e.code == 'permission-denied') {
        mensaje = 'Firebase no permite realizar esta operación.';
      } else if (e.code == 'unauthenticated') {
        mensaje = 'La sesión de Firebase ya no es válida.';
      } else if (e.code == 'unauthorized') {
        mensaje = 'No tienes permisos para guardar la receta.';
      }

      _mostrarMensaje(mensaje, esError: true);

      return false;
    } catch (e) {
      debugPrint('ERROR GUARDANDO RECETA: $e');

      if (!mounted) return false;

      _mostrarMensaje(
        e.toString().replaceFirst('Exception: ', ''),
        esError: true,
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  // ============================================================
  // BOTÓN GUARDAR
  // ============================================================

  Future<void> _presionarGuardar() async {
    if (guardando) return;

    final bool guardado = await guardarReceta();

    if (!mounted) return;

    if (guardado) {
      Navigator.of(context).pop(true);
    }
  }

  // ============================================================
  // CANCELAR
  // ============================================================

  void cancelar() {
    if (guardando) return;

    Navigator.of(context).pop(false);
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: esError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration campoDecoracion({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xffaaaaaa),
        fontSize: 12.5,
      ),
      filled: true,
      fillColor: const Color(0xfffafafa),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffe5e5e5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: verde, width: 1.2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffe5e5e5)),
      ),
    );
  }

  // ============================================================
  // TÍTULO DE CAMPO
  // ============================================================

  Widget tituloCampo(String texto) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: guardando ? null : cancelar,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: grisClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.black,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/logo.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            'armadillo',
            style: GoogleFonts.poppins(
              fontSize: 18,
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
  // SELECTOR DE IMAGEN
  // ============================================================

  Widget _buildSelectorImagen() {
    if (imagenBytes != null) {
      return _buildImagenSeleccionada();
    }

    if (editando && imagenActual.isNotEmpty) {
      return _buildImagenActual();
    }

    return _buildImagenVacia();
  }

  // ============================================================
  // IMAGEN SELECCIONADA
  // ============================================================

  Widget _buildImagenSeleccionada() {
    return GestureDetector(
      onTap: guardando ? null : seleccionarImagen,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: grisClaro,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.memory(imagenBytes!, fit: BoxFit.cover),
              ),
              _buildBotonCambiarImagen(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGEN ACTUAL
  // ============================================================

  Widget _buildImagenActual() {
    return GestureDetector(
      onTap: guardando ? null : seleccionarImagen,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: grisClaro,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imagenActual,
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
                    debugPrint('ERROR IMAGEN RECETA: $error');

                    return _buildImagenActualError();
                  },
                ),
              ),
              _buildBotonCambiarImagen(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTÓN CAMBIAR IMAGEN
  // ============================================================

  Widget _buildBotonCambiarImagen() {
    return Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: guardando ? null : seleccionarImagen,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGEN VACÍA
  // ============================================================

  Widget _buildImagenVacia() {
    return GestureDetector(
      onTap: guardando ? null : seleccionarImagen,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xfffafafa),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffe5e5e5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: grisClaro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 27,
                  color: verdeOscuro,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Seleccionar imagen',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Text(
                  'Elige una imagen desde tu dispositivo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.4,
                    color: grisTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR IMAGEN
  // ============================================================

  Widget _buildImagenActualError() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: grisClaro,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xffaaaaaa),
        size: 40,
      ),
    );
  }

  // ============================================================
  // BOTONES
  // ============================================================

  Widget _buildBotones() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: guardando ? null : _presionarGuardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
              disabledBackgroundColor: verde.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: guardando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        editando ? Icons.check_rounded : Icons.add_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        editando ? 'Actualizar receta' : 'Guardar receta',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: guardando ? null : cancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: Color(0xffdddddd)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editando ? 'Editar receta' : 'Nueva receta',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          editando
                              ? 'Actualiza los datos de esta receta regional.'
                              : 'Agrega un nuevo sabor a nuestro recetario.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.45,
                            color: grisTexto,
                          ),
                        ),
                        const SizedBox(height: 28),

                        tituloCampo('Nombre de la receta'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nombreController,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                          decoration: campoDecoracion(
                            hintText: 'Ej. Barbacoa de borrego',
                          ),
                        ),

                        const SizedBox(height: 22),

                        tituloCampo('Imagen'),
                        const SizedBox(height: 8),
                        _buildSelectorImagen(),

                        const SizedBox(height: 22),

                        tituloCampo('Descripción'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descripcionController,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.black,
                          ),
                          decoration: campoDecoracion(
                            hintText: 'Describe brevemente la receta',
                          ),
                        ),

                        const SizedBox(height: 22),

                        tituloCampo('Ingredientes'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ingredientesController,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.black,
                          ),
                          decoration: campoDecoracion(
                            hintText: 'Escribe los ingredientes, uno por línea',
                          ),
                        ),

                        const SizedBox(height: 22),

                        tituloCampo('Pasos de preparación'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pasosController,
                          maxLines: 10,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.black,
                          ),
                          decoration: campoDecoracion(
                            hintText: 'Escribe paso a paso la preparación',
                          ),
                        ),

                        const SizedBox(height: 28),

                        _buildBotones(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navegación inferior flotante
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdminBottomNavigation(currentIndex: editando ? 0 : 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
