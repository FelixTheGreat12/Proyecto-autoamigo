import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// Tracker global para mantener viva la conexión aunque salgamos de la pantalla
class RentalLocationTracker {
  static final Map<String, StreamSubscription<Position>> _activeStreams = {};
  static final Map<String, StreamSubscription<DocumentSnapshot>> _statusStreams = {};

  static bool isTracking(String rentalId) => _activeStreams.containsKey(rentalId);

  static void startTracking(String rentalId, StreamSubscription<Position> locationStream) {
    _activeStreams[rentalId] = locationStream;
    
    // Y crear un listener global a la BD para que si el arrendador apaga el viaje,
    // nosotros apaguemos automáticamente nuestro propio stream de ubicación en cualquier momento.
    _statusStreams[rentalId] = FirebaseFirestore.instance
        .collection('rentals')
        .doc(rentalId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'completed') {
          stopTracking(rentalId);
        }
      }
    });
  }

  static void stopTracking(String rentalId) {
    _activeStreams[rentalId]?.cancel();
    _activeStreams.remove(rentalId);

    _statusStreams[rentalId]?.cancel();
    _statusStreams.remove(rentalId);
  }
}

class ArrendatarioRastreoWidget extends StatefulWidget {
  final String rentalId;

  const ArrendatarioRastreoWidget({super.key, required this.rentalId});

  @override
  State<ArrendatarioRastreoWidget> createState() => _ArrendatarioRastreoWidgetState();
}

class _ArrendatarioRastreoWidgetState extends State<ArrendatarioRastreoWidget> {
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    // Recupera el estado si ya estábamos rastreando esta renta previa a salir de la pantalla
    _isTracking = RentalLocationTracker.isTracking(widget.rentalId);
  }

  @override
  void dispose() {
    // Ya NO detenemos el rastreo aquí al destruir el widget.
    // Queremos que siga corriendo en memoria aunque salgamos a otra pantalla.
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por motivos de seguridad, solo el arrendador puede detener el viaje.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, activa el GPS en los ajustes de tu celular.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Los permisos de ubicación fueron denegados.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los permisos de ubicación están denegados permanentemente, configúralos en tus ajustes.')),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() => _isTracking = true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualiza solo si se mueve 10 metros
    );

    final stream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      FirebaseFirestore.instance.collection('rentals').doc(widget.rentalId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    });

    RentalLocationTracker.startTracking(widget.rentalId, stream);
  }

  void _stopTracking() {
    RentalLocationTracker.stopTracking(widget.rentalId);
    if (mounted) {
      setState(() => _isTracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isTracking ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isTracking ? Colors.green.shade300 : Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isTracking ? Icons.satellite_alt_rounded : Icons.location_off,
                color: _isTracking ? Colors.green[800] : Colors.orange[800],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isTracking ? 'Transmitiendo ubicación GPS...' : 'Ubicación Pausada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isTracking ? Colors.green[900] : Colors.orange[900],
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isTracking
                ? 'El propietario ahora puede ver el progreso del viaje en vivo. Mantén la aplicación activa (no la cierres forzosamente).'
                : 'Debes iniciar la transmisión de tu viaje por cuestiones de seguridad. Presiona "Iniciar Viaje".',
            style: TextStyle(
              color: _isTracking ? Colors.green[900] : Colors.orange[900],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleTracking,
              icon: Icon(
                _isTracking ? Icons.lock_outline : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              label: Text(
                _isTracking ? 'Viaje en Curso (Bloqueado)' : 'Iniciar Viaje',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.grey[700] : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
