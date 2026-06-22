import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'detalle_solicitud_screen.dart';
import 'detalle_renta_arrendatario_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final unreadQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadQuery.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'rental_request':
        return Icons.car_rental;
      case 'status_update':
        return Icons.info_outline;
      case 'new_review':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'rental_request':
        return Colors.blue;
      case 'status_update':
        return Colors.amber.shade800;
      case 'new_review':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }
  }

  Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> data, String notificationId) async {
    // Marcar como leída
    if (!(data['isRead'] ?? false)) {
      await _markAsRead(notificationId);
    }

    final referenceId = data['referenceId'] as String?;
    final type = data['type'] as String?;

    if (referenceId == null || !context.mounted) return;

    // Aquí podrías agregar navegación condicional si lo deseas.
    // Por ejemplo, buscar el doc en 'rentals' para ver si es owner o tenant.
    try {
      final rentalDoc = await FirebaseFirestore.instance.collection('rentals').doc(referenceId).get();
      if (rentalDoc.exists && context.mounted) {
        final user = FirebaseAuth.instance.currentUser;
        final rentalData = rentalDoc.data()!;

        if (user?.uid == rentalData['ownerId']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleSolicitudScreen(
                rentalId: referenceId,
                tenantId: rentalData['tenantId'],
                rentalData: rentalData,
              ),
            ),
          );
        } else if (user?.uid == rentalData['tenantId']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleRentaArrendatarioScreen(
                rentalId: referenceId,
                ownerId: rentalData['ownerId'],
                rentalData: rentalData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error opening notification reference: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar advertencias'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Sin notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final isRead = data['isRead'] ?? false;
              final title = data['title'] ?? 'Notificación';
              final body = data['body'] ?? '';
              final type = data['type'] ?? 'info';
              
              final timestamp = data['createdAt'] as Timestamp?;
              final timeStr = timestamp != null
                  ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
                  : "";

              return Card(
                elevation: isRead ? 0 : 2,
                color: isRead ? Colors.white : Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isRead ? Colors.grey.shade200 : Colors.blue.shade200),
                ),
                child: InkWell(
                  onTap: () => _handleNotificationTap(context, data, doc.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: _getColorForType(type).withOpacity(0.2),
                          child: Icon(_getIconForType(type), color: _getColorForType(type)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 16,
                                        color: const Color(0xFF263238),
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}