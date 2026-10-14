import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String idUsuario;

  const NotificationsScreen({super.key, required this.idUsuario});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> notifications = [];

  bool isLoading = true;
  bool isError = false;

  List<Map<String, dynamic>> get nuevas {
    return notifications.where((notification) {
      return _estaSinLeer(notification['leida']);
    }).toList();
  }

  List<Map<String, dynamic>> get anteriores {
    return notifications.where((notification) {
      return !_estaSinLeer(notification['leida']);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarNotificaciones();
  }

  bool _estaSinLeer(dynamic valor) {
    if (valor is bool) {
      return !valor;
    }

    return false;
  }

  DateTime _obtenerFecha(dynamic valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return DateTime(2000);
  }

  Future<void> cargarNotificaciones() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(widget.idUsuario)
          .collection('notificaciones')
          .get();

      final List<Map<String, dynamic>> lista = [];

      for (final documento in snapshot.docs) {
        final data = documento.data();

        lista.add({...data, '_docId': documento.id});
      }

      lista.sort((a, b) {
        final fechaA = _obtenerFecha(a['fecha_creacion']);
        final fechaB = _obtenerFecha(b['fecha_creacion']);

        return fechaB.compareTo(fechaA);
      });

      if (!mounted) return;

      setState(() {
        notifications = lista;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE NOTIFICACIONES: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  Future<void> marcarComoLeida(Map<String, dynamic> notification) async {
    final String docId = notification['_docId']?.toString() ?? '';

    if (docId.isEmpty) return;

    try {
      await _firestore
          .collection('usuarios')
          .doc(widget.idUsuario)
          .collection('notificaciones')
          .doc(docId)
          .update({'leida': true, 'fecha_leida': FieldValue.serverTimestamp()});

      if (!mounted) return;

      setState(() {
        final index = notifications.indexWhere(
          (item) => item['_docId'] == docId,
        );

        if (index != -1) {
          notifications[index]['leida'] = true;
        }
      });
    } catch (e) {
      debugPrint('ERROR MARCANDO NOTIFICACION: $e');
    }
  }

  Future<void> abrirNotificacion(Map<String, dynamic> notification) async {
    // Las nuevas notificaciones guardan el ID del
    // documento de Firestore de la receta en id_receta.
    //
    // uid_receta se mantiene como respaldo para
    // notificaciones antiguas.
    final String idReceta =
        notification['id_receta']?.toString() ??
        notification['uid_receta']?.toString() ??
        '';

    if (idReceta.isEmpty) {
      debugPrint('ERROR: La notificación no tiene id_receta.');
      return;
    }

    if (_estaSinLeer(notification['leida'])) {
      await marcarComoLeida(notification);
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(idReceta: idReceta)),
    );

    if (mounted) {
      await cargarNotificaciones();
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) {
      return '';
    }

    final DateTime fechaNotificacion = _obtenerFecha(fecha);

    if (fechaNotificacion.year == 2000) {
      return '';
    }

    final DateTime ahora = DateTime.now();

    Duration diferencia = ahora.difference(fechaNotificacion);

    if (diferencia.isNegative) {
      diferencia = Duration.zero;
    }

    if (diferencia.inMinutes < 1) {
      return 'Ahora';
    }

    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} minutos';
    }

    if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} horas';
    }

    if (diferencia.inDays == 1) {
      return 'Ayer';
    }

    if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    }

    return '${fechaNotificacion.day.toString().padLeft(2, '0')}/'
        '${fechaNotificacion.month.toString().padLeft(2, '0')}/'
        '${fechaNotificacion.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF16A923),
          ),
        ),
      );
    }

    if (isError) {
      return _buildErrorState();
    }

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF16A923),
      onRefresh: cargarNotificaciones,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          if (nuevas.isNotEmpty) ...[
            _buildSectionTitle('Nuevas'),
            const SizedBox(height: 10),
            ...nuevas.map((notification) => _buildNotification(notification)),
          ],
          if (anteriores.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSectionTitle('Anteriores'),
            const SizedBox(height: 10),
            ...anteriores.map(
              (notification) => _buildNotification(notification),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notificaciones',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildNotification(Map<String, dynamic> notification) {
    final bool noLeida = _estaSinLeer(notification['leida']);

    final String nombre = notification['nombre']?.toString() ?? 'Nueva receta';

    final String descripcion = notification['descripcion']?.toString() ?? '';

    final String? imagen = notification['imagen']?.toString();

    final String fecha = formatearFecha(notification['fecha_creacion']);

    return GestureDetector(
      onTap: () => abrirNotificacion(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecipeImage(imagen),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Nueva receta disponible',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: noLeida
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (noLeida)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 5),
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16D928),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF777777),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (fecha.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      fecha,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String? imagen) {
    if (imagen == null || imagen.isEmpty) {
      return _buildImagePlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imagen,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.restaurant_outlined,
        size: 25,
        color: Color(0xFF999999),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 30,
                color: Color(0xFF16A923),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No tienes notificaciones',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aquí aparecerán las nuevas recetas que '
              'publique el administrador.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF888888),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Color(0xFF999999),
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar las notificaciones',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comprueba tu conexión e inténtalo nuevamente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: cargarNotificaciones,
              child: Text(
                'Intentar nuevamente',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF16A923),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
