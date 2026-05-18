import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StarRatingWidget extends StatefulWidget {
  final String rentalId;
  final String targetUserId; // userId of the person being rated
  final String role; // 'owner' or 'tenant' (indicates who is being rated)
  final String label;
  final VoidCallback? onSubmitted;

  const StarRatingWidget({
    super.key,
    required this.rentalId,
    required this.targetUserId,
    required this.role,
    required this.label,
    this.onSubmitted,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  int _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Update the rental document so we know it has been rated
      final ratingField = widget.role == 'owner' ? 'ownerRating' : 'tenantRating';
      await db.collection('rentals').doc(widget.rentalId).update({
        ratingField: _rating,
      });

      // 2. Update the target user's average rating
      final userRef = db.collection('users').doc(widget.targetUserId);
      
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return; // User might have been deleted

        final data = snapshot.data()!;
        final int totalReviews = (data['totalReviews'] ?? 0) as int;
        final double currentAverage = ((data['averageRating'] ?? 0.0) as num).toDouble();

        final newTotal = totalReviews + 1;
        // Formula to recalculate average:
        // newAvg = ((oldAvg * oldTotal) + newRating) / newTotal
        final double newAverage = ((currentAverage * totalReviews) + _rating) / newTotal;

        transaction.update(userRef, {
          'totalReviews': newTotal,
          'averageRating': newAverage,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificación enviada exitosamente')),
        );
        if (widget.onSubmitted != null) {
          widget.onSubmitted!();
        }
      }

    } catch (e) {
      debugPrint('Error en la calificación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar la calificación')),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF263238),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
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
          if (_rating > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Enviar Calificación', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }
}