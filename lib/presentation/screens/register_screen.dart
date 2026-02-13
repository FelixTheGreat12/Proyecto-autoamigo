import 'package:autoamigo/infrastructure/auth/auth_service.dart';
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
  // Dirección: campos detallados
  final TextEditingController _calleController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _coloniaController = TextEditingController();
  final TextEditingController _estadoController = TextEditingController();
  final TextEditingController _municipioController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Fecha de nacimiento: día/mes/año (separados)
  String? _selectedDay;
  String? _selectedMonth; // stored as '01'..'12'
  String? _selectedYear; // stored as 'YYYY'

  // Month display names in Spanish, but values remain as '01'..'12'
  final List<String> _monthNumbers = [
    '01','02','03','04','05','06','07','08','09','10','11','12'
  ];
  final Map<String, String> _monthNames = {
    '01': 'Ene',
    '02': 'Feb',
    '03': 'Mar',
    '04': 'Abr',
    '05': 'May',
    '06': 'Jun',
    '07': 'Jul',
    '08': 'Ago',
    '09': 'Sep',
    '10': 'Oct',
    '11': 'Nov',
    '12': 'Dic',
  };

  // Years limited to age between 18 and 100 (inclusive)
  late final List<String> _years;

  // --- LISTAS PARA DIRECCIÓN ---
  String? _selectedEstado;
  String? _selectedMunicipioZac;

  final List<String> _estadosMexico = [
    'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche', 
    'Chiapas', 'Chihuahua', 'Ciudad de México', 'Coahuila', 'Colima', 
    'Durango', 'Estado de México', 'Guanajuato', 'Guerrero', 'Hidalgo', 
    'Jalisco', 'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca', 
    'Puebla', 'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa', 
    'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán', 
    'Zacatecas'
  ];

  final List<String> _municipiosZacatecas = [
    'Apozol', 'Apulco', 'Atolinga', 'Benito Juárez', 'Calera', 
    'Cañitas de Felipe Pescador', 'Concepción del Oro', 'Cuauhtémoc', 'Chalchihuites', 
    'El Plateado de Joaquín Amaro', 'El Salvador', 'Fresnillo', 'Genaro Codina', 
    'General Enrique Estrada', 'General Francisco R. Murguía', 'General Pánfilo Natera', 
    'Guadalupe', 'Huanusco', 'Jalpa', 'Jerez', 'Jiménez del Teul', 'Juan Aldama', 
    'Juchipila', 'Loreto', 'Luis Moya', 'Mazapil', 'Melchor Ocampo', 'Mezquital del Oro', 
    'Miguel Auza', 'Momax', 'Monte Escobedo', 'Morelos', 'Moyahua de Estrada', 
    'Nochistlán de Mejía', 'Noria de Ángeles', 'Ojocaliente', 'Pánuco', 'Pinos', 
    'Río Grande', 'Sain Alto', 'Santa María de la Paz', 'Sombrerete', 'Susticacán', 
    'Tabasco', 'Tepechitlán', 'Tepetongo', 'Teúl de González Ortega', 
    'Tlaltenango de Sánchez Román', 'Trancoso', 'Trinidad García de la Cadena', 
    'Valparaíso', 'Vetagrande', 'Villa de Cos', 'Villa García', 'Villa González Ortega', 
    'Villa Hidalgo', 'Villa Nueva', 'Zacatecas'
  ];

  List<String> get _computedDays {
    // Compute days based on selected month and year. If year not selected, use current year.
    final year = _selectedYear != null ? int.tryParse(_selectedYear!) ?? DateTime.now().year : DateTime.now().year;
    final month = _selectedMonth != null ? int.tryParse(_selectedMonth!) ?? 1 : 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (i) => '${i + 1}');
  }

  @override
  void initState() {
    super.initState();
    final current = DateTime.now().year;
    const minAge = 18;
    const maxAge = 100;
    final count = maxAge - minAge + 1; // inclusive
    _years = List.generate(count, (i) => '${current - minAge - i}');
  }

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
    _calleController.dispose();
    _numeroController.dispose();
    _coloniaController.dispose();
    _estadoController.dispose();
    _municipioController.dispose();
    _cpController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _register() async {
    // --- MODIFICADO: Lógica de Foco ---
    // 1. Validar que el formulario cumpla las reglas
    if (!_formKey.currentState!.validate()) {
      // Si el formulario no es válido, encontramos el primer error y le damos foco.

      // 1. Validar Nombre (>2 caracteres, es decir >=3)
      if (_fullNameController.text.trim().length < 3) {
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

    // 3. Validar que la fecha de nacimiento esté completa
    if (_selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona día, mes y año de nacimiento.')), 
      );
      return;
    }

    // 4. Validar coherencia de dirección
    final addressError = _validateAddressCoherence(
      calle: _calleController.text.trim(),
      numero: _numeroController.text.trim(),
      colonia: _coloniaController.text.trim(),
      estado: _estadoController.text.trim(),
      municipio: _municipioController.text.trim(),
      cp: _cpController.text.trim(),
    );
    if (addressError != null) {
      return;
    }

    // 5. Si todo es válido, preparar los datos
    Map<String, dynamic> userData = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      // Guardamos la fecha en formato DD/MM/YYYY
      'birthDate': '${_selectedDay!.padLeft(2, '0')}/${_selectedMonth!}/${_selectedYear!}',
      'address': {
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'colonia': _coloniaController.text.trim(),
        'estado': _estadoController.text.trim(),
        'municipio': _municipioController.text.trim(),
        'cp': _cpController.text.trim(),
      },
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
      backgroundColor: const Color(0xFFF5F5F5), // Fondo gris muy claro
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: const Color(0xFF0D47A1), // Azul oscuro
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header bonito
                Container(
                  padding: const EdgeInsets.all(20),
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
                    Icons.person_add_rounded,
                    size: 60,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Bienvenido a AutoAmigo",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Completa tus datos para empezar",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Sección 1: Datos Personales
                _buildSectionCard(
                  "Información Personal",
                  Icons.person,
                  [
                    _buildTextFormField(
                      _fullNameController,
                      'Nombre Completo',
                      icon: Icons.badge_outlined,
                      focusNode: _fullNameFocus,
                      validator: (value) {
                         if (value == null || value.trim().length < 3) {
                          return 'El nombre debe tener más de 2 caracteres.';
                        }
                        if (RegExp(r'\d').hasMatch(value.trim())) {
                          return 'El nombre no debe contener números.';
                        }
                        return null;
                      },
                    ),
                    _buildTextFormField(
                      _emailController,
                      'Correo Electrónico',
                      icon: Icons.email_outlined,
                      focusNode: _emailFocus,
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
                      'Teléfono',
                      icon: Icons.phone_android,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    _buildBirthDateFields(),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Sección 2: Dirección
                _buildSectionCard(
                  "Dirección",
                  Icons.location_on,
                  [
                    _buildAddressFields(),
                  ],
                ),

                const SizedBox(height: 20),

                // Sección 3: Seguridad
                _buildSectionCard(
                  "Seguridad",
                  Icons.lock,
                  [
                     _buildTextFormField(
                      _passwordController,
                      'Contraseña',
                      icon: Icons.lock_outline,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length <= 6) {
                          return 'La contraseña debe tener más de 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                // Checkbox de Términos y Condiciones
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: CheckboxListTile(
                    value: _acceptTerms,
                    onChanged: (value) =>
                        setState(() => _acceptTerms = value ?? false),
                    title: const Text('He leído y acepto los Términos y Condiciones', style: TextStyle(fontSize: 14)),
                    activeColor: const Color(0xFF0D47A1),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),

                // Botones de acción
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                    ),
                    child: const Text('Registrarme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar y regresar', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- NUEVA FUNCIÓN para construir tarjetas de sección ---
  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0D47A1), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          ...children,
        ],
      ),
    );
  }

  // --- MODIFICADO: Diseño mejorado campos de texto ---
  Widget _buildTextFormField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red[300]!),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red[700]!),
          ),
        ),
        validator: validator,
      ),
    );
  }

  // Widget MEJORADO para campos de Fecha - NO TOCAR LOGICA, SOLO DISEÑO
  Widget _buildBirthDateFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fecha de nacimiento', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropDown(
                  hint: 'Día',
                  items: _computedDays,
                  value: _selectedDay,
                  onChanged: (v) => setState(() => _selectedDay = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropDown(
                  hint: 'Mes',
                  items: _monthNumbers,
                  itemLabels: _monthNames, // Mapping para mostrar Ene, Feb...
                  value: _selectedMonth,
                  onChanged: (v) => setState(() {
                    _selectedMonth = v;
                    final year = _selectedYear != null ? int.tryParse(_selectedYear!) ?? DateTime.now().year : DateTime.now().year;
                    final monthInt = v != null ? int.tryParse(v) ?? 1 : 1;
                    final daysInMonth = DateTime(year, monthInt + 1, 0).day;
                    if (_selectedDay != null && int.tryParse(_selectedDay!)! > daysInMonth) {
                      _selectedDay = null; // reset invalid day
                    }
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropDown(
                  hint: 'Año',
                  items: _years,
                  value: _selectedYear,
                  onChanged: (v) => setState(() {
                    _selectedYear = v;
                    final yearInt = v != null ? int.tryParse(v) ?? DateTime.now().year : DateTime.now().year;
                    final monthInt = _selectedMonth != null ? int.tryParse(_selectedMonth!) ?? 1 : 1;
                    final daysInMonth = DateTime(yearInt, monthInt + 1, 0).day;
                    if (_selectedDay != null && int.tryParse(_selectedDay!)! > daysInMonth) {
                      _selectedDay = null;
                    }
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper para dropdowns consistentes
  Widget _buildDropDown({
    required String hint, 
    required List<String> items, 
    required String? value, 
    required Function(String?) onChanged,
    Map<String,String>? itemLabels,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
      hint: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      items: items.map((val) => DropdownMenuItem(value: val, child: Text(itemLabels?[val] ?? val, style: const TextStyle(fontSize: 13)))).toList(),
      value: value,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Requerido' : null,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
    );
  }

  // Validadores personalizados
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingresa el teléfono.';
    }
    
    final phone = value.trim();
    
    // Rechazar si contiene letras u otros caracteres no numéricos
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Advertencia: El teléfono solo debe contener números.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return 'El teléfono solo debe contener números.';
    }
    
    if (phone.length != 10) {
      return 'El teléfono debe tener exactamente 10 dígitos.';
    }
    
    // Patrón secuencial: 0123456789, 1234567890, etc.
    bool isSequential = false;
    for (int i = 0; i < phone.length - 1; i++) {
      if (int.parse(phone[i]) + 1 != int.parse(phone[i + 1])) {
        isSequential = false;
        break;
      }
      isSequential = true;
    }
    if (isSequential) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Advertencia: El teléfono parece ser un número secuencial.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return 'Por favor, ingresa un teléfono válido.';
    }
    
    // Patrón repetitivo: 1111111111, 5555555555, etc.
    if (phone.split('').toSet().length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Advertencia: El teléfono no puede tener todos los dígitos iguales.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return 'Por favor, ingresa un teléfono válido.';
    }
    
    return null;
  }

  String? _validateAddressCoherence({
    required String calle,
    required String numero,
    required String colonia,
    required String estado,
    required String municipio,
    required String cp,
  }) {
    // Rechazar palabras ofensivas/absurdas comunes
    final prohibitedWords = ['tonto', 'falso', 'test', 'demo', 'prueba', 'xxx', 'aaa', 'bbb'];
    final inputLower = '$calle $colonia $municipio'.toLowerCase();
    
    for (final word in prohibitedWords) {
      if (inputLower.contains(word)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Advertencia: Dirección incoherente. Por favor, ingresa datos reales.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return 'La dirección debe ser coherente y real.';
      }
    }
    
    // Validar que los campos no sean solo números
    if (RegExp(r'^\d+$').hasMatch(calle.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Advertencia: La calle no puede ser solo números.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return 'La calle debe contener letras.';
    }
    
    // Validar formato CP (números de 5 dígitos en México)
    if (!RegExp(r'^\d{5}$').hasMatch(cp.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Advertencia: El CP debe tener 5 dígitos.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return 'El código postal debe tener 5 dígitos.';
    }
    
    return null;
  }

  // Widget para campos detallados de Dirección
  Widget _buildAddressFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dirección', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          
          // Calle
          _buildTextFormField(
            _calleController,
            'Calle',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, ingresa la calle.';
              }
              if (RegExp(r'^\d+$').hasMatch(value.trim())) {
                return 'La calle debe contener letras.';
              }
              if (RegExp(r'\d').hasMatch(value.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Advertencia: La calle no puede contener números.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
                return 'La calle no debe contener números.';
              }
              return null;
            },
          ),
          
          // Número (ext/int) y Colonia en fila
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextFormField(
                  _numeroController,
                  'Número (ext/int)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el número.';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Advertencia: El número solo debe contener dígitos.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return 'El número solo debe contener dígitos.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  _coloniaController,
                  'Colonia',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa la colonia.';
                    }
                    if (RegExp(r'\d').hasMatch(value.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Advertencia: La colonia no puede contener números.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return 'La colonia no debe contener números.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          // Estado y Municipio en fila
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estado', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Selecciona Estado',
                        filled: true,
                        fillColor: Colors.grey[50], // Fondo gris claro
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)), // Borde gris suave
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _estadosMexico.map((edo) => DropdownMenuItem(value: edo, child: Text(edo, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                      value: _selectedEstado,
                      onChanged: (val) {
                        setState(() {
                          _selectedEstado = val;
                          _estadoController.text = val ?? '';
                          // Si cambia el estado, limpiamos el municipio
                          _selectedMunicipioZac = null;
                          _municipioController.clear();
                        });
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _selectedEstado == 'Zacatecas'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Municipio', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Selecciona Municipio',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: _municipiosZacatecas.map((mun) => DropdownMenuItem(value: mun, child: Text(mun, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                            value: _selectedMunicipioZac,
                            onChanged: (val) {
                              setState(() {
                                _selectedMunicipioZac = val;
                                _municipioController.text = val ?? '';
                              });
                            },
                            validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                          ),
                        ],
                      )
                    : _buildTextFormField(
                        _municipioController,
                        'Municipio',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el municipio.';
                          }
                          // ...validaciones originales...
                          if (RegExp(r'\d').hasMatch(value.trim())) {
                            return 'El municipio no debe contener números.';
                          }
                          return null;
                        },
                      ),
              ),
            ],
          ),
          
          // CP
          _buildTextFormField(
            _cpController,
            'Código Postal (CP)',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el código postal.';
              }
              if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Advertencia: El CP solo debe contener números.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
                return 'El CP solo debe contener números.';
              }
              if (value.trim().length != 5) {
                return 'El CP debe tener exactamente 5 dígitos.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
