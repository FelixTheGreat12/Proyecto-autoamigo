import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/mis_autos_screen.dart';
import 'presentation/screens/cotizar_auto_screen.dart';
import 'presentation/screens/documentos_requeridos_screen.dart';
// import 'presentation/screens/product_car_screen.dart';
import 'infrastructure/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar App Check en modo debug para desarrollo
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Firebase Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(), // Usamos un Wrapper para decidir qué pantalla mostrar
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/mis_autos': (context) => const  MisAutosScreen(),
        '/cotizar_auto': (context) => const CotizarAutoScreen(),
        //'/documentos_requeridos': (context) => const DocumentosRequeridosScreen(),
        //'/product_car': (context) => const ProductCarScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return HomeScreen();
        }
        return LoginScreen();
      },
    );
  }
}