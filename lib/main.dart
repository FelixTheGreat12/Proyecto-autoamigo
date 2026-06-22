import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/mis_autos_screen.dart';
import 'presentation/screens/mis_rentas_screen.dart';
import 'presentation/screens/solicitudes_renta_screen.dart';
import 'presentation/screens/cotizar_auto_screen.dart';
import 'presentation/screens/perfil_screen.dart';
import 'presentation/screens/subir_documentos_usuario_screen.dart';
// import 'presentation/screens/product_car_screen.dart';
import 'package:autoamigo/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'infrastructure/auth/auth_service.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar Stripe con la clave pública de Test
  Stripe.publishableKey = 'pk_test_51TKNZlGwTKTod0UVEk2GEIvXbEyRCsqJLaIBlbm0xjqbL9D2wUrdBHm0KIuGhxj5wqasbVwRXuuYYbs0WQIaBhE400bZAg1I9V';
  await Stripe.instance.applySettings();

  // Inicializar App Check en modo debug para desarrollo
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Inicializar background service de FCM antes de runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      home: AuthWrapper(), // Usamos un Wrapper para decidir qué pantalla mostrar
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/mis_autos': (context) => const  MisAutosScreen(),
        '/mis_rentas': (context) => const MisRentasScreen(),
        '/solicitudes_renta': (context) => const SolicitudesRentaScreen(),
        '/cotizar_auto': (context) => const CotizarAutoScreen(),
        '/perfil': (context) => const PerfilScreen(),
        '/subir_documentos_usuario': (context) => const SubirDocumentosUsuarioScreen(),
        '/adminDashboard': (context) => const AdminDashboardScreen(),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          // El usuario está logueado, validemos su rol e isBlocked en Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                
                if (userData?['isBlocked'] == true) {
                  // Si está bloqueado, forzamos cierre de sesión
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await FirebaseAuth.instance.signOut();
                  });
                  return const Scaffold(
                    body: Center(
                      child: Text('Tu cuenta ha sido bloqueada por un administrador.', style: TextStyle(color: Colors.red, fontSize: 18), textAlign: TextAlign.center,),
                    ),
                  );
                }

                if (userData?['role'] == 'admin') {
                  return const AdminDashboardScreen();
                }
                return HomeScreen();
              }
              // Fallback default
              return HomeScreen();
            },
          );
        }
        return LoginScreen();
      },
    );
  }
}