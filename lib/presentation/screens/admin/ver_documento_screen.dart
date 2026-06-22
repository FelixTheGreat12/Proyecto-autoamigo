import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class VerDocumentoScreen extends StatelessWidget {
  final String title;
  final String url;

  const VerDocumentoScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    // Revisamos si la URL base (sin los parámetros de Firebase) termina en .pdf
    final bool isPdf = url.split('?').first.toLowerCase().endsWith('.pdf');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: isPdf
          ? SfPdfViewer.network(url)
          : InteractiveViewer(
              maxScale: 5.0,
              minScale: 0.5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('No se pudo cargar la imagen del documento.'),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
