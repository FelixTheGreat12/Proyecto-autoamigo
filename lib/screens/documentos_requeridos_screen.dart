import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/file_upload_service.dart';
import 'product_car_screen.dart';

class DocumentosRequeridosScreen extends StatefulWidget {
  final String? autoId;
  final Map<String, dynamic>? tempAutoData;

  const DocumentosRequeridosScreen({
    super.key,
    this.autoId,
    this.tempAutoData,
  });

  @override
  State<DocumentosRequeridosScreen> createState() =>
      _DocumentosRequeridosScreenState();
}

class _DocumentosRequeridosScreenState
    extends State<DocumentosRequeridosScreen> {
  final FileUploadService _uploadService = FileUploadService();

  bool _completed = false;
  bool _isDeleting = false;
  bool _isUploading = false;
  bool _isLoadingInitialData = true;
  bool _isEditingExisting = false;

  final Map<String, dynamic> _selectedFiles = {
    'Tarjeta de circulación': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  final Map<String, String?> _fileNames = {
    'Tarjeta de circulación': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  // Mapa para guardar las URLs actuales (viejas o nuevas)
  Map<String, dynamic> _uploadedUrls = {
    'Tarjeta de circulación': null,
    'Comprobante de verificación vehicular': null,
    'Póliza de seguro': null,
    'Fotos del vehículo': null,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  Future<void> _loadExistingDocuments() async {
    if (widget.autoId == null) {
      setState(() {
        _isLoadingInitialData = false;
      });
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('autos')
          .doc(widget.autoId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        if (docSnapshot.data()!['status'] == 'registrado') {
          _isEditingExisting = true;
        }
      }

      final docsSnapshot = await FirebaseFirestore.instance
          .collection('autos')
          .doc(widget.autoId)
          .collection('documentos')
          .doc('documentos_info')
          .get();

      if (docsSnapshot.exists && docsSnapshot.data() != null) {
        final data = docsSnapshot.data()!;
        if (data['documents'] != null) {
          setState(() {
            _uploadedUrls = Map<String, dynamic>.from(data['documents']);
          });
        }
      }
    } catch (e) {
      print("Error cargando documentos existentes: $e");
    } finally {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _handleExit() async {
    if (_isUploading) return;

    if (_completed) {
      Navigator.of(context).pop();
      return;
    }

    // Si no hay autoId (es nuevo en memoria), solo salir sin borrar nada en BD
    if (widget.autoId == null) {
      Navigator.of(context).pop();
      return;
    }

    if (_isEditingExisting) {
      Navigator.of(context).pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar registro?'),
        content: const Text(
          'Si retrocedes ahora, se eliminarán los datos del auto y tendrás que empezar de nuevo.\n\n¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, eliminar y salir'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(widget.autoId)
            .delete();
      } catch (e) {
        print("Error: $e");
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Documentos requeridos'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
        ),
        body: _isDeleting || _isLoadingInitialData
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                            child: Text(
                              'Documentos requeridos',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          IgnorePointer(
                            ignoring: _isUploading,
                            child: Column(
                              children: [
                                _buildDocField(
                                  'Tarjeta de circulación',
                                  format: 'PDF',
                                ),
                                const SizedBox(height: 12),
                                _buildDocField(
                                  'Comprobante de verificación vehicular',
                                  format: 'PDF',
                                ),
                                const SizedBox(height: 12),
                                _buildDocField(
                                  'Póliza de seguro',
                                  format: 'PDF',
                                ),
                                const SizedBox(height: 12),
                                _buildDocField(
                                  'Fotos del vehículo',
                                  format: 'JPG',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isUploading
                                  ? null
                                  : _saveAllDocuments,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
                                  : Text(
                                      _isEditingExisting
                                          ? 'Guardar Cambios'
                                          : 'Registrar',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDocField(String label, {required String format}) {
    final fileName = _fileNames[label];
    final isSelectedNewFile = _selectedFiles[label] != null;
    final hasExistingUrl = _uploadedUrls[label] != null;

    String displayText = 'Seleccionar';
    Color textColor = Colors.grey[600]!;
    IconData icon = Icons.cloud_upload_outlined;

    if (isSelectedNewFile) {
      displayText = fileName ?? 'Archivo seleccionado';
      textColor = Colors.blue;
      icon = Icons.check_circle;
    } else if (hasExistingUrl) {
      displayText = 'Archivo cargado previamente ✅\n(Toca para cambiar)';
      textColor = Colors.green[700]!;
      icon = Icons.file_present;
    }

    final extensions = format == 'PDF' ? ['pdf'] : ['jpg', 'jpeg', 'png'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              'Solo $format',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFile(label, extensions),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: (isSelectedNewFile || hasExistingUrl)
                    ? textColor
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
              color: (isSelectedNewFile || hasExistingUrl)
                  ? textColor.withOpacity(0.05)
                  : Colors.white,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: textColor),
                  const SizedBox(height: 8),
                  Text(
                    displayText,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    textAlign: TextAlign.center,
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
  }

  Future<void> _saveAllDocuments() async {
    // Validar que TODOS los documentos estén presentes
    List<String> missingDocs = [];
    for (var key in _uploadedUrls.keys) {
      bool hasFile = _selectedFiles[key] != null;
      bool hasUrl = _uploadedUrls[key] != null && _uploadedUrls[key] != '';
      
      if (!hasFile && !hasUrl) {
        missingDocs.add(key);
      }
    }

    if (missingDocs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan documentos: ${missingDocs.length} pendientes.'),
          action: SnackBarAction(
            label: 'Ver cuáles',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Documentos faltantes'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: missingDocs.map((doc) => Text('• $doc')).toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    )
                  ],
                ),
              );
            },
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String autoId;

      // 1. Si es nuevo (no tiene ID), crear el documento del auto primero
      if (widget.autoId == null) {
        if (widget.tempAutoData == null) {
          throw Exception('No hay datos del auto para guardar');
        }
        
        // Asegurar status y fecha
        final dataToSave = Map<String, dynamic>.from(widget.tempAutoData!);
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
        dataToSave['status'] = 'borrador'; // Temporal hasta que se suban docs

        final docRef = await FirebaseFirestore.instance
            .collection('autos')
            .add(dataToSave);
        autoId = docRef.id;
      } else {
        autoId = widget.autoId!;
      }

      for (final entry in _selectedFiles.entries) {
        final documentType = entry.key;
        final platformFile = entry.value;

        // Si NO seleccionó archivo nuevo, saltamos (mantenemos el viejo)
        if (platformFile == null) continue;

        // 1. SUBIR ARCHIVO NUEVO
        String? downloadUrl;
        if (platformFile.path == null) {
          if (platformFile.bytes != null) {
            downloadUrl = await _uploadService.uploadData(
              data: platformFile.bytes!,
              fileName: platformFile.name,
              documentType: documentType,
            );
          }
        } else {
          final file = File(platformFile.path!);
          downloadUrl = await _uploadService.uploadFile(
            file: file,
            fileName: platformFile.name,
            documentType: documentType,
          );
        }

        // 2. SI SUBIÓ CON ÉXITO, BORRAR EL VIEJO Y ACTUALIZAR MAPA
        if (downloadUrl != null) {
          // Verificar si había uno viejo
          if (_uploadedUrls.containsKey(documentType)) {
            final oldUrl = _uploadedUrls[documentType];
            if (oldUrl != null && oldUrl is String && oldUrl.isNotEmpty) {
              // IMPORTANTE: Borrar el archivo viejo de Cloud Storage
              print("Reemplazando archivo anterior: $documentType");
              await _uploadService.deleteFileByUrl(oldUrl);
            }
          }

          // Actualizar con la nueva URL
          _uploadedUrls[documentType] = downloadUrl;
        }
      }

      await FirebaseFirestore.instance.collection('autos').doc(autoId).update({
        'status': 'registrado',
      });

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
        _completed = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado exitosamente')));

      final autoSnapshot = await FirebaseFirestore.instance
          .collection('autos')
          .doc(autoId)
          .get();
      final autoData = autoSnapshot.data() ?? {};

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProductCarScreen(autoId: autoId, carData: autoData),
          ),
          (route) =>
              route.isFirst ||
              route.settings.name == '/home' ||
              route.settings.name == '/mis_autos',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }
}
