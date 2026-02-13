import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'documentos_requeridos_screen.dart';

class CotizarAutoScreen extends StatefulWidget {
  // Parámetros opcionales para MODO EDICIÓN
  final String? autoIdToEdit;
  final Map<String, dynamic>? existingData;

  const CotizarAutoScreen({super.key, this.autoIdToEdit, this.existingData});

  @override
  State<CotizarAutoScreen> createState() => _CotizarAutoScreenState();
}

class _CotizarAutoScreenState extends State<CotizarAutoScreen> {
  final TextEditingController _plateController = TextEditingController();
  bool _isSaving = false;

  String? selectedYear;
  String? selectedBrand;
  String? selectedModel;
  String? selectedColor;
  String? selectedTransmission;

  final years = List<String>.generate(9, (i) => '${2024 - i}');

  final List<String> colors = [
    'Blanco', 'Negro', 'Gris', 'Plata', 'Azul', 'Rojo', 'Café', 'Beige', 'Verde', 'Amarillo'
  ];

  final List<String> transmissions = [
    'Automática', 'Estándar', 'CVT', 'DSG', 'Tiptronic'
  ];

  final Map<String, List<String>> brandsWithModels = {
    'Nissan': ['March', 'Versa', 'Sentra'],
    'Volkswagen': ['Jetta', 'Vento', 'Gol'],
    'Kia': ['Picanto', 'Rio', 'K3'],
    'Chevrolet': ['Spark', 'Beat', 'Aveo'],
    'Hyundai': ['Grand i10', 'Accent', 'i10', 'i20'],
    'Ford': ['Figo', 'Fiesta', 'Focus'],
    'Toyota': ['Yaris', 'Corolla', 'Avanza'],
    'Honda': ['City', 'Civic', 'Fit'],
  };

  List<String> get brands => brandsWithModels.keys.toList();

  List<String> get models {
    if (selectedBrand == null) return [];
    return brandsWithModels[selectedBrand] ?? [];
  }

