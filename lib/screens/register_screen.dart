import 'package:autoamigo/auth/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- AÑADIDO: Nodos de Foco ---
  final _fullNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  // No necesitamos para fecha o dirección ya que no tienen validación

  final AuthService _authService = AuthService();
  bool _acceptTerms = false;

  // --- AÑADIDO: Método dispose para limpiar ---
  @override
  void dispose() {
    // Limpiamos los nodos de foco
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();

    // Limpiamos los controladores
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _register() async {
    // --- MODIFICADO: Lógica de Foco ---
    // 1. Validar que el formulario cumpla las reglas
    if (!_formKey.currentState!.validate()) {
      // Si el formulario no es válido, encontramos el primer error y le damos foco.

      // 1. Validar Nombre
      if (_fullNameController.text.trim().length < 4) {
        _fullNameFocus.requestFocus(); // Mueve la pantalla a este campo
        return;
      }

      // 2. Validar Correo
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(_emailController.text.trim())) {
        _emailFocus.requestFocus(); // Mueve la pantalla a este campo
        return;
      }

      // 3. Validar Teléfono
      final phone = _phoneController.text.trim();
      if (phone.length != 10 || int.tryParse(phone) == null) {
        _phoneFocus.requestFocus(); // Mueve la pantalla a este campo
        return;
      }

      // 4. Validar Contraseña
      if (_passwordController.text.length <= 6) {
        _passwordFocus.requestFocus(); // Mueve la pantalla a este campo
        return;
      }
      return; // Detener si el formulario no es válido
    }
    // --- FIN DE LA MODIFICACIÓN DE FOCO ---

    // 2. Validar que los términos y condiciones estén aceptados
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes aceptar los Términos y Condiciones'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Si todo es válido, preparar los datos
    Map<String, dynamic> userData = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'birthDate': _birthDateController.text.trim(),
      'address': _addressController.text.trim(),
    };
    String password = _passwordController.text.trim();

    // 4. Llama al servicio para registrar y guardar los datos
    final result = await _authService.signUpAndSaveData(userData, password);

    // 5. Navega a la pantalla de inicio si todo salió bien
    if (result != null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error en el registro. El correo ya podría estar en uso.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register'), elevation: 0),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_alt_1,
                  size: 100,
                  color: Colors.grey[700],
                ),
                SizedBox(height: 30),

                // --- MODIFICADO: Asignar FocusNode ---
                _buildTextFormField(
                  _fullNameController,
                  'Nombre Completo',
                  focusNode: _fullNameFocus, // Asignar nodo
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'El nombre debe tener al menos 4 caracteres.';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  _emailController,
                  'Correo Electronico',
                  focusNode: _emailFocus, // Asignar nodo
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingresa un correo.';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Por favor, ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  _phoneController,
                  'Telefono',
                  focusNode: _phoneFocus, // Asignar nodo
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().length != 10) {
                      return 'El teléfono debe tener 10 caracteres.';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'El teléfono debe contener solo números.';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  _birthDateController,
                  'Fecha de nacimiento',
                ),
                _buildTextFormField(_addressController, 'Dirección'),
                _buildTextFormField(
                  _passwordController,
                  'Contraseña',
                  focusNode: _passwordFocus, // Asignar nodo
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length <= 6) {
                      return 'La contraseña debe tener más de 6 caracteres.';
                    }
                    return null;
                  },
                ),
                // --- FIN DE MODIFICACIONES ---

                // Checkbox de Términos y Condiciones
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) =>
                            setState(() => _acceptTerms = value ?? false),
                      ),
                      Expanded(
                        child: Text('Acepto los Términos y Condiciones'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _register, // Llama a la nueva función
                        child: Text('Aceptar'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
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

  // --- MODIFICADO: Añadir parámetro FocusNode ---
  Widget _buildTextFormField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    FocusNode? focusNode, // Parámetro para el nodo de foco
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          TextFormField(
            controller: controller,
            focusNode: focusNode, // Asignar el nodo aquí
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
