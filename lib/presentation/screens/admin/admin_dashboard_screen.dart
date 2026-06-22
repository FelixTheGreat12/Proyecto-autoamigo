import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'ver_documento_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Panel de Administrador'),
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(icon: Icon(Icons.settings), text: 'Variables'),
                Tab(icon: Icon(Icons.block), text: 'Usuarios'),
                Tab(icon: Icon(Icons.fact_check), text: 'Validar Docs'),
                Tab(icon: Icon(Icons.article), text: 'Contrato'),
              ],
            ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            )
          ],
        ),
        body: const TabBarView(
          children: [
            VariablesAdminTab(),
            BloquearUsuariosTab(),
            ValidarDocumentosTab(),
            ContratoAdminTab(),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 1. PESTAÑA: VARIABLES (PRECIO GASOLINA)
// ----------------------------------------------------------------------
class VariablesAdminTab extends StatefulWidget {
  const VariablesAdminTab({Key? key}) : super(key: key);

  @override
  State<VariablesAdminTab> createState() => _VariablesAdminTabState();
}

class _VariablesAdminTabState extends State<VariablesAdminTab> {
  final TextEditingController _gasPriceController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVariables();
  }

  Future<void> _loadVariables() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('system_settings').doc('variables').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _gasPriceController.text = (data['gasolinePrice'] ?? 0).toString();
        _commissionController.text = (data['platformCommission'] ?? 20).toString();
        _depositController.text = (data['securityDeposit'] ?? 1500).toString();
        _deliveryFeeController.text = (data['deliveryFee'] ?? 150).toString();
        _basePriceController.text = (data['baseDailyPrice'] ?? 350).toString();
      }
    } catch (e) {
      debugPrint("Error al cargar variables: \$e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveVariables() async {
    setState(() => _isLoading = true);
    try {
      final double gasPrice = double.tryParse(_gasPriceController.text) ?? 0;
      final double commission = double.tryParse(_commissionController.text) ?? 0;
      final double deposit = double.tryParse(_depositController.text) ?? 0;
      final double deliveryFee = double.tryParse(_deliveryFeeController.text) ?? 0;
      final double baseDailyPrice = double.tryParse(_basePriceController.text) ?? 0;

      await FirebaseFirestore.instance.collection('system_settings').doc('variables').set(
        {
          'gasolinePrice': gasPrice,
          'platformCommission': commission,
          'securityDeposit': deposit,
          'deliveryFee': deliveryFee,
          'baseDailyPrice': baseDailyPrice,
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variables actualizadas con éxito', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar variables'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración Global',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _basePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio Base Diario Sugerido (MXN)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
              helperText: 'Base para calcular sugerencias de tarifa en Cotizar',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gasPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio de Gasolina por Litro (MXN)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_gas_station),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commissionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Comisión de Plataforma (%)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.percent),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _depositController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Depósito de Seguridad Sugerido (MXN)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _deliveryFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tarifa de Entrega Base (MXN)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.delivery_dining),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveVariables,
              icon: const Icon(Icons.save),
              label: const Text('Guardar Cambios'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. PESTAÑA: BLOQUEAR USUARIOS
// ----------------------------------------------------------------------
class BloquearUsuariosTab extends StatefulWidget {
  const BloquearUsuariosTab({Key? key}) : super(key: key);

  @override
  State<BloquearUsuariosTab> createState() => _BloquearUsuariosTabState();
}

class _BloquearUsuariosTabState extends State<BloquearUsuariosTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleBlockStatus(BuildContext context, String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBlocked': !currentStatus,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!currentStatus ? 'Usuario bloqueado' : 'Usuario desbloqueado')),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Campo de búsqueda
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar usuario por nombre o email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),
        // Lista de usuarios
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay usuarios registrados.'));
              }

              // Filtramos localmente para omitir a los administradores
              var users = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['role'] != 'admin';
              }).toList();

              // Aplicar búsqueda
              if (_searchQuery.isNotEmpty) {
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return fullName.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No se encontraron usuarios que coincidan.'
                        : 'No hay usuarios normales registrados.',
                  ),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final bool isBlocked = data['isBlocked'] == true;
                  final fullName = data['fullName'] ?? 'Desconocido';
                  final email = data['email'] ?? 'Sin correo';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isBlocked ? Colors.red : Colors.green,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(fullName),
                    subtitle: Text(email),
                    trailing: Switch(
                      value: isBlocked,
                      activeColor: Colors.red,
                      inactiveThumbColor: Colors.green,
                      onChanged: (val) {
                        _toggleBlockStatus(context, doc.id, isBlocked);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 3. PESTAÑA: VALIDAR DOCUMENTOS DE USUARIOS
// ----------------------------------------------------------------------
class ValidarDocumentosTab extends StatefulWidget {
  const ValidarDocumentosTab({super.key});

  @override
  State<ValidarDocumentosTab> createState() => _ValidarDocumentosTabState();
}

class _ValidarDocumentosTabState extends State<ValidarDocumentosTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos todos los usuarios para revisar si tienen documentos de identidad
    return Column(
      children: [
        // Campo de búsqueda
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar usuario por nombre o email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay usuarios registrados.'));
              }

              var users = snapshot.data!.docs;

              // Aplicar búsqueda
              if (_searchQuery.isNotEmpty) {
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return fullName.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No se encontraron usuarios que coincidan.'
                        : 'No hay usuarios registrados.',
                  ),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final fullName = userData['fullName'] ?? 'Usuario sin nombre';
                  final email = userData['email'] ?? 'Sin correo';
                  final userId = userDoc.id;
                  
                  // Verificamos si los documentos ya fueron validados (aprobados o rechazados)
                  final docStatus = userData['documentStatus'] ?? 'pendiente';

            // Opcional: si quisieras ocultarlos por completo al estar aprobados, lo harías aquí.
            // if (docStatus == 'aprobado') return const SizedBox.shrink();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('documentos')
                  .doc('documentos_info')
                  .get(),
              builder: (context, docSnapshot) {
                if (docSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink(); 
                }

                if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
                  // Si el usuario no ha subido documentos, no lo mostramos en esta lista
                  // para mantener la pantalla limpia de solo "pendientes de validación" (opcional)
                  return const SizedBox.shrink();
                }

                final docData = docSnapshot.data!.data() as Map<String, dynamic>?;
                final documents = docData?['documents'] as Map<String, dynamic>? ?? {};

                if (documents.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: docStatus == 'aprobado' 
                          ? Colors.green.shade300 
                          : docStatus == 'rechazado' 
                              ? Colors.red.shade300 
                              : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ExpansionTile(
                    title: Text(fullName),
                    subtitle: Text(
                      '$email\nEstado: ${docStatus.toUpperCase()}',
                      style: TextStyle(
                        color: docStatus == 'aprobado' 
                            ? Colors.green 
                            : docStatus == 'rechazado' 
                                ? Colors.red 
                                : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      )
                    ),
                    leading: Icon(
                      Icons.person, 
                      color: docStatus == 'aprobado' ? Colors.green : Colors.blue,
                    ),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Documentos de identidad:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...documents.entries.map((e) {
                            final title = e.key;
                            final url = e.value.toString();
                            
                            final isImage = title.toLowerCase().contains('foto') || 
                                            title.toLowerCase().contains('ine') || 
                                            title.toLowerCase().contains('ife') || 
                                            title.toLowerCase().contains('licencia');
                            
                            return ListTile(
                              leading: Icon(isImage ? Icons.image : Icons.picture_as_pdf),
                              title: Text(title),
                              subtitle: const Text('Toca para abrir el documento'),
                              trailing: const Icon(Icons.visibility, size: 18),
                              onTap: () {
                                if (url.startsWith('http')) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VerDocumentoScreen(
                                        title: title,
                                        url: url,
                                      ),
                                    ),
                                  );
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('URL del documento no válida')),
                                    );
                                  }
                                }
                              },
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: docStatus == 'rechazado' 
                                      ? null 
                                      : () async {
                                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                            'documentStatus': 'rechazado',
                                            'isVerified': false,
                                          });

                                          // Enviar Notificación al usuario
                                          await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
                                            'title': 'Documentos Rechazados',
                                            'body': 'Hubo un problema al validar tu INE, Licencia o Comprobante. Por favor vuelve a subirlos.',
                                            'type': 'status_update',
                                            'isRead': false,
                                            'createdAt': FieldValue.serverTimestamp(),
                                            'referenceId': userId,
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documentos rechazados')));
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rechazar'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: docStatus == 'aprobado' 
                                      ? null 
                                      : () async {
                                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                            'documentStatus': 'aprobado',
                                            'isVerified': true,
                                          });

                                          // Enviar Notificación al usuario
                                          await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
                                            'title': 'Documentos Aprobados',
                                            'body': '¡Felicidades! Se han validado con éxito tu INE, Licencia y Comprobante. Ya estás listo para rentar.',
                                            'type': 'status_update',
                                            'isRead': false,
                                            'createdAt': FieldValue.serverTimestamp(),
                                            'referenceId': userId,
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documentos aprobados')));
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Aprobar'),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
            },
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 4. PESTANA: SUBIR CONTRATO GLOBAL
// ----------------------------------------------------------------------
class ContratoAdminTab extends StatefulWidget {
  const ContratoAdminTab({super.key});

