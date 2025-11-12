import 'package:flutter/material.dart';

class CotizarAutoScreen extends StatefulWidget {
  const CotizarAutoScreen({super.key});

  @override
  State<CotizarAutoScreen> createState() => _CotizarAutoScreenState();
}

class _CotizarAutoScreenState extends State<CotizarAutoScreen> {
  String? selectedYear;
  String? selectedBrand;
  String? selectedModel;

  final years = List<String>.generate(30, (i) => '${DateTime.now().year - i}');
  final brands = ['Toyota', 'Honda', 'Nissan', 'Ford'];
  final models = ['Modelo A', 'Modelo B', 'Modelo C'];

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

  Widget _buildCotizarButton() {
    return ElevatedButton(
      onPressed: () {
        // Interfaz solamente: no acción
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interfaz: acción de cotizar (solo UI).')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Cotizar auto'),
    );
  }
}
