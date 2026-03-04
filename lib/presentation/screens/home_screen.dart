import 'dart:math';
import 'package:autoamigo/infrastructure/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'buscar_auto_screen.dart';
import 'rentar_auto_screen.dart';
import 'subir_documentos_usuario_screen.dart';

import '../widgets/car_image_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // Actualizar la UI cuando cambia la pestaña para cambiar el BottomNav
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    final isArrendatario = _tabController.index == 0;

    // --- LÓGICA DE NAVEGACIÓN ---
    if (isArrendatario) {
      // ARRENDATARIO: [0: Buscar, 1: Mis Rentas]
      switch (index) {
        case 0: // Buscar
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BuscarAutoScreen()),
          );
          break;
        case 1: // Mis Rentas
           Navigator.pushNamed(context, '/mis_rentas');
           break;
      }
    } else {
      // ARRENDADOR: [0: Cotizar, 1: Solicitudes]
      switch (index) {
        case 0: // Cotizar
          Navigator.pushNamed(context, '/cotizar_auto');
          break;
        case 1: // Solicitudes
           Navigator.pushNamed(context, '/solicitudes_renta');
           break;
      }
    }
  }

  Stream<bool> _checkDocumentsMissing(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('documentos')
        .doc('documentos_info')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return true;
      final data = snapshot.data();
      if (data == null || !data.containsKey('documents')) return true;

      final docs = data['documents'] as Map<String, dynamic>;
      final hasIne = docs['INE / IFE'] != null && docs['INE / IFE'].toString().isNotEmpty;
      final hasLicencia = docs['Licencia'] != null && docs['Licencia'].toString().isNotEmpty;
      final hasComprobante = docs['Comprobante'] != null && docs['Comprobante'].toString().isNotEmpty;

      return !(hasIne && hasLicencia && hasComprobante);
    });
  }

  Widget _buildMissingDocumentsBanner() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _checkDocumentsMissing(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) return const SizedBox.shrink();
        
        // Si data es false, significa que NO faltan documentos (todo ok).
        // Si data es true, significa que SÍ faltan documentos.
        final areDocumentsMissing = snapshot.data!;
        
        if (!areDocumentsMissing) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            color: Colors.yellow[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.yellow[700]!, width: 1),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                   Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¡Acción Requerida!\nFaltan subir tus documentos (INE, Licencia, Comprobante).',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubirDocumentosUsuarioScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Subir Documentos Ahora'),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArrendatario = _tabController.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fondo gris azulado suave
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'AutoAmigo',
          style: TextStyle(
            color: Color(0xFF1565C0), // Azul corporativo
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/perfil');
              },
              icon: const Icon(Icons.person, color: Color(0xFF1565C0)),
              tooltip: 'Perfil',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1565C0),
          tabs: const [
            Tab(text: 'Arrendatario'),
            Tab(text: 'Arrendador'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña Arrendatario (Lista de autos disponibles)
          _buildTenantView(),

          // Pestaña Arrendador (Menú de gestión)
          _buildRoleView(
            roleTitle: 'Arrendador',
            roleSubtitle: 'Administra tu flota y ganancias',
            items: [
              _buildMenuItem(
                icon: Icons.directions_car_filled_outlined,
                title: 'Mis Autos',
                subtitle: 'Gestionar flota',
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pushNamed(context, '/mis_autos');
                },
              ),
              _buildMenuItem(
                icon: Icons.business_center_outlined,
                title: 'Mis doc.',
                subtitle: 'Documentos propietario',
                color: Colors.teal,
              ),
              _buildMenuItem(
                icon: Icons.analytics_outlined,
                title: 'Ganancias',
                subtitle: 'Reporte ingresos',
                color: Colors.green,
              ),
              _buildMenuItem(
                icon: Icons.history_rounded,
                title: 'Historial',
                subtitle: 'Rentas activas',
                color: Colors.purpleAccent,
              ),
              _buildMenuItem(
                icon: Icons.notifications_active_outlined,
                title: 'Avisos',
                subtitle: 'Solicitudes',
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            items: isArrendatario
              ? const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Buscar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.key),
                    label: 'Mis Rentas',
                  ),
                ]
              : const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline),
                    label: 'Cotizar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_alt_outlined),
                    label: 'Solicitudes',
                  ),
                ],
          currentIndex: _selectedIndex,
          backgroundColor: Colors.white,
          elevation: 0,
          // Mantenemos tu preferencia de no iluminar
          selectedItemColor: Colors.grey[800],
          unselectedItemColor: Colors.grey[600],
          showUnselectedLabels: true,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
        ),
        ),
      ),
    );
  }

  Widget _buildTenantView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de aviso de documentos faltantes
        _buildMissingDocumentsBanner(),

        // Banner de bienvenida ARRENDATARIO
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenido, Arrendatario',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Encuentra tu auto ideal',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Lista de Autos disponibles
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Filtramos solo los autos que ya completaron su registro
            stream: FirebaseFirestore.instance
                .collection('autos')
                .where('status', isEqualTo: 'registrado')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar autos'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filtramos localmente para excluir los autos del propio usuario
              final currentUserId =
                  AuthService().currentUser?.uid; // Obtener ID actual

              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Si el auto tiene dueño y es el mismo usuario actual, lo ocultamos
                return data['userId'] != currentUserId;
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay autos disponibles por ahora',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final autoId = docs[index].id;

                  // Datos básicos
                  final brand = data['brand'] ?? 'Marca desconocida';
                  final model = data['model'] ?? 'Modelo desconocido';
                  final year = data['year'] ?? '';

                  // Precio aleatorio (temporal)
                  // Usamos el hash del ID para que el precio sea fijo para cada auto
                  final random = Random(autoId.hashCode);
                  final price = 500 + random.nextInt(2000); // Entre 500 y 2500

                  // Intentamos sacar la URL de la imagen principal si existe en
                  // la subcolección 'documentos'. Como aquí no tenemos fácil acceso
                  // a la subcolección en una sola query, mostraremos un placeholder
                  // y cargaremos la imagen con un FutureBuilder interno si es necesario,
                  // o mejor aún, si guardaste la URL principal en el documento del auto.
                  
                  // NOTA: Para eficiencia, lo ideal sería guardar 'mainImageUrl'
                  // directamente en el documento 'autos/{id}' al subir los docs.
                  // Aquí simularemos con un FutureBuilder simple.

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        // Navegar a la pantalla de detalles para rentar
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RentarAutoScreen(
                              autoId: autoId,
                              carData: data,
                              price: price, // Pasar el precio calculado
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imagen del auto
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: CarImageLoader(
                              autoId: autoId,
                              fit: BoxFit.cover,
                            ),
                          ),
                          
                          // Información
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded( // <-- AGREGADO: Evita el overflow
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$brand $model $year',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF263238),
                                        ),
                                        maxLines: 1, // <-- AGREGADO: Limita a una línea
                                        overflow: TextOverflow.ellipsis, // <-- AGREGADO: Pone '...'
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Disponible ahora',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$$price MXN',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                    Text(
                                      'por día',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildRoleView({
    required String roleTitle,
    required String roleSubtitle,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de aviso de documentos faltantes
        _buildMissingDocumentsBanner(),
        
        // Banner de bienvenida específico por rol
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenido, $roleTitle',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roleSubtitle,
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Grid de opciones
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: items,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.0),
      elevation: 0, // Flat design con sombra suave
      child: InkWell(
        onTap: onTap ??
            () {
              print('$title presionado');
            },
        borderRadius: BorderRadius.circular(20.0),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28.0, color: color),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                    color: Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
