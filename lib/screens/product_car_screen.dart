import 'package:flutter/material.dart';

class ProductCarScreen extends StatelessWidget {
  final String? year;
  final String? brand;
  final String? model;

  const ProductCarScreen({
    super.key,
    this.year,
    this.brand,
    this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product-Car'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del auto (placeholder)
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: Icon(
                Icons.image,
                size: 80,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Marca
            const Text(
              'Marca',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              brand ?? 'N/A',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Modelo
            const Text(
              'Modelo',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              model ?? 'N/A',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Número de placas
            const Text(
              'Número de placas',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              year ?? 'N/A',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),

            // Botón Mis Autos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/mis_autos',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Mis Autos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
