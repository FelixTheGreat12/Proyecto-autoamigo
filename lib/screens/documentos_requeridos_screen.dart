import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/file_upload_service.dart';

class DocumentosRequeridosScreen extends StatefulWidget {
  const DocumentosRequeridosScreen({super.key});

  @override
  State<DocumentosRequeridosScreen> createState() =>
      _DocumentosRequeridosScreenState();
}

class _DocumentosRequeridosScreenState extends State<DocumentosRequeridosScreen> {
  final FileUploadService _uploadService = FileUploadService();

  // Mapas para guardar archivos seleccionados (en memoria hasta presionar Registrar)
  final Map<String, dynamic> _selectedFiles = {
    'Tarjeta de circulación': null,
    'Carta factura': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  // Mapa para nombres de archivo seleccionados
  final Map<String, String?> _fileNames = {
    'Tarjeta de circulación': null,
    'Carta factura': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  // URLs después de subir a Storage
  final Map<String, String?> _uploadedUrls = {
    'Tarjeta de circulación': null,
    'Carta factura': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  // Track loading state
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos requeridos'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Documentos requeridos',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  _buildDocField('Tarjeta de circulación', format: 'PDF'),
                  const SizedBox(height: 12),
                  _buildDocField('Carta factura', format: 'PDF'),
                  const SizedBox(height: 12),
                  _buildDocField('Comprobante de verificación vehicular',
                      format: 'PDF'),
                  const SizedBox(height: 12),
                  _buildDocField('Póliza de seguro', format: 'PDF'),
                  const SizedBox(height: 12),
                  _buildDocField('Fotos del vehículo', format: 'JPG'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveAllDocuments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Registrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocField(String label, {required String format}) {
    final fileName = _fileNames[label];
    final isSelected = _selectedFiles[label] != null;
    final extensions = format == 'PDF' ? ['pdf'] : ['jpg', 'jpeg', 'png'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            Text('Solo $format',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFile(label, extensions),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? Colors.blue[50] : Colors.white,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.cloud_upload_outlined,
                    size: 56,
                    color: isSelected ? Colors.blue : Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName ?? 'Seleccionar',
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Se subirá al presionar Registrar',
                        style: TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(String documentType, List<String> extensions) async {
    final platformFile = await _uploadService.pickFile(
      allowedExtensions: extensions,
    );

    if (platformFile == null) return;

    setState(() {
      _selectedFiles[documentType] = platformFile;
      _fileNames[documentType] = platformFile.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentType seleccionado: ${platformFile.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAllDocuments() async {
    // Validar que al menos un documento esté seleccionado
    final hasFiles = _selectedFiles.values.any((file) => file != null);
    if (!hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor selecciona al menos un documento')),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Obtener el último auto del usuario
      final autosQuery = await FirebaseFirestore.instance
          .collection('autos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (autosQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No hay auto registrado. Por favor cotiza un auto primero')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final autoId = autosQuery.docs.first.id;

      // Subir todos los archivos seleccionados
      for (final entry in _selectedFiles.entries) {
        final documentType = entry.key;
        final platformFile = entry.value;

        if (platformFile == null) continue;

        String? downloadUrl;
        if (platformFile.path == null) {
          // Usar bytes si path es null
          if (platformFile.bytes != null) {
            downloadUrl = await _uploadService.uploadData(
              data: platformFile.bytes!,
              fileName: platformFile.name,
              documentType: documentType,
            );
          }
        } else {
          // Usar archivo físico
          final file = File(platformFile.path!);
          downloadUrl = await _uploadService.uploadFile(
            file: file,
            fileName: platformFile.name,
            documentType: documentType,
          );
        }

        if (downloadUrl != null) {
          _uploadedUrls[documentType] = downloadUrl;
        }
      }

      // Guardar URLs en Firestore
      await FirebaseFirestore.instance
          .collection('autos')
          .doc(autoId)
          .collection('documentos')
          .doc('documentos_info')
          .set({
        'documents': _uploadedUrls,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documentos guardados exitosamente')),
      );

      // Navegar a product_car
      Navigator.pushNamed(context, '/product_car');
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }
}
