import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'rentar_auto_screen.dart';

import '../widgets/car_image_loader.dart';

class BuscarAutoScreen extends StatefulWidget {
  const BuscarAutoScreen({super.key});

  @override
  State<BuscarAutoScreen> createState() => _BuscarAutoScreenState();
}

class _BuscarAutoScreenState extends State<BuscarAutoScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Filtros seleccionados
  String? _selectedBrand;
  RangeValues _priceRange = const RangeValues(0, 2000);
  
  // Ubicación y distancias
  Position? _currentPosition;
  bool _locating = false;
  final Map<String, double> _ownerDistances = {};
  final Map<String, String> _ownerMunicipios = {};
  final Set<String> _fetchingOwners = {};

  final List<String> _brands = [
    'Chevrolet',
    'Nissan',
    'Volkswagen',
    'Toyota',
    'Ford',
    'Honda',
    'Kia',
    'Mazda',
  ];

  double _calculateSimulatedPrice(String autoId) {
    final randomHash = autoId.hashCode;
    return (350 + (randomHash % 1650).abs()).toDouble(); // ~ $350 - $2000 MXN en Zacatecas
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _fetchOwnerLocationAsync(String ownerId) async {
    if (_currentPosition == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['address'] != null && data['address'] is Map) {
          final addr = data['address'] as Map;
          String fullAddress = '${addr['calle'] ?? ''} ${addr['numeroExterior'] ?? ''}'.trim();
          if (addr['colonia'] != null) fullAddress += ', ${addr['colonia']}';
          if (addr['municipio'] != null) fullAddress += ', ${addr['municipio']}';
          if (addr['estado'] != null) fullAddress += ', ${addr['estado']}';

          String municipio = addr['municipio']?.toString() ?? 'Desconocido';

          if (fullAddress.isNotEmpty) {
            List<Location> locations = await locationFromAddress(fullAddress);
            if (locations.isNotEmpty) {
              final target = locations.first;
              double distanceMeters = Geolocator.distanceBetween(
                _currentPosition!.latitude, 
                _currentPosition!.longitude, 
                target.latitude, 
                target.longitude
              );
              if (mounted) {
                setState(() {
                  _ownerDistances[ownerId] = distanceMeters / 1000; // km
                  _ownerMunicipios[ownerId] = municipio;
                });
              }
              return;
            }
          }
        }
      }
      
      // Fallback si no hay dirección o no se pudo codificar
      if (mounted) {
        setState(() {
          _ownerDistances[ownerId] = -1; // -1 indica no disponible
          _ownerMunicipios[ownerId] = 'Ubicación oculta';
        });
      }
    } catch (e) {
      debugPrint("Error geocodificando owner $ownerId: $e");
      if (mounted) {
        setState(() {
          _ownerDistances[ownerId] = -1;
          _ownerMunicipios[ownerId] = 'Desconocido';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Mismo fondo que Home
      appBar: AppBar(
        title: const Text(
          'Encuentra tu auto',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1565C0)),
            tooltip: 'Filtros avanzados',
            onPressed: () {
              _showFilterModal(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BARRA DE BÚSQUEDA Y CHIPS
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Campo de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ej. Versa 2020',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // Chips de marcas populares (Scroll horizontal)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _brands.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final brand = _brands[index];
                      final isSelected = _selectedBrand == brand;
                      return ChoiceChip(
                        label: Text(brand),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedBrand = selected ? brand : null;
                          });
                        },
                        selectedColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor: Colors.grey[100],
                        side: BorderSide.none,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. RESULTADOS
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    // Si no hay búsqueda ni filtro de marca, mostrar mensaje "Empieza a buscar"
    if (_searchQuery.isEmpty && _selectedBrand == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Escribe una marca o modelo\npara empezar la búsqueda',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('autos')
          // En vez de filtrar aquí, lo procesaremos localmente o usaremos el where de ambas condiciones
          // where('status', isEqualTo: 'registrado') // <-- Removido para poder mostrar los ocupados
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar datos'));
        }

        final docs = snapshot.data?.docs ?? [];

        // --- FILTRADO LOCAL ---
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          
          // Mostrar solo "registrado" o "ocupado"
          if (status != 'registrado' && status != 'ocupado') return false;

          // Mostrar solo autos con tarifa diaria definida.
          // Esto evita que aparezcan tarjetas con esquema legado por km.
          if (data['pricePerDay'] == null) return false;

          final brand = (data['brand'] ?? '').toString();
          final model = (data['model'] ?? '').toString();

          // Filtro de texto (búsqueda parcial en marca o modelo)
          final matchesSearch =
              _searchQuery.isEmpty ||
              brand.toLowerCase().contains(_searchQuery) ||
              model.toLowerCase().contains(_searchQuery);

          // Filtro de marca (chip seleccionado)
          final matchesBrand =
              _selectedBrand == null ||
              brand.toLowerCase() == _selectedBrand!.toLowerCase();

          // Filtro de precio por día
          double price = 0;
          price = (data['pricePerDay'] as num).toDouble();

          final matchesPrice =
              price >= _priceRange.start && price <= _priceRange.end;

          return matchesSearch && matchesBrand && matchesPrice;
        }).toList();

        // --- ORDENAR POR DISTANCIA Y OBTENER UBICACIONES FALTANTES ---
        if (_currentPosition != null) {
          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final ownerId = data['userId']?.toString();
            if (ownerId != null) {
              if (!_ownerDistances.containsKey(ownerId) && !_fetchingOwners.contains(ownerId)) {
                _fetchingOwners.add(ownerId);
                _fetchOwnerLocationAsync(ownerId);
              }
            }
          }

          filteredDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aOwnerId = aData['userId']?.toString() ?? '';
            final bOwnerId = bData['userId']?.toString() ?? '';

            final aDist = _ownerDistances[aOwnerId] ?? double.infinity;
            final bDist = _ownerDistances[bOwnerId] ?? double.infinity;

            final aVal = aDist < 0 ? double.infinity : aDist;
            final bVal = bDist < 0 ? double.infinity : bDist;

            return aVal.compareTo(bVal);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_rounded,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                Text(
                  'No encontramos autos con esa descripción',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final autoId = doc.id;
            return _buildCarCard(autoId, data);
          },
        );
      },
    );
  }

  // Tarjeta de auto real conectada a datos
  Widget _buildCarCard(String autoId, Map<String, dynamic> data) {
    final brand = data['brand'] ?? 'Marca';
    final model = data['model'] ?? 'Modelo';
    final year = data['year']?.toString() ?? 'N/A';

    // Usaremos el precio real por día, o un fallback ajustado
    double actualPrice = 0;
    if (data['pricePerDay'] != null) {
      actualPrice = (data['pricePerDay'] as num).toDouble();
    } else {
      actualPrice = _calculateSimulatedPrice(autoId) / 100;
    }

    final ownerId = data['userId']?.toString();
    final double? distance = ownerId != null ? _ownerDistances[ownerId] : null;
    final String? municipio = ownerId != null ? _ownerMunicipios[ownerId] : null;
    final bool isOccupied = data['status'] == 'ocupado';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RentarAutoScreen(
              autoId: autoId,
              carData: data,
              pricePerDay: actualPrice.toDouble(),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del auto
            SizedBox(
              height: 150,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CarImageLoader(autoId: autoId, fit: BoxFit.cover),
                    if (isOccupied)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: Text(
                            'OCUPADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '$brand $model',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${actualPrice.toStringAsFixed(2)} / día',
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
                  if (distance != null && distance >= 0 && municipio != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFE53935),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'A ${distance.toStringAsFixed(1)} km de ti ($municipio)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF546E7A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_fetchingOwners.contains(ownerId)) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE53935),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Calculando distancia...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          year,
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['transmission'] ?? 'Estándar',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    RangeValues tempRange = _priceRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // --- FILTRO PRECIO POR DÍA ---
                    const Text(
                      'Rango de Precio Máximo (por día)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF455A64)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${tempRange.start.round()} MXN',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${tempRange.end.round()} MXN',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: tempRange,
                      min: 0,
                      max: 2000,
                      divisions: 20,
                      activeColor: const Color(0xFF1565C0),
                      labels: RangeLabels(
                        '\$${tempRange.start.round()}',
                        '\$${tempRange.end.round()}',
                      ),
                      onChanged: (RangeValues values) {
                        setModalState(() {
                          tempRange = values;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _priceRange = tempRange;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Aplicar filtros',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
