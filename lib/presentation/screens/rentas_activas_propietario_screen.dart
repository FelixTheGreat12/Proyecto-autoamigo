import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'detalle_solicitud_screen.dart';

class RentasActivasPropietarioScreen extends StatelessWidget {
  const RentasActivasPropietarioScreen({super.key});

  // Función para obtener el nombre del inquilino
  Future<String> _getTenantName(String tenantId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(tenantId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // Intenta obtener nombre y apellido, o firstName/lastName, o name
        // Ajusta esto según cómo guardes los usuarios en auth_service.dart
        // En RegisterScreen vemos que se guarda como 'fullName'
        String fullName = data['fullName'] ?? '';

        if (fullName.isNotEmpty) {
          return fullName;
        }

        // Fallbacks antiguos por si acaso
        String nombre = data['nombre'] ?? data['firstName'] ?? '';
        String apellido = data['apellido'] ?? data['lastName'] ?? '';

        if (nombre.isNotEmpty) {
          return '$nombre $apellido'.trim();
        }
        return data['email'] ?? 'Usuario desconocido';
      }
    } catch (e) {
      debugPrint('Error getting tenant name: $e');
    }
    return 'Usuario desconocido';
  }

  // Actualizar estado de la solicitud
  Future<void> _updateStatus(
    BuildContext context,
    String rentalId,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(rentalId)
          .update({'status': newStatus});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'Solicitud aceptada'
                  : 'Solicitud rechazada',
            ),
            backgroundColor: newStatus == 'approved'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitudes')),
        body: const Center(child: Text('Sesión no iniciada')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Rentadas y Solicitudes',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .where('ownerId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('failed-precondition')) {
              return const Center(
                child: Text(
                  'Falta índice. Revisa la consola y crea el índice compuesto.',
                ),
              );
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtramos localmente los estados activos
          final allDocs = snapshot.data?.docs ?? [];
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            return ['pending', 'approved', 'in_progress', 'ocupado', 'en_curso'].contains(status);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes solicitudes ni rentas activas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final rentalId = docs[index].id;
              final data = docs[index].data() as Map<String, dynamic>;

              final tenantId = data['tenantId'] ?? '';
              final carBrand = data['carBrand'] ?? '';
              final carModel = data['carModel'] ?? '';
              final status = data['status'] ?? 'pending';
              final price = data['pricePerKm'] ?? data['pricePerDay'] ?? 0;
              final timestamp = data['createdAt'] as Timestamp?;
              final dateStr = timestamp != null
                  ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
                  : "Fecha desconocida";

              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalleSolicitudScreen(
                          rentalId: rentalId,
                          tenantId: tenantId,
                          rentalData: data,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FutureBuilder<String>(
                              future: _getTenantName(tenantId),
                              builder: (context, snapshot) {
                                final name = snapshot.data ?? 'Cargando...';
                                final initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?';

                                return CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                    future: _getTenantName(tenantId),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? 'Cargando usuario...',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    'Interesado en: $carBrand $carModel',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Detalles
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Solicitado: $dateStr',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '\$$price',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botones eliminados por solicitud
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
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'approved':
        bg = Colors.green[100]!;
        text = Colors.green[800]!;
        label = 'Aprobada';
        break;
      case 'rejected':
        bg = Colors.red[100]!;
        text = Colors.red[800]!;
        label = 'Rechazada';
        break;
      case 'pending':
        bg = Colors.orange[100]!;
        text = Colors.orange[800]!;
        label = 'Pendiente';
        break;
      default:
        bg = Colors.grey[200]!;
        text = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
