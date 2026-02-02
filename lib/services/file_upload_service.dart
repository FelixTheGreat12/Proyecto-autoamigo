import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FileUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Borra un archivo de Storage usando su URL pública
  /// Esta es la función necesaria para el borrado completo
  Future<void> deleteFileByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
      print("Archivo eliminado de Storage: $url");
    } catch (e) {
      print('Error eliminando archivo de Storage: $e');
    }
  }

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

  Future<String?> uploadFile({
    required File file,
    required String fileName,
    required String documentType,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    if (!file.existsSync()) return null;

    final ref = _storage
        .ref()
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
          ? ref.putFile(file, metadata)
          : ref.putFile(file);

      await uploadTask.whenComplete(() {});

      if (uploadTask.snapshot.state != TaskState.success) return null;

      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<String?> uploadData({
    required List<int> data,
    required String fileName,
    required String documentType,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final ref = _storage
        .ref()
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

      await uploadTask.whenComplete(() {});

      if (uploadTask.snapshot.state != TaskState.success) return null;

      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading data: $e');
      return null;
    }
  }

  Future<bool> deleteFile({
    required String fileName,
    required String documentType,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final ref = _storage
          .ref()
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

  String getFileName(PlatformFile file) => file.name;
  String getFileExtension(String fileName) =>
      fileName.split('.').last.toLowerCase();
}
