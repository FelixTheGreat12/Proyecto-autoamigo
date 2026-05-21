import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RastreoAutoPropietarioScreen extends StatefulWidget {
  final String rentalId;
  final String carDetails;

  const RastreoAutoPropietarioScreen({
    super.key,
    required this.rentalId,
    this.carDetails = 'Auto en curso',
  });

  @override
  State<RastreoAutoPropietarioScreen> createState() =>
      _RastreoAutoPropietarioScreenState();
}

class _RastreoAutoPropietarioScreenState
    extends State<RastreoAutoPropietarioScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rastreando: ${widget.carDetails}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // 1. Nos suscribimos al documento específico de la renta en tiempo real
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .doc(widget.rentalId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Datos de renta no encontrados.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // Extraer precio por KM y distancia guardada (si existe)
          final double pricePerKm = (data['pricePerKm'] ?? data['price'] ?? 0).toDouble();
          final double distancia = (data['distanciaRecorridaKm'] ?? 0).toDouble();
          
          // Recuperar kmLimit para calcular el límite de 500km
          final double kmLimit = (data['kmLimit'] ?? 500).toDouble();
          final double kmOverage = distancia > kmLimit ? distancia - kmLimit : 0;
          final double extraKmCharge = kmOverage * pricePerKm;
          
          final double gananciaAcumulada = distancia * pricePerKm;

          // 2. Leemos la ubicación actual subida por el arrendatario
          final GeoPoint? location = data['currentLocation'];

          if (location == null) {
            return Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_searching,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Esperando conexión GPS del arrendatario...',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El mapa aparecerá cuando inicie su viaje.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. Transformamos de Firestore GeoPoint a Google Maps LatLng
          final LatLng position = LatLng(location.latitude, location.longitude);

          // 4. Si el mapa ya cargó, animamos la cámara a la nueva posición para dar fluidez al rastreo
          if (_mapController != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController?.animateCamera(CameraUpdate.newLatLng(position));
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 16.5, // Zoom cercano
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: {
                  Marker(
                    markerId: const MarkerId('car_location'),
                    position: position,
                    // Icono color azul, podemos usar un Asset de un coche luego si quieres
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                    infoWindow: const InfoWindow(
                      title: 'Ubicación del vehículo',
                    ),
                  ),
                },
                mapToolbarEnabled: false,
                zoomControlsEnabled:
                    false, // Usaremos nuestros botones personalizados
              ),

              // Tarjeta superior flotante de estado
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.satellite_alt_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Señal GPS Activa en Tiempo Real',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (distancia > 0) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Distancia recorrida',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${distancia.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF263238),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Ganancia / Cobro',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '\$${gananciaAcumulada.toStringAsFixed(2)} MXN',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (kmLimit > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kmOverage > 0 ? Colors.red[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: kmOverage > 0 ? Colors.red[200]! : Colors.blue[200]!,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Límite de KM:',
                                        style: TextStyle(
                                          color: kmOverage > 0 ? Colors.red[900] : Colors.blue[900],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${kmLimit.toStringAsFixed(2)} km',
                                        style: TextStyle(
                                          color: kmOverage > 0 ? Colors.red[900] : Colors.blue[900],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (kmOverage > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Exceso:',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${kmOverage.toStringAsFixed(2)} km',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Cargo Extra:',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '\$${extraKmCharge.toStringAsFixed(2)} MXN',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Botones de Zoom Personalizados
              Positioned(
                right: 16,
                bottom: 30,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _mapController?.animateCamera(
                          CameraUpdate.zoomIn(),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.add, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _mapController?.animateCamera(
                          CameraUpdate.zoomOut(),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.remove, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
