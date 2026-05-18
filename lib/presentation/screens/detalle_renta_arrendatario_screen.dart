import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'ubicacion_auto_screen.dart';
import 'arrendatario_rastreo_widget.dart';
import 'calificar_viaje_screen.dart';
import 'resenas_usuario_screen.dart';
import 'pdf_viewer_screen.dart';

class DetalleRentaArrendatarioScreen extends StatefulWidget {
  final String rentalId;
  final String ownerId;
  final Map<String, dynamic> rentalData;

  const DetalleRentaArrendatarioScreen({
    super.key,
    required this.rentalId,
    required this.ownerId,
    required this.rentalData,
  });

  @override
  State<DetalleRentaArrendatarioScreen> createState() => _DetalleRentaArrendatarioScreenState();
}

class _DetalleRentaArrendatarioScreenState extends State<DetalleRentaArrendatarioScreen> {
  bool _hasShownRatingDialog = false;

  Future<Map<String, dynamic>?> _getCarDocuments(String autoId) async {
    if (autoId.isEmpty) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('autos')
          .doc(autoId)
          .collection('documentos')
          .doc('documentos_info')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['documents'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error getting car documents: $e');
    }
    return null;
  }

  void _openDocument(BuildContext context, String? url, String title) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento no disponible')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(url: url, title: title),
      ),
    );
  }

  // Fetch owner data to display contact info
  Future<Map<String, dynamic>?> _getOwnerData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerId)
          .get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting owner data: $e');
      return null;
    }
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar Renta'),
          content: const Text(
            '¿Estás seguro de que deseas cancelar este viaje? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Flujo Stripe - Cancelar Pre-autorización y devolver fondos
      final String paymentId = widget.rentalData['stripePaymentIntentId'] ?? '';
      if (paymentId.isNotEmpty && newStatus == 'cancelled') {
        try {
          await FirebaseFunctions.instance.httpsCallable('cancelPayment').call({
            'paymentIntentId': paymentId,
          });
        } catch (e) {
          debugPrint('Error al cancelar pago: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.rentalId)
          .update({'status': newStatus});

      final autoId = widget.rentalData['autoId']?.toString() ?? '';
      if (newStatus == 'cancelled' && autoId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .update({'status': 'registrado'})
            .catchError((e) => debugPrint('Error devolviendo auto a registrado: $e'));
      }

      // Notificar al propietario
      final ownerId = widget.rentalData['ownerId'];
      if (ownerId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('notifications')
            .add({
          'title': 'Renta Cancelada',
          'body': 'El arrendatario ha cancelado la renta del auto.',
          'type': 'status_update',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': widget.rentalId,
        });
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renta cancelada exitosamente.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Detalle de Renta'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0), // Main blue
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .doc(widget.rentalId)
            .snapshots(),
        builder: (context, rentalSnapshot) {
          if (rentalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!rentalSnapshot.hasData || !rentalSnapshot.data!.exists) {
            return const Center(
              child: Text("La renta no existe o fue eliminada"),
            );
          }

          final currentRentalData =
              rentalSnapshot.data!.data() as Map<String, dynamic>;
          final status = currentRentalData['status'] ?? 'pending';
          final carBrand = currentRentalData['carBrand'] ?? '';
          final carModel = currentRentalData['carModel'] ?? '';
          final carYear = currentRentalData['carYear'] ?? '';
          final price =
              currentRentalData['pricePerKm'] ??
              currentRentalData['pricePerDay'] ??
              0;

          // Extraer fechas, pago y depósito
          final paymentMethod =
              currentRentalData['paymentMethod'] ?? 'No especificado';
          final startDateStr = currentRentalData['startDate'];
          final endDateStr = currentRentalData['endDate'];
          final estimatedTotalData = currentRentalData['estimatedTotal'];
          final double estimatedTotal = estimatedTotalData != null
              ? (estimatedTotalData as num).toDouble()
              : 0.0;

          final double distanciaFinal = (currentRentalData['distanciaRecorridaKm'] ?? 0).toDouble();
          final double finalBasePay = (currentRentalData['finalBasePay'] ?? (distanciaFinal * price)).toDouble();
          final double finalCommission = (currentRentalData['finalCommission'] ?? (finalBasePay * 0.20)).toDouble();
          
          // Usar el total estimado original si existe (ya que fue lo que se retuvo y cobró en Stripe)
          // de lo contrario usar el cálculo de base + comisión.
          final double finalTotalPay = estimatedTotal > 0 
              ? estimatedTotal 
              : finalBasePay + finalCommission;

          int days = 0;
          if (startDateStr != null && endDateStr != null) {
            try {
              final start = DateTime.parse(startDateStr);
              final end = DateTime.parse(endDateStr);
              days = end.difference(start).inDays + 1;
            } catch (_) {}
          }

          // Lógica para mostrar el diálogo automáticamente si el viaje terminó y el dueño no ha recibido calificación local.
          if (status == 'completed' &&
              currentRentalData['ownerRating'] == null &&
              !_hasShownRatingDialog) {
            _hasShownRatingDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (ctx) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¡Viaje Finalizado!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Por favor califica al dueño y al auto para ayudar a la comunidad.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF546E7A),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx); // Cierra el dialog
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CalificarViajeScreen(
                                    rentalId: widget.rentalId,
                                    targetUserId: widget.ownerId,
                                    role: 'owner',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Calificar ahora'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Calificar más tarde',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          }

          final timestamp = currentRentalData['createdAt'] as Timestamp?;
          final dateStr = timestamp != null
              ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
              : "N/A";

          return FutureBuilder<Map<String, dynamic>?>(
            future: _getOwnerData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data ?? {};
              final fullName =
                  userData['fullName'] ?? 'Propietario desconocido';
              final email = userData['email'] ?? 'No disponible';
              final phone = userData['phone'] ?? 'No registrado';
                final autoId = (currentRentalData['autoId'] ?? widget.rentalData['autoId'] ?? '').toString();

              String address = 'No registrada';
              if (userData['address'] != null && userData['address'] is Map) {
                final addr = userData['address'] as Map;
                address =
                    '${addr['calle'] ?? ''} ${addr['numero'] ?? ''}, ${addr['colonia'] ?? ''}';
                if (addr['municipio'] != null) {
                  address += ', ${addr['municipio']}';
                }
              }

              final initial = fullName.isNotEmpty
                  ? fullName[0].toUpperCase()
                  : '?';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Solo mostramos la información del propietario si el viaje no ha finalizado
                    if (status != 'completed' && status != 'rejected') ...[
                      // 1. HEADER: INFO DEL PROPIETARIO
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(
                          'Datos del Propietario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF455A64),
                          ),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.ownerId)
                            .collection('reviews')
                            .where('roleEvaluated', isEqualTo: 'owner')
                            .snapshots(),
                        builder: (context, reviewSnapshot) {
                          double average = 0.0;
                          int total = 0;
                          if (reviewSnapshot.hasData) {
                            final docs = reviewSnapshot.data!.docs;
                            total = docs.length;
                            if (total > 0) {
                              double sum = 0;
                              for (var doc in docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                sum += (data['rating'] as num?)?.toDouble() ?? 0.0;
                              }
                              average = sum / total;
                            }
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ResenasUsuarioScreen(
                                    userId: widget.ownerId,
                                    role: 'owner',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.green[100],
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  fullName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF263238),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (total > 0)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      average.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      ' ($total)',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (total == 0)
                                                const Text(
                                                  'Nuevo',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          _buildInfoRow(Icons.email_outlined, email),
                                          const SizedBox(height: 4),
                                          _buildInfoRow(Icons.phone_outlined, phone),
                                          const SizedBox(height: 4),
                                          _buildInfoRow(
                                            Icons.location_on_outlined,
                                            address,
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 2. ESTADO DE LA RENTA
                    if (status == 'completed') ...[
                      // ESTADO: FINALIZADO
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5), // Morado suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.purple[800],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Viaje Finalizado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'El propietario ha marcado el viaje como finalizado. Por tu seguridad, los datos del propietario y vehículo se han ocultado.',
                                    style: TextStyle(
                                      color: Colors.purple[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // NUEVO: RECIBO DE PAGO
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.teal.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  color: Colors.teal[800],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recibo de Viaje',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Se asume que finalTotalPay fue calculado al inicio de la pantalla
                            _buildDetailRow(
                              'Pago original (Aprobado al inicio)',
                              '\$$finalTotalPay MXN',
                              color: Colors.teal[800],
                            ),
                            if (paymentMethod == 'Tarjeta' || paymentMethod == 'Tarjeta (Retenido)') ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.teal[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pago con tarjeta liquidado al inicio.',
                                      style: TextStyle(
                                        color: Colors.teal[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (paymentMethod == 'Efectivo') ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.payments, color: Colors.green[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pago en Efectivo (A liquidar en persona)',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else if (status == 'approved') ...[
                      // ADVERTENCIA DE PERMISO PRESENCIAL
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0), // Naranja suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[800],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Importante: Validación Presencial',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'El día acordado debes presentarte con el propietario para que verifique tu licencia y valide tu permiso en la app para poder conducir.',
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'in_progress') ...[
                      // ESTADO: EN USO
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD), // Azul suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: Colors.blue[800],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vehículo En Uso',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Disfruta tu viaje. Recuerda devolver el auto a tiempo y en buen estado.',
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // AGREGAMOS EL WIDGET PARA COMPARTIR UBICACIÓN GPS
                      const SizedBox(height: 16),
                      ArrendatarioRastreoWidget(rentalId: widget.rentalId),
                    ] else if (status == 'rejected') ...[
                      // ESTADO: RECHAZADA
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE), // Rojo suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel,
                              color: Colors.red[800],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Solicitud Rechazada',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lo sentimos, el propietario ha rechazado tu solicitud.',
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'pending') ...[
                      // ESTADO: PENDIENTE
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA), // Gris suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              color: Colors.grey[800],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Solicitud Pendiente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[900],
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Esperando respuesta del propietario.',
                                    style: TextStyle(
                                      color: Colors.grey[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (status != 'completed' && status != 'rejected') ...[
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(
                          'Documentación del Vehículo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF455A64),
                          ),
                        ),
                      ),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _getCarDocuments(autoId),
                        builder: (context, docsSnapshot) {
                          if (docsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final docs = docsSnapshot.data;
                          final tarjetaUrl = docs?['Tarjeta de circulación']?.toString();
                          final verificacionUrl = docs?['Comprobante de verificación vehicular']?.toString();
                          final polizaUrl = docs?['Póliza de seguro']?.toString();

                          final hasAny =
                              (tarjetaUrl != null && tarjetaUrl.isNotEmpty) ||
                              (verificacionUrl != null && verificacionUrl.isNotEmpty) ||
                              (polizaUrl != null && polizaUrl.isNotEmpty);

                          if (!hasAny) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'El propietario aún no ha subido documentos del vehículo.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDocCard(
                                      context,
                                      'Tarjeta de circulación',
                                      Icons.credit_card,
                                      tarjetaUrl,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDocCard(
                                      context,
                                      'Verificación vehicular',
                                      Icons.verified,
                                      verificacionUrl,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDocCard(
                                      context,
                                      'Póliza de seguro',
                                      Icons.security,
                                      polizaUrl,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    if (status == 'completed') ...[
                      const Divider(height: 32, thickness: 1),
                      if (currentRentalData['ownerRating'] == null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Califica tu Viaje',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ayuda a otros usuarios calificando al propietario y su vehículo.',
                                style: TextStyle(color: Colors.amber[900]),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CalificarViajeScreen(
                                          rentalId: widget.rentalId,
                                          targetUserId: widget.ownerId,
                                          role: 'owner',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Ir a calificar'),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Calificaste este viaje con ${currentRentalData['ownerRating']} estrellas',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],

                    // 3. UBICACIÓN DE ENTREGA
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: const Text(
                        'Ubicación de Entrega',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF455A64),
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF263238),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (address != 'No registrada') ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UbicacionAutoScreen(
                                              address: address,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('Ver Ubicación en el Mapa'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1565C0),
                                    side: const BorderSide(
                                      color: Color(0xFF1565C0),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. INFO DEL AUTO Y RENTA
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: const Text(
                        'Detalles del Vehículo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF455A64),
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.directions_car_filled,
                                    color: Colors.blue[800],
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$carBrand $carModel',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Año $carYear',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            _buildDetailRow(
                              'Precio acordado',
                              '\$$price MXN / km',
                            ),
                            if (days > 0) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Días solicitados',
                                '$days ${days == 1 ? "día" : "días"}',
                              ),
                            ],
                            if (estimatedTotal > 0) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Estimado a pagar al finalizar',
                                '\$${estimatedTotal.toStringAsFixed(2)} MXN',
                                color: const Color(0xFF1565C0),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildDetailRow('Método de pago', paymentMethod),
                            const SizedBox(height: 8),
                            _buildDetailRow('Fecha de envío de sol.', dateStr),
                          ],
                        ),
                      ),
                    ),

                    // BOTON CANCELAR VIAJE PARA ARRENDATARIO (Solo pending o approved)
                    if (status == 'pending' || status == 'approved') ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(context, 'cancelled'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          label: const Text(
                            'Cancelar Renta',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF263238),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(
    BuildContext context,
    String label,
    IconData icon,
    String? url,
  ) {
    final bool hasDoc = url != null && url.isNotEmpty;

    return InkWell(
      onTap: () => hasDoc ? _openDocument(context, url, label) : null,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDoc ? Colors.blue[300]! : Colors.grey[300]!,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: hasDoc ? const Color(0xFF1565C0) : Colors.grey,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasDoc ? const Color(0xFF263238) : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
