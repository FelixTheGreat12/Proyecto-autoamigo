import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PDFViewerScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    // Detectar si es una imagen simple por la extensión
    final isImage =
        url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        // Sin botones de descarga
      ),
      body: isImage
          ? InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            )
          : SfPdfViewer.network(
              url,
              enableTextSelection: false,
              canShowScrollHead: false,
              pageLayoutMode: PdfPageLayoutMode.continuous,
            ),
    );
  }
}
