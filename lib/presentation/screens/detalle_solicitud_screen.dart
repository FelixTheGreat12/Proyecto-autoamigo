import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.tenantId).get();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento no disponible')),
      );
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

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.rentalId)
          .update({'status': newStatus});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' ? 'Solicitud aceptada' : 'Solicitud rechazada'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context); // Regresar a la lista
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.rentalData['status'] ?? 'pending';
    final carBrand = widget.rentalData['carBrand'] ?? '';
    final carModel = widget.rentalData['carModel'] ?? '';
    final carYear = widget.rentalData['carYear'] ?? '';
    final price = widget.rentalData['pricePerDay'] ?? 0;
    
    // Safety check for timestamp
    final rawDate = widget.rentalData['createdAt'];
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
            address = '${addr['calle'] ?? ''} ${addr['numero'] ?? ''}, ${addr['colonia'] ?? ''}';
            if (addr['municipio'] != null) address += ', ${addr['municipio']}';
            if (addr['estado'] != null) address += ', ${addr['estado']}';
          } 

          // Extraer inicial
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER: INFO DEL SOLICITANTE
                _buildSectionTitle('Solicitante'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                _buildSectionTitle('Detalles de la Renta'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDetailRow('Vehículo', '$carBrand $carModel $carYear'),
                        const Divider(),
                        _buildDetailRow('Precio por día', '\$$price MXN'),
                        const Divider(),
                        _buildDetailRow('Fecha solicitud', dateStr),
                        const Divider(),
                        _buildDetailRow('Estado actual', _translateStatus(status), 
                          color: _getStatusColor(status)),
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
                    if (docSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    
                    final docs = docSnapshot.data;
                    final ineUrl = docs?['INE / IFE'];
                    final licenciaUrl = docs?['Licencia'];
                    final comprobanteUrl = docs?['Comprobante'];
                    
                    final hasAny = (ineUrl != null) || (licenciaUrl != null) || (comprobanteUrl != null);

                    if (docs == null && !hasAny) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.grey),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('El usuario no ha subido documentos aún.', style: TextStyle(color: Colors.grey))),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDocCard(context, 'INE / IFE', Icons.credit_card, ineUrl)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDocCard(context, 'Licencia', Icons.directions_car, licenciaUrl)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildDocCard(context, 'Comprobante', Icons.home_work_outlined, comprobanteUrl)),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()), // Spacer
                          ],
                        ),
                      ],
                    );
                  }
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: status == 'pending' ? _buildActionButtons(context) : null,
    );
  }

  Widget _buildDocCard(BuildContext context, String label, IconData icon, String? url) {

    final bool hasDoc = url != null && url.isNotEmpty;

    return InkWell(
      onTap: () => hasDoc ? _openDocument(context, url, label) : null,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasDoc ? Colors.blue[300]! : Colors.grey[300]!),
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
                child: Icon(Icons.visibility, size: 16, color: Colors.blue[300]), // Icono de ojo (ver)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Aceptar Solicitud', style: TextStyle(color: Colors.white)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
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
      case 'approved': return 'Aprobada';
      case 'rejected': return 'Rechazada';
      case 'pending': return 'Pendiente';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DE VISOR DE PDF INTERNO (Sin opción obvia de descarga)
// ---------------------------------------------------------------------------
class PDFViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PDFViewerScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    // Detectar si es una imagen simple por la extensión (opcional, para robustez)
    final isImage = url.toLowerCase().contains('.jpg') || 
                    url.toLowerCase().contains('.jpeg') || 
                    url.toLowerCase().contains('.png');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        // No agregamos actions aquí, por lo que no hay botón "Share" ni "Download" en la AppBar
      ),
      body: isImage
          ? Center(child: Image.network(url)) // Si es imagen, la muestra
          : SfPdfViewer.network(
              url,
              // Deshabilitamos interacciones que puedan facilitar la extracción
              enableTextSelection: false, 
              canShowScrollHead: false,
              pageLayoutMode: PdfPageLayoutMode.continuous,
            ),
    );
  }
}
