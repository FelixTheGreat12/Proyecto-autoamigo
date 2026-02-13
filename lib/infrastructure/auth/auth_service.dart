import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter para obtener el usuario actual
  User? get currentUser => _auth.currentUser;

  // --- MÉTODO PARA INICIAR SESIÓN (LOGIN) ---
  // Este solo necesita el correo y la contraseña.
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      print("Error al iniciar sesión: ${e.code}");
      return null;
    }
  }

  // --- MÉTODO PARA REGISTRAR UN NUEVO USUARIO ---
  // Este guarda los datos en Firestore.
  Future<UserCredential?> signUpAndSaveData(Map<String, dynamic> userData, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: userData['email'],
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Error en el registro (Auth): ${e.code}");
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}