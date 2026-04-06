import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pdf_viewer_screen.dart';
import 'rastreo_auto_propietario_screen.dart';

class DetalleSolicitudScreen extends StatefulWidget {
  final String rentalId;
  final String tenantId;
  final Map<String, dynamic> rentalData;

  const DetalleSolicitudScreen({
    super.key,
    required this.rentalId,
    required this.tenantId,
    required this.rentalData,
  });

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  Future<Map<String, dynamic>?> _getTenantData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.tenantId)
          .get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting tenant data: $e');
      return null;
    }
  }

  // Simulamos o buscamos los documentos.
  // Nota: Si el usuario arrendatario sube sus documentos en "users/{uid}/documentos/documentos_info",
  // aquí los leeremos.
  Future<Map<String, dynamic>?> _getTenantDocuments() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.tenantId)
          .collection('documentos')
          .doc('documentos_info')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['documents'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting tenant documents: $e');
    }
    return null;
  }

  void _openDocument(BuildContext context, String? url, String title) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento no disponible')));
      return;
    }

    // Navegar a la pantalla de visualización interna
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(url: url, title: title),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String newStatus, {
    double? finalDistance,
    double? pricePerKm,
  }) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus};

      // Si el viaje se finaliza, hacemos el corte para fijar el precio real a cobrar
      if (newStatus == 'completed' &&
          finalDistance != null &&
          pricePerKm != null) {
        final double basePay = finalDistance * pricePerKm;
        final double commission = basePay * 0.20;
        
        updates['finalBasePay'] = basePay;
        updates['finalCommission'] = commission;
        updates['finalTotalPay'] = basePay + commission;
      }

      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.rentalId)
          .update(updates);

      // Actualizar el estado del auto
      final autoId = widget.rentalData['autoId']?.toString() ?? '';
      if (newStatus == 'approved' && autoId.isNotEmpty) {
        // Al aceptar, el auto pasa a estado 'ocupado' para que no salga en las búsquedas
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .update({'status': 'ocupado'})
            .catchError((e) => debugPrint('Error al cambiar status del auto a ocupado: $e'));
      } else if ((newStatus == 'completed' || newStatus == 'rejected' || newStatus == 'cancelled') && autoId.isNotEmpty) {
        // Al terminar, rechazar o cancelar, el auto vuelve a estar 'registrado' (disponible)
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .update({'status': 'registrado'})
            .catchError((e) => debugPrint('Error al cambiar status del auto a registrado: $e'));
      }

      if (!context.mounted) return;
      
      String message;
        Color color;

        switch (newStatus) {
          case 'approved':
            message = 'Solicitud aceptada. Esperando entrega.';
            color = Colors.green;
            break;
          case 'rejected':
            message = 'Solicitud rechazada';
            color = Colors.red;
            break;
          case 'in_progress':
            message = '¡Renta iniciada! Vehículo en uso.';
            color = Colors.blue;
            break;
          case 'completed':
            message = 'Viaje finalizado correctamente. GPS detenido.';
            color = Colors.purple;
            break;
          default:
            message = 'Estado actualizado';
            color = Colors.grey;
        }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );

      // Return to the list ONLY if rejected or completed to clean up the flow,
      // otherwise they stay here to see the next available actions.
      if (newStatus == 'rejected' || newStatus == 'completed') {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeliveryAndStartRental(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Entrega y Permiso'),
        content: const Text(
          'Al continuar, confirmas que:\n\n'
          '✅ Has verificado físicamente la licencia del arrendatario.\n'
          '✅ Has entregado el vehículo.\n'
          '✅ Otorgas permiso explícito para manejar.\n\n'
          'La renta pasará a estado "En Uso".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text(
              'Confirmar e Iniciar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      _updateStatus(context, 'in_progress');
    }
  }

  Future<void> _confirmEndRental(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Viaje y Detener GPS'),
        content: const Text(
          '¿Estás seguro de que deseas finalizar este viaje?\n\n'
          '✅ Esto detendrá automáticamente la transmisión GPS del arrendatario.\n'
          '✅ El viaje pasará a estado "Finalizada".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sí, Finalizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final docData = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.rentalId)
          .get();
          
      final double distance =
          (docData.data()?['distanciaRecorridaKm'] ?? 0).toDouble();
      final double price =
          (docData.data()?['pricePerKm'] ?? docData.data()?['price'] ?? 0)
              .toDouble();

      _updateStatus(
        context,
        'completed',
        finalDistance: distance,
        pricePerKm: price,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.rentalId)
          .snapshots(),
      builder: (context, rentalSnapshot) {
        if (rentalSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentRentalData =
            rentalSnapshot.data?.data() as Map<String, dynamic>? ??
            widget.rentalData;
        final status = currentRentalData['status'] ?? 'pending';

        final carBrand =
            currentRentalData['carBrand'] ??
            widget.rentalData['carBrand'] ??
            '';
        final carModel =
            currentRentalData['carModel'] ??
            widget.rentalData['carModel'] ??
            '';
        final carYear =
            currentRentalData['carYear'] ?? widget.rentalData['carYear'] ?? '';
        final price =
            currentRentalData['pricePerKm'] ??
            currentRentalData['pricePerDay'] ??
            widget.rentalData['pricePerKm'] ??
            widget.rentalData['pricePerDay'] ??
            0;

        // Nuevos campos de estimado de renta
        final paymentMethod =
            currentRentalData['paymentMethod'] ??
            widget.rentalData['paymentMethod'] ??
            'No especificado';
        final startDateStr =
            currentRentalData['startDate'] ?? widget.rentalData['startDate'];
        final endDateStr =
            currentRentalData['endDate'] ?? widget.rentalData['endDate'];
        final estimatedTotalData =
            currentRentalData['estimatedTotal'] ??
            widget.rentalData['estimatedTotal'];
        final double estimatedTotal = estimatedTotalData != null
            ? (estimatedTotalData as num).toDouble()
            : 0.0;

        final double distanciaFinal =
            (currentRentalData['distanciaRecorridaKm'] ?? 0).toDouble();
            
        final double finalBasePay =
            (currentRentalData['finalBasePay'] ?? (distanciaFinal * price)).toDouble();
        final double finalCommission =
            (currentRentalData['finalCommission'] ?? (finalBasePay * 0.20)).toDouble();
        // Forzar suma correcta en UI en caso de ser un viaje de prueba pasado y tenga "finalTotalPay" con valores viejos
        final double finalTotalPay = finalBasePay + finalCommission;

        int days = 0;
        if (startDateStr != null && endDateStr != null) {
          try {
            final start = DateTime.parse(startDateStr);
            final end = DateTime.parse(endDateStr);
            days = end.difference(start).inDays + 1;
          } catch (_) {}
        }

        // Safety check for timestamp
        final rawDate =
            currentRentalData['createdAt'] ?? widget.rentalData['createdAt'];
        Timestamp? timestamp;
        if (rawDate is Timestamp) {
          timestamp = rawDate;
        }

        final dateStr = timestamp != null
            ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
            : "N/A";

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Detalle de Solicitud'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1565C0),
            elevation: 0,
          ),
          body: FutureBuilder<Map<String, dynamic>?>(
            future: _getTenantData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data ?? {};
              final fullName = userData['fullName'] ?? 'Usuario desconocido';
              final email = userData['email'] ?? 'No disponible';
              final phone = userData['phone'] ?? 'No registrado';

              String address = 'No registrada';
              if (userData['address'] != null && userData['address'] is Map) {
                final addr = userData['address'] as Map;
                address =
                    '${addr['calle'] ?? ''} ${addr['numero'] ?? ''}, ${addr['colonia'] ?? ''}';
                if (addr['municipio'] != null)
                  address += ', ${addr['municipio']}';
                if (addr['estado'] != null) address += ', ${addr['estado']}';
              }

              // Extraer inicial
              final initial = fullName.isNotEmpty
                  ? fullName[0].toUpperCase()
                  : '?';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER: INFO DEL SOLICITANTE
                    _buildSectionTitle('Solicitante'),
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
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
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

                    // 2. INFO DEL AUTO Y RENTA
                    _buildSectionTitle('Detalles de la Renta'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Vehículo',
                              '$carBrand $carModel $carYear',
                            ),
                            const Divider(),
                            _buildDetailRow('Precio por km', '\$$price MXN'),
                            if (days > 0) ...[
                              const Divider(),
                              _buildDetailRow(
                                'Días solicitados',
                                '$days ${days == 1 ? "día" : "días"}',
                              ),
                            ],
                            if (estimatedTotal > 0) ...[
                              const Divider(),
                              _buildDetailRow(
                                'Estimado a pagar al finalizar',
                                '\$${estimatedTotal.toStringAsFixed(2)} MXN',
                                color: const Color(0xFF1565C0),
                              ),
                            ],
                            const Divider(),
                            _buildDetailRow('Método de pago', paymentMethod),
                            const Divider(),
                            _buildDetailRow('Fecha de envío de sol.', dateStr),
                            const Divider(),
                            _buildDetailRow(
                              'Estado actual',
                              _translateStatus(status),
                              color: _getStatusColor(status),
                            ),
                            if (status == 'completed') ...[
                              const Divider(height: 32),
                              const Text(
                                'Liquidación del Viaje',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Distancia real',
                                '${distanciaFinal.toStringAsFixed(2)} km',
                              ),
                              _buildDetailRow(
                                'Subtotal (Tu ganancia)',
                                '\$${finalBasePay.toStringAsFixed(2)} MXN',
                                color: Colors.green[700],
                              ),
                              _buildDetailRow(
                                'Comisión AutoAmigo (20%)',
                                '\$${finalCommission.toStringAsFixed(2)} MXN',
                                color: Colors.red[700],
                              ),
                              const Divider(),
                              _buildDetailRow(
                                'Cobro total al cliente',
                                '\$${finalTotalPay.toStringAsFixed(2)} MXN',
                                color: const Color(0xFF1565C0),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. DOCUMENTACIÓN DEL USUARIO (FETCHING)
                    _buildSectionTitle('Documentación del Usuario'),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getTenantDocuments(),
                      builder: (context, docSnapshot) {
                        if (docSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final docs = docSnapshot.data;
                        final ineUrl = docs?['INE / IFE'];
                        final licenciaUrl = docs?['Licencia'];
                        final comprobanteUrl = docs?['Comprobante'];

                        final hasAny =
                            (ineUrl != null) ||
                            (licenciaUrl != null) ||
                            (comprobanteUrl != null);

                        if (docs == null && !hasAny) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'El usuario no ha subido documentos aún.',
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
                                    'INE / IFE',
                                    Icons.credit_card,
                                    ineUrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDocCard(
                                    context,
                                    'Licencia',
                                    Icons.directions_car,
                                    licenciaUrl,
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
                                    'Comprobante',
                                    Icons.home_work_outlined,
                                    comprobanteUrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: SizedBox()), // Spacer
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
          bottomNavigationBar:
              (status == 'pending' ||
                  status == 'approved' ||
                  status == 'in_progress')
              ? _buildActionButtons(context, status)
              : null,
        );
      },
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
                  size: 32,
                  color: hasDoc ? const Color(0xFF1565C0) : Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: hasDoc ? const Color(0xFF1565C0) : Colors.grey[500],
                    fontWeight: FontWeight.w500,
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
                ), // Icono de ojo (ver)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    if (status == 'in_progress') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final carBrand = widget.rentalData['carBrand'] ?? '';
                    final carModel = widget.rentalData['carModel'] ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RastreoAutoPropietarioScreen(
                          rentalId: widget.rentalId,
                          carDetails: '$carBrand $carModel',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.my_location, color: Colors.white),
                  label: const Text(
                    'Rastrear Auto en Vivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmEndRental(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Finalizar Viaje y Detener GPS',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          // Asegurar padding en dispositivos con notch
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDeliveryAndStartRental(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.vpn_key_outlined, color: Colors.white),
              label: const Text(
                'Confirmar Entrega y Permiso',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Default: Pending status -> Approve/Reject
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateStatus(context, 'rejected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateStatus(context, 'approved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Aceptar Solicitud',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF455A64),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  String _translateStatus(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En uso';
      case 'completed':
        return 'Finalizada';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
