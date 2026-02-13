import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cotizar_auto_screen.dart'; // Para navegar a editar
import '../../services/file_upload_service.dart'; // Para borrar archivos

class ProductCarScreen extends StatelessWidget {
  final String autoId;
  final Map<String, dynamic> carData;

  const ProductCarScreen({
    super.key,
    required this.autoId,
    required this.carData,
  });

  // Obtiene la URL de la foto del auto desde Firestore
  Future<String?> _getCarImageUrl() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('autos')
          .doc(autoId)
          .collection('documentos')
          .doc('documentos_info')
          .get();

      if (doc.exists && doc.data() != null) {
        final docs = doc.data()!['documents'] as Map<String, dynamic>;
        return docs['Fotos del vehículo'] as String?;
      }
    } catch (e) {
      debugPrint('Error obteniendo imagen: $e');
    }
    return null;
  }

  // Función completa para borrar el auto y sus archivos
  Future<void> _deleteAuto(BuildContext context) async {
    // 1. Confirmación
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("¿Eliminar auto?"),
          content: const Text(
            "Esta acción borrará permanentemente el auto y sus documentos de la nube. ¿Estás seguro?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Sí, eliminar"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Mostrar indicador de carga
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        // A. BORRAR ARCHIVOS DE STORAGE
        final docsSnapshot = await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .collection('documentos')
            .doc('documentos_info')
            .get();

        if (docsSnapshot.exists && docsSnapshot.data() != null) {
          final data = docsSnapshot.data()!;
          if (data['documents'] != null) {
            final docsMap = data['documents'] as Map<String, dynamic>;

            final uploadService = FileUploadService();

            // Borrar cada archivo físico de la nube
            for (var url in docsMap.values) {
              if (url != null && url is String) {
                await uploadService.deleteFileByUrl(url);
              }
            }
          }
        }

        // B. BORRAR REGISTROS DE FIRESTORE
        // Borrar subcolección de documentos
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .collection('documentos')
            .doc('documentos_info')
            .delete();

        // Borrar documento principal del auto
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoId)
            .delete();

        if (context.mounted) {
          Navigator.of(context).pop(); // Cerrar loader

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto eliminado correctamente'),
              backgroundColor: Colors.grey,
            ),
          );

          Navigator.of(context).pop(); // Regresar a la lista
        }
      } catch (e) {
        if (context.mounted)
          Navigator.of(context).pop(); // Cerrar loader si falla

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = carData['brand'] ?? 'N/A';
    final model = carData['model'] ?? 'N/A';
    final year = carData['year'] ?? 'N/A';
    final color = carData['color'] ?? 'N/A';
    final transmission = carData['transmission'] ?? 'N/A';
    final plate = carData['plate'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Detalle del Auto',
            style: TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
            ),
          ),  
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // --- BOTÓN DE BORRAR ---
          TextButton.icon(
            onPressed: () => _deleteAuto(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text(
              'Borrar',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // --- BOTÓN DE EDITAR ---
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CotizarAutoScreen(
                    autoIdToEdit: autoId,
                    existingData: carData,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.edit, color: Color(0xFF1565C0), size: 18),
            label: const Text(
              'Editar',
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con indicador de carga circular
            FutureBuilder<String?>(
              future: _getCarImageUrl(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildImagePlaceholder(isLoading: true);
                }
                final imageUrl = snapshot.data;
                if (imageUrl == null) {
                  return _buildImagePlaceholder(isLoading: false);
                }
                return Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Tarjeta de Información
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información del Vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263238),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.directions_car, 'Marca', brand),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.category, 'Modelo', model),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.calendar_today, 'Año', year),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.palette, 'Color', color),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.settings, 'Transmisión', transmission),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.confirmation_number, 'Placas', plate),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón Volver Inferior
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Volver',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({required bool isLoading}) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Sin imagen disponible',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF1565C0)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
