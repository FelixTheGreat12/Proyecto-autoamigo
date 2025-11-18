import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CotizarAutoScreen extends StatefulWidget {
  const CotizarAutoScreen({super.key});

  @override
  State<CotizarAutoScreen> createState() => _CotizarAutoScreenState();
}

class _CotizarAutoScreenState extends State<CotizarAutoScreen> {
  String? selectedYear;
  String? selectedBrand;
  String? selectedModel;
  // Años limitados 2024..2016
  final years = List<String>.generate(9, (i) => '${2024 - i}');

  // Marcas y modelos predefinidos
  final Map<String, List<String>> brandsWithModels = {
    'Nissan': ['March', 'Versa', 'Sentra'],
    'Volkswagen': ['Jetta', 'Vento', 'Gol'],
    'Kia': ['Picanto', 'Rio', 'K3'],
    'Chevrolet': ['Spark', 'Beat', 'Aveo'],
    'Hyundai': ['Grand i10', 'Accent', 'i10', 'i20'],
    'Ford': ['Figo', 'Fiesta', 'Focus'],
    'Toyota': ['Yaris', 'Corolla', 'Avanza'],
    'Honda': ['City', 'Civic', 'Fit'],
  };

  List<String> get brands => brandsWithModels.keys.toList();

  List<String> get models {
    if (selectedBrand == null) return [];
    return brandsWithModels[selectedBrand] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizar Auto'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Cotiza y vende tu auto al mejor precio',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Encuentra las mejores ofertas para vender tu usado de manera rápida, fácil y segura.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // Form row: Año | Marca | Modelo | Button
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              if (isNarrow) {
                // Column layout for narrow screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDropdownYear(),
                    const SizedBox(height: 12),
                    _buildDropdownBrand(),
                    const SizedBox(height: 12),
                    _buildDropdownModel(),
                    const SizedBox(height: 16),
                    _buildCotizarButton(),
                  ],
                );
              }

              // Row layout for wide screens
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDropdownYear()),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _buildDropdownBrand()),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _buildDropdownModel()),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: _buildCotizarButton()),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownYear() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Año',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedYear,
          hint: const Text('Año'),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
          onChanged: (v) => setState(() => selectedYear = v),
        ),
      ),
    );
  }

  Widget _buildDropdownBrand() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Marca',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedBrand,
          hint: const Text('Marca'),
          items: brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (v) => setState(() {
            selectedBrand = v;
            // reset model when brand changes (interface only)
            selectedModel = null;
          }),
        ),
      ),
    );
  }

  Widget _buildDropdownModel() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Modelo',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedModel,
          hint: const Text('Modelo'),
          items: models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => selectedModel = v),
        ),
      ),
    );
  }

  Future<void> _saveCotizacionToFirebase() async {
    // Validar que todos los campos estén completos
    if (selectedYear == null || selectedBrand == null || selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Obtener ID del usuario actual
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    try {
      // Guardar cotización en Firestore
      await FirebaseFirestore.instance.collection('autos').add({
        'year': selectedYear,
        'brand': selectedBrand,
        'model': selectedModel,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'cotizado',
      });

      // Navegar a la pantalla de documentos
      Navigator.pushNamed(context, '/documentos_requeridos');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Widget _buildCotizarButton() {
    return ElevatedButton(
      onPressed: _saveCotizacionToFirebase,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Registrar auto'),
    );
  }
}
