import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class UbicacionAutoScreen extends StatefulWidget {
  final String address;

  const UbicacionAutoScreen({super.key, required this.address});

  @override
  State<UbicacionAutoScreen> createState() => _UbicacionAutoScreenState();
}

class _UbicacionAutoScreenState extends State<UbicacionAutoScreen> {
  LatLng? _targetLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _geocodeAddress();
  }

  Future<BitmapDescriptor> _createCarMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 110.0;

    // Fondo azul circular
    final Paint paint = Paint()..color = const Color(0xFF1565C0); // Azul principal
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, paint);

    // Borde blanco
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, borderPaint);

    // Dibujar el icono de auto de material icons en blanco
    const IconData iconData = Icons.directions_car;
    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.6,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _geocodeAddress() async {
    try {
      // Intentar obtener las coordenadas de la dirección
      List<Location> locations = await locationFromAddress(widget.address);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        
        // Creamos el ícono del auto dinámicamente antes de agregar el marcador
        BitmapDescriptor carMarkerIcon = await _createCarMarker();
        
        setState(() {
          _targetLocation = LatLng(loc.latitude, loc.longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('car_location'),
              position: _targetLocation!,
              infoWindow: const InfoWindow(title: 'Punto de entrega'),
              icon: carMarkerIcon, // Se asigna el icono generado
            ),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No se encontraron coordenadas para esta dirección.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No pudimos localizar la dirección en el mapa.';
        _isLoading = false;
      });
      debugPrint('Error de Geocoding: $e');
    }
  }

  Future<void> _launchExternalMap(BuildContext context) async {
    final urlText =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}';
    final Uri url = Uri.parse(urlText);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el mapa: $urlText')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Punto de Entrega'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------
          // MAPA INTERACTIVO (GOOGLE MAPS)
          // ---------------------------------------------------------
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _targetLocation != null
                  ? Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _targetLocation!,
                            zoom:
                                16.0, // Zoom suficientemente cerca para ver las calles
                          ),
                          markers: _markers,
                          onMapCreated: (controller) =>
                              _mapController = controller,
                          myLocationEnabled: true,
                          zoomControlsEnabled:
                              false, // Usaremos nuestros propios botones
                          mapToolbarEnabled: false,
                        ),
                        Positioned(
                          right: 10,
                          bottom: 30,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    _mapController?.animateCamera(
                                      CameraUpdate.zoomIn(),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    _mapController?.animateCamera(
                                      CameraUpdate.zoomOut(),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.remove,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 60,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // ---------------------------------------------------------
          // DETALLES DE LA DIRECCIÓN
          // ---------------------------------------------------------
          Container(
            padding: const EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: 30,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dirección del Propietario',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),

                // Tarjeta de dirección
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.home_work_outlined,
                          color: Colors.blue[800],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF263238),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botón de indicaciones paso a paso
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchExternalMap(context),
                    icon: const Icon(
                      Icons.directions,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Conducir hacia ahí',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
