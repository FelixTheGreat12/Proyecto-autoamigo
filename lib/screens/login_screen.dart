import 'package:autoamigo/auth/auth_service.dart';
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
      appBar: AppBar(
        title: Text('AutoAmigo'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        // --- AÑADIDO: Widget Form ---
        child: Form(
          key: _formKey, // Asignar la clave
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_pin, size: 120, color: Colors.grey[700]),
                SizedBox(height: 20),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        // --- MODIFICADO: de TextField a TextFormField ---
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus, // Asignar nodo de foco
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor, ingresa tu correo.';
                            }
                            // Expresión regular para correo válido
                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Por favor, ingresa un correo válido.';
                            }
                            return null; // Nulo significa que es válido
                          },
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
                        // --- MODIFICADO: de TextField a TextFormField ---
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus, // Asignar nodo de foco
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa tu contraseña.';
                            }
                            return null; // Nulo significa que es válido
                          },
                        ),
                        SizedBox(height: 20),
                        // Botones de Registrarse e Iniciar Sesión
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _navigateToRegister,
                                child: Text('Registrarse'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _login, // Llama a la función con validación
                                child: Text('Iniciar Sesión'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
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
      ),
    );
  }
}
