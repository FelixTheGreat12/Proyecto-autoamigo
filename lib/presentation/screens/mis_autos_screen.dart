import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Asegúrate de importar tu pantalla de producto
import 'product_car_screen.dart';

class MisAutosScreen extends StatelessWidget {
  const MisAutosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Autos')),
        body: const Center(child: Text('Usuario no autenticado')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Mis Autos',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF1565C0),
              size: 28,
            ),
            tooltip: 'Agregar auto',
            onPressed: () {
              Navigator.pushNamed(context, '/cotizar_auto');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('autos')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final autos = snapshot.data?.docs ?? [];

          if (autos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: Colors.blue[300],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No tienes autos registrados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comienza cotizando tu primer vehículo',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/cotizar_auto'),
                    icon: const Icon(Icons.add),
                    label: const Text('Cotizar ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: autos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final docSnapshot = autos[index];
              final autoData = docSnapshot.data() as Map<String, dynamic>;
              final autoId = docSnapshot.id;

              final brand = autoData['brand'] ?? 'Marca desconocida';
              final model = autoData['model'] ?? 'Modelo desconocido';
              final year = autoData['year'] ?? 'Año desconocido';
              final status = autoData['status'] ?? 'borrador';

              // Color del icono según la marca (simple hash o random consistente)
              final iconColor =
                  Colors.primaries[brand.hashCode % Colors.primaries.length];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductCarScreen(
                            autoId: autoId,
                            carData: autoData,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                brand.isNotEmpty ? brand[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  color: iconColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$brand $model',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF263238),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$year',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'registrado'
                                            ? Colors.green[50]
                                            : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: status == 'registrado'
                                              ? Colors.green[200]!
                                              : Colors.orange[200]!,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        status == 'registrado'
                                            ? 'Registrado'
                                            : 'Borrador',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: status == 'registrado'
                                              ? Colors.green[700]
                                              : Colors.orange[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
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
          currentIndex:
              1, // Resaltamos "Cotizar" o similar, ya que estamos en gestión
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.grey[800],
          unselectedItemColor: Colors.grey[600],
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            if (index == 0) {
              Navigator.popUntil(context, ModalRoute.withName('/'));
            }
            // Otros casos...
          },
        ),
      ),
    );
  }
}
