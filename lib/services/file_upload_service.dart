import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FileUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Selecciona un archivo usando file picker
  /// Soporta extensiones: ['.pdf', '.jpg', '.jpeg', '.png']
  Future<PlatformFile?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
    } catch (e) {
      print('Error picking file: $e');
    }
    return null;
  }

  /// Sube un archivo a Firebase Storage
  /// Retorna la URL pública si es exitoso, null si falla
  Future<String?> uploadFile({
    required File file,
    required String fileName,
    required String documentType,
  }) async {
    // Validaciones previas
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('Usuario no autenticado');
      return null;
    }

    if (!file.existsSync()) {
      print('El archivo no existe en la ruta: ${file.path}');
      return null;
    }

    // Ruta: /autos/{userId}/{documentType}/{fileName}
    final ref = _storage.ref()
        .child('autos')
        .child(userId)
        .child(documentType)
        .child(fileName);

    // Intentar inferir contentType simple
    final ext = fileName.split('.').last.toLowerCase();
    String? contentType;
    if (ext == 'pdf') contentType = 'application/pdf';
    if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
    if (ext == 'png') contentType = 'image/png';

    try {
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      final uploadTask = metadata != null
          ? ref.putFile(file, metadata)
          : ref.putFile(file);

      // Esperar al resultado de la subida
      await uploadTask.whenComplete(() {});

      // Verificar si la tarea fue exitosa
      final taskSnapshot = uploadTask.snapshot;
      if (taskSnapshot.state != TaskState.success) {
        print('Upload failed, task state: ${taskSnapshot.state}');
        return null;
      }

      // Obtener URL descargable
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (fe) {
      print('FirebaseException uploading file: code=${fe.code} message=${fe.message}');
      return null;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  /// Sube datos (bytes) a Firebase Storage. Útil cuando PlatformFile.path es null.
  /// Retorna la URL pública si es exitoso, null si falla
  Future<String?> uploadData({
    required List<int> data,
    required String fileName,
    required String documentType,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('Usuario no autenticado');
      return null;
    }

    // Ruta: /autos/{userId}/{documentType}/{fileName}
    final ref = _storage.ref()
        .child('autos')
        .child(userId)
        .child(documentType)
        .child(fileName);

    final ext = fileName.split('.').last.toLowerCase();
    String? contentType;
    if (ext == 'pdf') contentType = 'application/pdf';
    if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
    if (ext == 'png') contentType = 'image/png';

    try {
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      final uploadTask = metadata != null
          ? ref.putData(data as Uint8List, metadata)
          : ref.putData(data as Uint8List);

      // Escuchar progreso
      uploadTask.snapshotEvents.listen((snapshot) {
        final transferred = snapshot.bytesTransferred;
        final total = snapshot.totalBytes;
        if (total > 0) {
          final pct = (transferred / total * 100).toStringAsFixed(0);
          print('Upload progress: $transferred/$total ($pct%)');
        } else {
          print('Upload progress: $transferred bytes transferred');
        }
      });

      await uploadTask.whenComplete(() {});

      final taskSnapshot = uploadTask.snapshot;
      if (taskSnapshot.state != TaskState.success) {
        print('Upload failed, task state: ${taskSnapshot.state}');
        return null;
      }

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (fe) {
      print('FirebaseException uploading data: code=${fe.code} message=${fe.message}');
      return null;
    } catch (e) {
      print('Error uploading data: $e');
      return null;
    }
  }

  /// Elimina un archivo de Firebase Storage
  Future<bool> deleteFile({required String fileName, required String documentType}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final ref = _storage.ref()
          .child('autos')
          .child(userId)
          .child(documentType)
          .child(fileName);

      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Obtiene el nombre del archivo desde PlatformFile
  String getFileName(PlatformFile file) {
    return file.name;
  }

  /// Obtiene la extensión del archivo
  String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }
}