  @override
  State<ContratoAdminTab> createState() => _ContratoAdminTabState();
}

class _ContratoAdminTabState extends State<ContratoAdminTab> {
  bool _isUploading = false;
  String? _currentContractUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentContract();
  }

  Future<void> _checkCurrentContract() async {
    try {
      final url = await FirebaseStorage.instance
          .ref('global_contracts/contracto_global.pdf')
          .getDownloadURL();
      if (mounted) {
        setState(() {
          _currentContractUrl = url;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentContractUrl = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadContract() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      if (!mounted) return;
      setState(() => _isUploading = true);

      final ref = FirebaseStorage.instance
          .ref('global_contracts/contracto_global.pdf');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _currentContractUrl = url;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrato subido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir contrato: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContract() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Contrato'),
        content: const Text('¿Estás seguro de eliminar el contrato actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseStorage.instance
          .ref('global_contracts/contracto_global.pdf')
          .delete();
      if (mounted) {
        setState(() => _currentContractUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrato eliminado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contrato Global',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Este contrato se mostrara a los arrendadores al momento de aceptar una solicitud de renta.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _currentContractUrl != null
                        ? Icons.check_circle
                        : Icons.article_outlined,
                    size: 64,
                    color: _currentContractUrl != null
                        ? Colors.green
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentContractUrl != null
                        ? 'Contrato actual cargado'
                        : 'No hay contrato cargado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _currentContractUrl != null
                          ? Colors.green[800]
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentContractUrl != null
                        ? 'Los arrendadores podran ver e imprimir el contrato.'
                        : 'Sube un PDF para que los arrendadores puedan ver el contrato.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadContract,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _isUploading
                    ? 'Subiendo...'
                    : _currentContractUrl != null
                        ? 'Actualizar Contrato'
                        : 'Subir Contrato (PDF)',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_currentContractUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _deleteContract,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Eliminar Contrato',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
