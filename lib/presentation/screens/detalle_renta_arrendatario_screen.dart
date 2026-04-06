import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ubicacion_auto_screen.dart';
import 'pdf_viewer_screen.dart';
import 'arrendatario_rastreo_widget.dart';

class DetalleRentaArrendatarioScreen extends StatelessWidget {
  final String rentalId;
  final String ownerId;
  final Map<String, dynamic> rentalData;

  const DetalleRentaArrendatarioScreen({
    super.key,
    required this.rentalId,
    required this.ownerId,
    required this.rentalData,
  });

  // Fetch owner data to display contact info
  Future<Map<String, dynamic>?> _getOwnerData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting owner data: $e');
      return null;
    }
  }

  // Método para abrir URLs
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el archivo: $urlString')),
        );
      }
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
            .doc(rentalId)
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
          // Forzar la suma correcta en la UI para viajes anteriores que se guardaron con la lógica vieja
          final double finalTotalPay = finalBasePay + finalCommission;

          int days = 0;
          if (startDateStr != null && endDateStr != null) {
            try {
              final start = DateTime.parse(startDateStr);
              final end = DateTime.parse(endDateStr);
              days = end.difference(start).inDays + 1;
            } catch (_) {}
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

              String address = 'No registrada';
              if (userData['address'] != null && userData['address'] is Map) {
                final addr = userData['address'] as Map;
                address =
                    '${addr['calle'] ?? ''} ${addr['numero'] ?? ''}, ${addr['colonia'] ?? ''}';
                if (addr['municipio'] != null)
                  address += ', ${addr['municipio']}';
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text(
                          'Datos del Propietario',
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
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF263238),
                                      ),
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
                            _buildDetailRow(
                              'Kilómetros reales',
                              '${distanciaFinal.toStringAsFixed(2)} km',
                            ),
                            _buildDetailRow('Precio por km', '\$$price MXN'),
                            const SizedBox(height: 4),
                            _buildDetailRow('Subtotal', '\$${finalBasePay.toStringAsFixed(2)} MXN'),
                            _buildDetailRow('Tarifa de servicio (20%)', '\$${finalCommission.toStringAsFixed(2)} MXN'),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Total a Pagar',
                              '\$${finalTotalPay.toStringAsFixed(2)} MXN',
                              color: Colors.teal[800],
                            ),
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
                      ArrendatarioRastreoWidget(rentalId: rentalId),
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

                    const SizedBox(height: 24),

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

                    if ((status == 'approved' || status == 'in_progress') &&
                        rentalData['autoId'] != null) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text(
                          'Documentos del Vehículo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF455A64),
                          ),
                        ),
                      ),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('autos')
                            .doc(rentalData['autoId'])
                            .collection('documentos')
                            .doc('documentos_info')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No hay documentos disponibles para este auto.',
                                ),
                              ),
                            );
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final docs =
                              data?['documents'] as Map<String, dynamic>? ?? {};

                          if (docs.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'El propietario no ha subido documentos.',
                                ),
                              ),
                            );
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final entry = docs.entries.elementAt(index);
                              final key = entry.key;
                              final url = entry.value.toString();

                              IconData icon = Icons.description;
                              if (key.contains('Seguro')) icon = Icons.security;
                              if (key.contains('Circulación'))
                                icon = Icons.credit_card;
                              if (key.contains('Verificación'))
                                icon = Icons.verified;
                              if (key.contains('Foto')) icon = Icons.image;

                              return _buildDocCard(context, key, icon, url);
                            },
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDocument(BuildContext context, String? url, String title) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento no disponible')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(url: url, title: title),
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
                  size: 32,
                  color: hasDoc ? const Color(0xFF1565C0) : Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: hasDoc
                          ? const Color(0xFF1565C0)
                          : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (hasDoc)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.visibility,
                  size: 16,
                  color: Colors.blue[300],
                ),
              ),
          ],
        ),
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
}
