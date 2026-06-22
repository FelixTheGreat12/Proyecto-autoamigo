import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalificarViajeScreen extends StatefulWidget {
  final String rentalId;
  final String targetUserId;
  final String role; // 'owner' o 'tenant'

  const CalificarViajeScreen({
    super.key,
    required this.rentalId,
    required this.targetUserId,
    required this.role,
  });

  @override
  State<CalificarViajeScreen> createState() => _CalificarViajeScreenState();
}

class _CalificarViajeScreenState extends State<CalificarViajeScreen> {
  int _rating = 0;
  bool _isSubmitting = false;
  final TextEditingController _reviewController = TextEditingController();

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      
      // Obtener el nombre del usuario actual (el que hace la reseña)
      final currentUserDoc = await db.collection('users').doc(currentUser.uid).get();
      final reviewerName = currentUserDoc.data()?['fullName'] ?? 'Usuario AutoAmigo';

      // 1. Actualizar el documento de la renta para que la otra pantalla sepa que ya calificó
      final ratingField = widget.role == 'owner' ? 'ownerRating' : 'tenantRating';
      final reviewField = widget.role == 'owner' ? 'ownerReview' : 'tenantReview';
      
      await db.collection('rentals').doc(widget.rentalId).update({
        ratingField: _rating,
        reviewField: _reviewController.text.trim(),
      });

      // 2. Transacción atómica: Actualizar promedio global del usuario calificado
      final targetUserRef = db.collection('users').doc(widget.targetUserId);
      
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(targetUserRef);
        if (!snapshot.exists) return; // Por si el usuario fue borrado

        final data = snapshot.data()!;
        final int totalReviews = (data['totalReviews'] ?? 0) as int;
        final double currentAverage = ((data['averageRating'] ?? 0.0) as num).toDouble();

        final newTotal = totalReviews + 1;
        // Formula para recalcular el promedio dinámico
        final double newAverage = ((currentAverage * totalReviews) + _rating) / newTotal;

        transaction.update(targetUserRef, {
          'totalReviews': newTotal,
          'averageRating': newAverage,
        });
      });

      // 3. Crear el documento directo de la "reseña" dentro del usuario objetivo (Subcolección)
      await targetUserRef.collection('reviews').doc(widget.rentalId).set({
        'rating': _rating,
        'review': _reviewController.text.trim(),
        'reviewerId': currentUser.uid,
        'reviewerName': reviewerName,
        'rentalId': widget.rentalId,
        'roleEvaluated': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Crear notificación de nueva calificación
      await targetUserRef.collection('notifications').add({
        'title': 'Nueva Calificación Recibida',
        'body': '¡$reviewerName acaba de calificarte con $_rating estrellas!',
        'type': 'new_review',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': widget.rentalId,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reseña enviada y guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en la calificación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la calificación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Calificar Viaje'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(
              widget.role == 'owner' ? Icons.directions_car : Icons.person,
              size: 80,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 24),
            Text(
              widget.role == 'owner'
                  ? '¿Cómo calificarías al dueño y al auto?'
                  : '¿Cómo calificarías al arrendatario?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 30),
            // Estrellas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  iconSize: 48,
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                );
              }),
            ),
            const SizedBox(height: 30),
            // Reseña
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Escribe una reseña (Opcional):',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 5,                enabled: !_isSubmitting,              decoration: InputDecoration(
                hintText: 'Cuéntanos cómo te fue en el viaje...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_rating > 0 && !_isSubmitting) ? _submitRating : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enviar Calificación',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}