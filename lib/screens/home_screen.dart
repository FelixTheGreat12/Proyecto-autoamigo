import 'package:autoamigo/auth/auth_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // --- LÓGICA DE NAVEGACIÓN ---
    switch (index) {
      case 0:
        // Ya estamos en Home (Rentar Auto)
        break;
      case 1:
        // Opción: Publicar Autos -> Ir a Cotizar
        Navigator.pushNamed(context, '/cotizar_auto');
        break;
      case 2:
        // Opción: Localizar Autos
        // Navigator.pushNamed(context, '/localizar'); // Pendiente
        break;
      case 3:
        // Opción: Perfil
        // Navigator.pushNamed(context, '/perfil'); // Pendiente
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () async {
                await _authService.signOut();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Cerrar sesión',
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de bienvenida
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
                  'Bienvenido',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '¿Qué deseas hacer hoy?',
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
          // Grid de opciones
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.count(
                crossAxisCount: 2, // 2 columnas para mejor visibilidad
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: <Widget>[
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
                    icon: Icons.person_outline,
                    title: 'Arrendatario',
                    subtitle: 'Mis documentos',
                    color: Colors.orangeAccent,
                  ),
                  _buildMenuItem(
                    icon: Icons.business_center_outlined,
                    title: 'Arrendador',
                    subtitle: 'Mis documentos',
                    color: Colors.teal,
                  ),
                  _buildMenuItem(
                    icon: Icons.payment_outlined,
                    title: 'Pagos',
                    subtitle: 'Métodos de pago',
                    color: Colors.green,
                  ),
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: 'Historial',
                    subtitle: 'Rentas pasadas',
                    color: Colors.purpleAccent,
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_active_outlined,
                    title: 'Avisos',
                    subtitle: 'Notificaciones',
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
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
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              label: 'Cotizar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              label: 'Localizar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
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
