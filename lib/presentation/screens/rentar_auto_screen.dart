import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/car_image_loader.dart';

class RentarAutoScreen extends StatelessWidget {
  final String autoId;
  final Map<String, dynamic> carData;
  final int price;

  const RentarAutoScreen({
    super.key,
    required this.autoId,
    required this.carData,
    required this.price,
  });


  // Obtiene datos del dueño
  Future<Map<String, dynamic>?> _getOwnerData() async {
    try {
      final ownerId = carData['userId'] as String?;
      if (ownerId == null) return null;

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

  Future<void> _solicitarRenta(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para rentar')),
      );
      return;
    }

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Crear solicitud en Firestore
      await FirebaseFirestore.instance.collection('rentals').add({
        'autoId': autoId,
        'tenantId': user.uid,
        'ownerId': carData['userId'],
        'status': 'pending', // pending, approved, rejected, completed
        'createdAt': FieldValue.serverTimestamp(),
        'pricePerDay': price,
        'carBrand': carData['brand'],
        'carModel': carData['model'],
        'carYear': carData['year'],
        'carColor': carData['color'],
      });

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de renta enviada con éxito'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Regresar al Home
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Cerrar loading si falla
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar renta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = carData['brand'] ?? 'N/A';
    final model = carData['model'] ?? 'N/A';
    final year = carData['year'] ?? 'N/A';
    final color = carData['color'] ?? 'N/A';
    final transmission = carData['transmission'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // 1. GALERÍA DE IMÁGENES (CARRUSEL)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Stack(
              children: [
                PageView(
                  children: [
                    // Imagen Real del auto
                    CarImageLoader(
                      autoId: autoId,
                      fit: BoxFit.cover,
                    ),
                    // Imágenes de ejemplo (Vacías por ahora)
                    Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Vista Interior', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Vista Lateral', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Vista Trasera', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Indicador de "Varias fotos"
                Positioned(
                  bottom: 40, // Justo encima del contenido blanco que empieza en top:220 (250 - 40 = 210 visualmente)
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.photo_camera, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '1/4', // Estático por ahora
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Gradiente oscuro para que se vean los iconos blancos
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Botón de regreso
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. CONTENIDO SCROLLABLE CON TARJETA FLOTANTE
          Positioned.fill(
            top: 220, // Subido de 280
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TÍTULO Y PRECIO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$brand $model',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF263238),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  year.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$$price',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            Text(
                              'MXN / día',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // PERFIL DEL DUEÑO
                    const Text(
                      'Propietario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getOwnerData(),
                      builder: (context, snapshot) {
                        final ownerData = snapshot.data;
                        // Corrección: Usar 'fullName' que es como se guarda en el registro
                        final fullName = ownerData?['fullName'] as String? ?? 'Usuario AutoAmigo';
                        
                        // Rating simulado para la demo
                        const rating = 4.8;
                        const reviews = 124;

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildOwnerSkeleton();
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar Owner
                              Container(
                                height: 60,
                                width: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue[100],
                                  image: const DecorationImage(
                                    // Placeholder image de perfil
                                    image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified, size: 16, color: Colors.blue),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Info Owner
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isNotEmpty ? fullName : 'Cargando...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF263238),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 16, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$rating',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          ' ($reviews reseñas)',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // CARACTERÍSTICAS GRID
                    const Text(
                      'Características del Auto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.0, 
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFeatureCard(Icons.calendar_today, 'Año', year.toString()),
                        _buildFeatureCard(Icons.speed, 'Transmisión', transmission),
                        _buildFeatureCard(Icons.palette_outlined, 'Color', color),
                        _buildFeatureCard(Icons.local_gas_station_outlined, 'Combustible', 'Gasolina'),
                      ],
                    ),

                    const SizedBox(height: 32),
                    
                    // DESCRIPCIÓN 
                    const Text(
                      'Descripción del Propietario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este auto se encuentra en excelentes condiciones mecánicas y estéticas. Ideal para viajes largos o uso diario en la ciudad. Cuenta con seguro vigente y todos los servicios al día.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                  ],
                ),
              ),
            ),
          ),

          // BOTÓN FLOTANTE INFERIOR
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => _solicitarRenta(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Solicitar Renta ahora',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 16, color: Colors.grey[200]),
              const SizedBox(height: 8),
              Container(width: 80, height: 14, color: Colors.grey[200]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA), // Gris muy muy claro
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 24),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
