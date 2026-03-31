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

  Future<void> _solicitarRenta(BuildContext context, DateTime startDate, DateTime endDate, double total) async {
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
        'totalPrice': total,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
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
        Navigator.pop(context); // Cerrar el bottomsheet de checkout
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading si falla
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar renta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPriceRow(String label, String value, {bool isFee = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isFee ? Colors.grey[700] : Colors.black87,
              ),
            ),
            if (isFee) ...[
              const SizedBox(width: 6),
              Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isFee ? Colors.grey[700] : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _mostrarCheckoutFront(BuildContext context) async {
    // 1. Mostrar selector de fechas
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona las fechas de renta',
      cancelText: 'CERRAR',
      confirmText: 'CONTINUAR',
      saveText: 'LISTO',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return; // El usuario canceló la selección de fechas

    // 2. Calcular días y costos
    final int days = picked.end.difference(picked.start).inDays + 1; // +1 si rentar hoy y devolver hoy es 1 día
    final double subtotal = (price * days).toDouble();
    final double serviceFee = subtotal * 0.10; // 10% de tarifa de servicio
    final double total = subtotal + serviceFee;
    
    // Función auxiliar para meses
    String obtenerMes(int mes) {
      const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return meses[mes - 1];
    }

    // 3. Mostrar BottomSheet interactivo como Checkout
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).padding.bottom + 24, // Área segura inferior
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Manija superior
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Título y Cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confirma tu renta',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263238),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Fechas en tarjetas llamativas
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.blue[800]),
                              const SizedBox(width: 8),
                              Text('ENTREGA', style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${picked.start.day} ${obtenerMes(picked.start.month)} ${picked.start.year}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_available, size: 16, color: Colors.blue[800]),
                              const SizedBox(width: 8),
                              Text('DEVOLUCIÓN', style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${picked.end.day} ${obtenerMes(picked.end.month)} ${picked.end.year}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Desglose de pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
              ),
              const SizedBox(height: 16),

              // Desglose de precios
              _buildPriceRow(
                'Tarifa base (\$$price x $days ${days == 1 ? "día" : "días"})',
                '\$${subtotal.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              _buildPriceRow(
                'Tarifa de servicio',
                '\$${serviceFee.toStringAsFixed(2)}',
                isFee: true,
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total (MXN)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    '\$${total.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _solicitarRenta(context, picked.start, picked.end, total),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Confirmar y Solicitar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                onPressed: () => _mostrarCheckoutFront(context),
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
