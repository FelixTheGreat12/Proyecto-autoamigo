import 'package:autoamigo/auth/auth_service.dart';
import 'package:flutter/material.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0; // Para controlar el ítem seleccionado en la barra inferior

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Aquí puedes añadir la lógica para navegar a otras pantallas
    // basadas en el índice seleccionado. Por ahora, solo cambia el estado.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menú de Inicio'),
        automaticallyImplyLeading: false, // Oculta la flecha de retroceso
        elevation: 1,
        actions: [
          // Botón de Logout (Cerrar Sesión)
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        // GridView para mostrar las opciones del menú
        child: GridView.count(
          crossAxisCount: 3, // 3 columnas
          crossAxisSpacing: 12, // Espacio horizontal entre ítems
          mainAxisSpacing: 12,  // Espacio vertical entre ítems
          children: <Widget>[
            // Aquí creamos cada uno de los botones del menú
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Arrendatario',
              subtitle: 'Documentos',
            ),
            _buildMenuItem(
              icon: Icons.business_center_outlined,
              title: 'Arrendador',
              subtitle: 'Documentos',
            ),
            _buildMenuItem(
              icon: Icons.payment_outlined,
              title: 'Forma de pago',
              subtitle: 'Updated 2 days ago',
            ),
            _buildMenuItem(
              icon: Icons.directions_car_outlined,
              title: 'Mis Autos',
              subtitle: 'Updated today',
              onTap: () => Navigator.pushNamed(context, '/mis_autos'),
            ),
            _buildMenuItem(
              icon: Icons.history_outlined,
              title: 'Historial',
              subtitle: 'Updated yesterday',
            ),
            _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              subtitle: 'Updated 2 days ago',
            ),
             _buildMenuItem(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Updated today',
            ),
             _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Ayuda',
              subtitle: 'Updated yesterday',
            ),
          ],
        ),
      ),
      // Barra de Navegación Inferior
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            label: 'Rentar Auto',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.publish_outlined),
            label: 'Publicar Autos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            label: 'Localizar Autos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800], // Color del ítem activo
        unselectedItemColor: Colors.grey[600], // Color de los ítems inactivos
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Mantiene el layout fijo
      ),
    );
  }

  /// Widget auxiliar para crear cada ítem del menú y evitar repetir código.
  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          // Lógica por defecto para cuando se presiona un ítem del menú
          print('$title presionado');
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 28.0, color: Colors.grey[700]),
            SizedBox(height: 5.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.0,
              ),
            ),
            SizedBox(height: 2.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.0,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}