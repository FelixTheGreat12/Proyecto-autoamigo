import 'package:autoamigo/auth/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  void _login() async {
    // Asegúrate de limpiar los espacios en blanco
    final result = await _authService.signInWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (result != null) {
      // Navegar a la pantalla de inicio
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Mostrar un error más descriptivo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión. Verifica tus credenciales.'),
        ),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  void _forgotPassword() {
    // Aquí podrías implementar la lógica para enviar un correo de recuperación
    // Por ahora, solo mostrará un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Funcionalidad de recuperar contraseña pendiente.'),
      ),
    );
    // Future<void> resetPassword(String email) async {
    //   await _authService.sendPasswordResetEmail(email); // Necesitarías añadir este método en AuthService
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AutoAmigo'),
        elevation:
            0, // Remueve la sombra de la AppBar si quieres un look más plano
        backgroundColor:
            Colors.transparent, // Fondo transparente para la AppBar
        foregroundColor: Colors.black, // Color del texto del título
      ),
      body: SingleChildScrollView(
        // Para evitar overflow si el teclado aparece

        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono de usuario grande
              Icon(
                Icons.person_pin, // O Icons.person para un ícono más simple
                size: 120,
                color: Colors.grey[700],
              ),
              SizedBox(height: 20),
              // Tarjeta contenedora de los campos de login
              Card(
                elevation: 8, // Sombra para la tarjeta
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // Ocupa solo el espacio necesario
                    children: [
                      // Campo de Correo Electrónico
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Correo Electronico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo Electronico',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Campo de Contraseña
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Contraseña',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Botones de Registrarse e Iniciar Sesión
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _navigateToRegister, // Llama a la función para navegar
                              child: Text('Registrarse'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green[700], // Color de fondo verde
                                foregroundColor:
                                    Colors.white, // Color del texto blanco
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10), // Espacio entre botones
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _login,
                              child: Text('Iniciar Sesión'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.blue[700], // Color de fondo azul
                                foregroundColor:
                                    Colors.white, // Color del texto blanco
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Botón para Recuperar Contraseña
                      TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          'Recuperar Contraseña',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
