import 'package:autoamigo/infrastructure/auth/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- AÑADIDO: Clave del formulario ---
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- AÑADIDO: Nodos de Foco ---
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final AuthService _authService = AuthService();

  // --- AÑADIDO: Controladores y Clave para el diálogo de reseteo ---
  final _resetFormKey = GlobalKey<FormState>();
  final TextEditingController _resetEmailController = TextEditingController();

  // --- AÑADIDO: Método dispose para limpiar ---
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _login() async {
    // --- MODIFICADO: Lógica de validación y foco ---
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) {
      // 2. Si es inválido, encontrar el primer error y hacer foco

      // 2a. Validar Correo
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (_emailController.text.trim().isEmpty ||
          !emailRegex.hasMatch(_emailController.text.trim())) {
        _emailFocus.requestFocus();
        return;
      }

      // 2b. Validar Contraseña
      if (_passwordController.text.isEmpty) {
        _passwordFocus.requestFocus();
        return;
      }
      return; // Detener
    }

    // 3. Si es válido, intentar iniciar sesión
    final result = await _authService.signInWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (result != null) {
      if (!mounted) return;
      // Navegar a la pantalla de inicio
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (!mounted) return;
      // Mostrar un error más descriptivo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión. Verifica tus credenciales.'),
          backgroundColor: Colors.red, // Advertencia en rojo
        ),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  void _forgotPassword() {
    // Limpiar el controlador por si se usó antes
    _resetEmailController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Recuperar Contraseña"),
          content: Form(
            key: _resetFormKey, // Usar la clave del formulario del diálogo
            child: Column(
              mainAxisSize: MainAxisSize.min, // Para que el diálogo no se expanda
              children: [
                Text(
                  "Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.",
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingresa tu correo.';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Por favor, ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            // Botón de Cancelar
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancelar"),
            ),
            // Botón de Enviar
            ElevatedButton(
              onPressed: () async {
                // Validar solo el formulario del diálogo
                if (_resetFormKey.currentState!.validate()) {
                  final email = _resetEmailController.text.trim();
                  
                  try {
                    // Llamar a nuestro servicio
                    await _authService.sendPasswordResetEmail(email);

                    if (!mounted) return;
                    Navigator.of(context).pop(); // Cerrar el diálogo
                    
                    // Mostrar mensaje de éxito
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Enlace de recuperación enviado a $email"),
                        backgroundColor: Colors.green,
                      ),
                    );

                  } catch (e) {
                    if (!mounted) return;
                    Navigator.of(context).pop(); // Cerrar el diálogo

                    // Mostrar mensaje de error (ej. usuario no encontrado)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: No se encontró un usuario con ese correo."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text("Enviar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Mantiene la pantalla fija, sin scroll al abrir teclado
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Icono principal
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 50,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "AutoAmigo",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Tu compañero en el camino",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),

                // Tarjeta de Login
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Bienvenido",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 15),
                      
                      // Campo Email
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF0D47A1), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, ingresa tu correo.';
                          }
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Por favor, ingresa un correo válido.';
                          }
                          return null;
                        },
                      ),
                      
                      SizedBox(height: 15),

                      // Campo Password
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF0D47A1), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa tu contraseña.';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10),

                      // Botón Forgot Password alineado a la derecha
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: const Color(0xFF0D47A1),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 10),

                      // Botón Iniciar Sesión (Principal)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Sección "No tienes cuenta?"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tienes una cuenta?",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    TextButton(
                      onPressed: _navigateToRegister,
                      child: Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          color: const Color(0xFF0D47A1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
