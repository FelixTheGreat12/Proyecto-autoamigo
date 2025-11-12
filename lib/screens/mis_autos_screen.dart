import 'package:flutter/material.dart';

class MisAutosScreen extends StatelessWidget {
  const MisAutosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Autos'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navegar a la pantalla de cotizar (solo interfaz)
              Navigator.pushNamed(context, '/cotizar_auto');
            },
          ),
        ],
      ),
      backgroundColor: Colors.pink[50],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: ListView.separated(
          itemCount: 12,
          separatorBuilder: (context, index) => SizedBox(height: 8),
          itemBuilder: (context, index) {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple[100],
                  child: Text(
                    'A',
                    style: TextStyle(color: Colors.deepPurple[800]),
                  ),
                ),
                title: Text('List item'),
                subtitle: Text('Descripción breve del auto'),
                onTap: () {
                  // Interfaz solamente: no navegar
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomItem(Icons.star_border, 'Rentar Auto'),
              _bottomItem(Icons.publish_outlined, 'Publicar Autos'),
              _bottomItem(Icons.location_on_outlined, 'Localizar Autos'),
              _bottomItem(Icons.person_outline, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }
}