  @override
  void initState() {
    super.initState();
    // SI ESTAMOS EN MODO EDICIÓN: Pre-llenar los campos
    if (widget.existingData != null) {
      selectedYear = widget.existingData!['year'];
      selectedBrand = widget.existingData!['brand'];
      selectedModel = widget.existingData!['model'];
      selectedColor = widget.existingData!['color'];
      selectedTransmission = widget.existingData!['transmission'];
      _plateController.text = widget.existingData!['plate'] ?? '';
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Saber si estamos editando o creando para cambiar textos
    final isEditing = widget.autoIdToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Auto' : 'Cotizar Auto'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              isEditing
                  ? 'Actualiza los datos de tu auto'
                  : 'Cotiza y vende tu auto al mejor precio',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isEditing
                  ? 'Modifica la información básica y luego actualiza los documentos.'
                  : 'Encuentra las mejores ofertas para vender tu usado de manera rápida, fácil y segura.',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDropdownYear(),
                      const SizedBox(height: 12),
                      _buildDropdownBrand(),
                      const SizedBox(height: 12),
                      _buildDropdownModel(),
                      const SizedBox(height: 12),
                      _buildDropdownColor(),
                      const SizedBox(height: 12),
                      _buildDropdownTransmission(),
                      const SizedBox(height: 12),
                      _buildPlateInput(),
                      const SizedBox(height: 16),
                      _buildCotizarButton(isEditing),
                    ],
                  );
                }

                // Layout para pantallas anchas
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildDropdownYear()),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _buildDropdownBrand()),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _buildDropdownModel()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDropdownColor()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdownTransmission()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPlateInput()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: _buildCotizarButton(isEditing)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownYear() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Año',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedYear,
          hint: const Text('Año'),
          onChanged: _isSaving ? null : (v) => setState(() => selectedYear = v),
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text(y)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownBrand() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Marca',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedBrand,
          hint: const Text('Marca'),
          onChanged: _isSaving
              ? null
              : (v) => setState(() {
                  selectedBrand = v;
                  selectedModel = null;
                }),
          items: brands
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownModel() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Modelo',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedModel,
          hint: const Text('Modelo'),
          onChanged: _isSaving
              ? null
              : (v) => setState(() => selectedModel = v),
          items: models
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDropdownColor() {  
    return GestureDetector(
      onTap: _isSaving ? null : _showColorPicker,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Color',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (selectedColor == null)
              const Text('Selecciona un color',
                  style: TextStyle(color: Colors.black54))
            else
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getColorFromName(selectedColor!),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: null,
                  ),
                  const SizedBox(width: 8),
                  Text(selectedColor!),
                ],
              ),
            const Icon(Icons.arrow_drop_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    switch (name) {
      case 'Blanco':
        return Colors.white;
      case 'Negro':
        return Colors.black;
      case 'Gris':
        return Colors.grey;
      case 'Plata':
        return const Color(0xFFC0C0C0);
      case 'Azul':
        return Colors.blue;
      case 'Rojo':
        return Colors.red;
      case 'Café':
        return Colors.brown;
      case 'Beige':
        return const Color(0xFFF5F5DC);
      case 'Verde':
        return Colors.green;
      case 'Amarillo':
        return Colors.yellow;
      default:
        return Colors.transparent;
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Elige el color'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: colors.map((color) {
                final isSelected = selectedColor == color;
                final colorValue = _getColorFromName(color);
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = color);
                    Navigator.pop(context);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorValue,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.blue, width: 3)
                              : Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                            )
                          ],
                        ),
                        child: null,
                      ),
                      const SizedBox(height: 4),
                      Text(color,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            )
          ],
        );
      },
    );
  }

  Widget _buildDropdownTransmission() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Transmisión',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedTransmission,
          hint: const Text('Tipo'),
          onChanged: _isSaving
              ? null
              : (v) => setState(() => selectedTransmission = v),
          items: transmissions
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPlateInput() {
    return TextField(
      controller: _plateController,
      enabled: !_isSaving,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[IOQÑioqñ]')),
        PlacaInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Placa',
        hintText: 'ABC-12-34',
        helperText: '3 letras + 4 números (Sin I, O, Q, Ñ)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _saveOrUpdateAuto() async {
    if (_isSaving) return;

    if (selectedYear == null ||
        selectedBrand == null ||
        selectedModel == null ||
        selectedColor == null ||
        selectedTransmission == null ||
        _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Validar formato de placa estricto
    final plateText = _plateController.text.trim();
    // Regex: 3 letras, guion, 2 numeros, guion, 2 numeros
    final plateRegex = RegExp(r'^[A-Z]{3}-[0-9]{2}-[0-9]{2}$');
    
    if (!plateRegex.hasMatch(plateText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La placa debe estar completa: ABC-12-34'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario no autenticado')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String autoIdResult;

      // CORRECCIÓN: Definir explícitamente el tipo del mapa como <String, dynamic>
      final Map<String, dynamic> dataToSave = {
        'year': selectedYear,
        'brand': selectedBrand,
        'model': selectedModel,
        'color': selectedColor,
        'transmission': selectedTransmission,
        'plate': _plateController.text.trim().toUpperCase(),
        'userId': userId,
      };

      if (widget.autoIdToEdit != null) {
        // --- MODO ACTUALIZACIÓN ---
        autoIdResult = widget.autoIdToEdit!;
        await FirebaseFirestore.instance
            .collection('autos')
            .doc(autoIdResult)
            .update(dataToSave);

        if (!mounted) return;

        // Navegar a Documentos (pasando el ID)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DocumentosRequeridosScreen(autoId: autoIdResult),
          ),
        ).then((_) {
          if (mounted) setState(() => _isSaving = false);
        });
      } else {
        // --- MODO CREACIÓN (DIFERIDO) ---
        // NO guardamos en Firestore todavía. Pasamos los datos en memoria.
        
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentosRequeridosScreen(
              autoId: null,
              tempAutoData: dataToSave,
            ),
          ),
        ).then((_) {
          // Al volver, simplemente dejamos de cargar
          if (mounted) setState(() => _isSaving = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  Widget _buildCotizarButton(bool isEditing) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveOrUpdateAuto,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : Text(
              isEditing
                  ? 'Guardar cambios y Editar Documentos'
                  : 'Registrar auto',
            ),
    );
  }
}

class PlacaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // 1. Normalizar: Mayúsculas y quitar guiones
    String newText = newValue.text.toUpperCase().replaceAll('-', '');

    // 2. Filtrar caracteres prohibidos (I, O, Q, Ñ) y no alfanuméricos
    newText = newText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    newText = newText.replaceAll(RegExp(r'[IOQÑ]'), '');

    // 3. Construir string válido (LLLNNNN)
    String processed = '';
    for (int i = 0; i < newText.length; i++) {
      if (i >= 7) break; // Máximo 7 caracteres reales

      String char = newText[i];
      if (i < 3) {
        // Primeros 3 deben ser letras
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          processed += char;
        }
      } else {
        // Siguientes 4 deben ser números
        if (RegExp(r'[0-9]').hasMatch(char)) {
          processed += char;
        }
      }
    }

    // 4. Formatear con guiones: ABC-12-34
    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < processed.length; i++) {
      if (i == 3) formatted.write('-');
      if (i == 5) formatted.write('-');
      formatted.write(processed[i]);
    }

    final String resultText = formatted.toString();

    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(offset: resultText.length),
    );
  }
}
