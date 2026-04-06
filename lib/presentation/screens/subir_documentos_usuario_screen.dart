import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Importante para PlatformFile
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/file_upload_service.dart';

class SubirDocumentosUsuarioScreen extends StatefulWidget {
  const SubirDocumentosUsuarioScreen({super.key});

  @override
  State<SubirDocumentosUsuarioScreen> createState() =>
      _SubirDocumentosUsuarioScreenState();
}

class _SubirDocumentosUsuarioScreenState
    extends State<SubirDocumentosUsuarioScreen> {
  final FileUploadService _uploadService = FileUploadService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mapa para trackear archivos seleccionados localmente
  final Map<String, PlatformFile?> _selectedFiles = {
    'INE / IFE': null,
    'Licencia': null,
    'Comprobante': null,
  };

  // Mapa para trackear nombres de archivos seleccionados
  final Map<String, String?> _fileNames = {
    'INE / IFE': null,
    'Licencia': null,
    'Comprobante': null,
  };

  // Mapa para almacenar URLs ya existentes (si venimos a editar)
  Map<String, dynamic> _uploadedUrls = {};

  bool _isLoadingInitialData = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  Future<void> _loadExistingDocuments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documentos')
          .doc('documentos_info')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['documents'] != null) {
          setState(() {
            _uploadedUrls = Map<String, dynamic>.from(data['documents']);
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando documentos existentes: $e");
    } finally {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _pickFile(String documentType) async {
    final extensions = ['jpg', 'png', 'jpeg', 'pdf'];

    // Asumimos que pickFile devuelve un PlatformFile o similar del upload_service
    // Nota: Si FileUploadService usa file_picker, devuelve PlatformFile.
    // Revisar la implementación de FileUploadService en tu proyecto si falla.
    final platformFile = await _uploadService.pickFile(
      allowedExtensions: extensions,
    );

    if (platformFile == null) return;

    setState(() {
      _selectedFiles[documentType] = platformFile;
      _fileNames[documentType] = platformFile.name;
    });
  }

  Future<void> _saveDocuments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Validar que tengamos al menos un documento o existente
    bool hasAny = false;
    for (var key in _selectedFiles.keys) {
      if (_selectedFiles[key] != null ||
          (_uploadedUrls[key] != null && _uploadedUrls[key] != '')) {
        hasAny = true;
        break;
      }
    }

    if (!hasAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor sube al menos un documento')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Subir archivos nuevos
      for (final entry in _selectedFiles.entries) {
        final docType = entry.key;
        final platformFile = entry.value;

        if (platformFile == null) continue;

        // Subir a Storage
        String? downloadUrl;

        // Dependiendo de si es Web o Mobile (bytes vs path)
        if (platformFile.bytes != null) {
          downloadUrl = await _uploadService.uploadData(
            data: platformFile.bytes!,
            fileName: platformFile.name,
            documentType: 'users/${user.uid}/$docType', // Ruta personalizada
          );
        } else if (platformFile.path != null) {
          final file = File(platformFile.path!);
          downloadUrl = await _uploadService.uploadFile(
            file: file,
            fileName: platformFile.name,
            documentType: 'users/${user.uid}/$docType', // Ruta personalizada
          );
        }

        if (downloadUrl != null) {
          // Si había uno viejo, idealmente lo borramos, pero por ahora sobrescribimos URL
          _uploadedUrls[docType] = downloadUrl;
        }
      }

      // Guardar mapa de URLs en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documentos')
          .doc('documentos_info')
          .set({
            'documents': _uploadedUrls,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documentos guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error subiendo documentos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Documentos'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sube tus documentos para validar tu identidad y poder rentar autos.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  _buildUploadCard('INE / IFE', Icons.credit_card),
                  const SizedBox(height: 16),
                  _buildUploadCard('Licencia', Icons.directions_car),
                  const SizedBox(height: 16),
                  _buildUploadCard(
                    'Comprobante',
                    Icons.home_work_outlined,
                  ), // Comprobante de domicilio

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveDocuments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Guardar Documentos',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUploadCard(String label, IconData icon) {
    final localName = _fileNames[label];
    final existingUrl = _uploadedUrls[label];

    final bool hasFile = localName != null;
    final bool hasUrl = existingUrl != null && existingUrl.isNotEmpty;
    final bool isCompleted = hasFile || hasUrl;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted ? Colors.blue[200]! : Colors.grey[300]!,
        ),
      ),
      child: InkWell(
        onTap: () => _pickFile(label),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.blue[50] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isCompleted
                      ? const Color(0xFF1565C0)
                      : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile
                          ? 'Archivo seleccionado: $localName'
                          : (hasUrl
                                ? 'Documento ya subido'
                                : 'Toque para seleccionar'),
                      style: TextStyle(
                        color: hasFile
                            ? Colors.green[700]
                            : (hasUrl ? Colors.blue[700] : Colors.grey[500]),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}
