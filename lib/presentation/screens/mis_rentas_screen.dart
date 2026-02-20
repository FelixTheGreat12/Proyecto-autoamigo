import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_renta_arrendatario_screen.dart';

class MisRentasScreen extends StatelessWidget {
  const MisRentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Rentas')),
        body: const Center(child: Text('Usuario no autenticado')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Mis Rentas',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .where('tenantId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             // Handle "FAILED_PRECONDITION" (missing index) gracefully-ish
             // Usually developer needs to click the link in logs.
             if(snapshot.error.toString().contains('failed-precondition')) {
               return const Center(child: Text('Falta índice en Firestore. Revisa la consola.'));
             }
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rentas = snapshot.data?.docs ?? [];

          if (rentas.isEmpty) {
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
                      Icons.key_rounded,
                      size: 64,
                      color: Colors.blue[300],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No tienes rentas activas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Busca un auto y solicítalo',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rentas.length,
            itemBuilder: (context, index) {
              final rental = rentas[index].data() as Map<String, dynamic>;
              final rentalId = rentas[index].id;
              
              final carBrand = rental['carBrand'] ?? 'Auto';
              final carModel = rental['carModel'] ?? '';
              final status = rental['status'] ?? 'pending';
              final ownerId = rental['ownerId'] ?? '';
              final price = rental['pricePerDay'] ?? 0;
              final timestamp = rental['createdAt'] as Timestamp?;
              final dateStr = timestamp != null 
                  ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}" 
                  : "Fecha desc.";

              return GestureDetector(
                onTap: () {
                  if (status == 'approved') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalleRentaArrendatarioScreen(
                          rentalId: rentalId,
                          ownerId: ownerId,
                          rentalData: rental,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(status == 'rejected' 
                          ? 'Esta solicitud fue rechazada.' 
                          : 'Espera a que el dueño apruebe la solicitud.'),
                        backgroundColor: status == 'rejected' ? Colors.red : Colors.orange,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                      // Icono o Imagen pequeña (Placeholder por simplicidad si no guardamos URL)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.directions_car, color: Colors.blue[800], size: 30),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$carBrand $carModel',
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF263238),
                              ),
                            ),
                            const SizedBox(height: 4),
                             Text(
                              '\$$price MXN / día',
                              style: const TextStyle(
                                fontSize: 14, 
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Solicitado: $dateStr',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      _buildStatusBadge(status),
                    ],
                  ),
                ),
              ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        text = 'Aprobado';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Rechazado';
        icon = Icons.cancel_outlined;
        break;
      case 'pending':
      default:
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        text = 'En espera';
        icon = Icons.hourglass_empty;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
