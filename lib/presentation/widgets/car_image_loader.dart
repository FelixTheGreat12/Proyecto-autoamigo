import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarImageLoader extends StatelessWidget {
  final String autoId;
  final double? height;
  final double? width;
  final BoxFit fit;

  const CarImageLoader({
    super.key,
    required this.autoId,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('autos')
          .doc(autoId)
          .collection('documentos')
          .doc('documentos_info')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: height,
              width: width,
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                ),
              ),
            );
        }

        if (snapshot.hasError) {
             return _buildPlaceholder(Icons.broken_image);
        }
        
        String? imageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          // Buscar en el mapa 'documents' o directamente si la estructura cambió
          dynamic documentsData = data['documents'];
          
          if (documentsData is Map) {
             imageUrl = documentsData['Fotos del vehículo'] as String?;
          } else {
             // Fallback por si la estructura no es la esperada
             imageUrl = data['Fotos del vehículo'] as String?;
          }
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: imageUrl,
            height: height,
            width: width,
            fit: fit,
            placeholder: (context, url) => Container(
              height: height,
              width: width,
              color: const Color(0xFFF0F0F0),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => _buildPlaceholder(Icons.broken_image),
            fadeInDuration: const Duration(milliseconds: 300),
          );
        }

        // Si no hay imagen
        return _buildPlaceholder(Icons.directions_car);
      },
    );
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: Center(
        child: Icon(icon, color: Colors.grey[400], size: 40),
      ),
    );
  }
}
