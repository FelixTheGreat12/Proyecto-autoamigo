import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
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
    final status = rentalData['status'] ?? 'pending';
    final carBrand = rentalData['carBrand'] ?? '';
    final carModel = rentalData['carModel'] ?? '';
    final carYear = rentalData['carYear'] ?? '';
    final price = rentalData['pricePerDay'] ?? 0;
    final timestamp = rentalData['createdAt'] as Timestamp?;
    final dateStr = timestamp != null
        ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
        : "N/A";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Detalle de Renta'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0), // Main blue
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getOwnerData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data ?? {};
          final fullName = userData['fullName'] ?? 'Propietario desconocido';
          final email = userData['email'] ?? 'No disponible';
          final phone = userData['phone'] ?? 'No registrado';
          
          String address = 'No registrada';
          if (userData['address'] != null && userData['address'] is Map) {
            final addr = userData['address'] as Map;
            address = '${addr['calle'] ?? ''} ${addr['numero'] ?? ''}, ${addr['colonia'] ?? ''}';
            if (addr['municipio'] != null) address += ', ${addr['municipio']}';
          }

          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              _buildInfoRow(Icons.location_on_outlined, address, maxLines: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // 2. INFO DEL AUTO Y RENTA
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                               child: Icon(Icons.directions_car_filled, color: Colors.blue[800], size: 32),
                             ),
                             const SizedBox(width: 16),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('$carBrand $carModel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                 Text('Año $carYear', style: TextStyle(color: Colors.grey[600])),
                               ],
                             )
                           ],
                         ),
                        const Divider(height: 32),
                        _buildDetailRow('Precio acordado', '\$$price MXN / día'),
                        _buildDetailRow('Fecha solicitud', dateStr),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50], // Light green bg because it's approved
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado: Aprobado',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ponte en contacto con el propietario para acordar la entrega.',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (status == 'approved' && rentalData['autoId'] != null) ...[
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                         return const Card(
                           child: Padding(
                             padding: EdgeInsets.all(16),
                             child: Text('No hay documentos disponibles para este auto.'),
                           ),
                         );
                      }

                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      final docs = data?['documents'] as Map<String, dynamic>? ?? {};

                      if (docs.isEmpty) {
                         return const Card(
                           child: Padding(
                             padding: EdgeInsets.all(16),
                             child: Text('El propietario no ha subido documentos.'),
                           ),
                         );
                      }

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: docs.entries.map((entry) {
                            final key = entry.key;
                            final url = entry.value.toString();

                            IconData icon = Icons.description;
                            if (key.contains('Seguro')) icon = Icons.security;
                            if (key.contains('Circulación')) icon = Icons.credit_card;
                            if (key.contains('Verificación')) icon = Icons.verified;
                            if (key.contains('Foto')) icon = Icons.image;

                            return ListTile(
                              leading: Icon(icon, color: const Color(0xFF1565C0)),
                              title: Text(key, style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: const Icon(Icons.open_in_new, color: Colors.grey),
                              onTap: () => _launchUrl(context, url),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // 3. ACCIONES
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Acción simulada de llamar o contactar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abriendo marcador...')),
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar al Propietario'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Acción simulada de chat
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abriendo chat...')),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Enviar Mensaje'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF263238),
            ),
          ),
        ],
      ),
    );
  }
}
