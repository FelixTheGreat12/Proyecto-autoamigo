import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResenasUsuarioScreen extends StatelessWidget {
  final String userId;
  final String role; // 'owner' o 'tenant', para saber el título

  const ResenasUsuarioScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = role == 'owner';
    final titleRole = isOwner ? 'Propietario' : 'Arrendatario';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Perfil del $titleRole'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleRole,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 16),
            
              // StreamBuilder general para calcular las calificaciones y mostrar estadísticas
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('reviews')
                    .where('roleEvaluated', isEqualTo: role)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, reviewsSnapshot) {
                  if (reviewsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                    );
                  }

                  if (reviewsSnapshot.hasError) {
                    return Center(
                      child: Text('Ocurrió un error cargando las reseñas',
                          style: TextStyle(color: Colors.red[800])),
                    );
                  }

                  final docs = reviewsSnapshot.data?.docs ?? [];
                  
                  // Calcular promedio y conteo de estrellas
                  int totalReviews = docs.length;
                  double sumRatings = 0;
                  List<int> starCounts = [0, 0, 0, 0, 0, 0]; // [0, 1, 2, 3, 4, 5]

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    int r = (data['rating'] ?? 0) as int;
                    if (r < 0) r = 0;
                    if (r > 5) r = 5;
                    sumRatings += r;
                    starCounts[r]++;
                  }
                  
                  final double currentAverage = totalReviews > 0 ? sumRatings / totalReviews : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de Perfil modernizado
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                          final fullName = userData['fullName'] ?? 'Usuario';
                          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 4),
                                      ),
                                      child: CircleAvatar(
                                        radius: 45,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: const Icon(
                                          Icons.verified,
                                          color: Color(0xFF1565C0),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentAverage > 0 ? currentAverage.toStringAsFixed(1) : 'Nuevo',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '($totalReviews reseñas)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),

                      const SizedBox(height: 32),

                      if (totalReviews > 0) ...[
                        const Text(
                          'Resumen de Calificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Promedio grande
                              Column(
                                children: [
                                  Text(
                                    currentAverage.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF263238),
                                      height: 1.1,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < currentAverage.round() ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 24),
                              // Barras
                              Expanded(
                                child: Column(
                                  children: List.generate(5, (index) {
                                    int star = 5 - index;
                                    double percent = totalReviews > 0 ? starCounts[star] / totalReviews : 0.0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            '$star',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF546E7A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: percent,
                                                minHeight: 8,
                                                backgroundColor: Colors.grey.shade200,
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      const Text(
                        'Reseñas Recientes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (docs.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.speaker_notes_off_rounded, color: Color(0xFF1565C0), size: 48),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin reseñas aún',
                                style: TextStyle(
                                  color: Color(0xFF263238), 
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Este usuario todavía no ha recibido ninguna reseña.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final reviewData = docs[index].data() as Map<String, dynamic>;
                            return _buildReviewCard(reviewData);
                          },
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Reciente';
    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.inDays > 365) {
      return 'Hace ${difference.inDays ~/ 365} años';
    } else if (difference.inDays > 30) {
      return 'Hace ${difference.inDays ~/ 30} meses';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hrs';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} mins';
    } else {
      return 'Justo ahora';
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> reviewData) {
    final reviewerName = reviewData['reviewerName'] ?? 'Anónimo';
    final initial = reviewerName.toString().isNotEmpty ? reviewerName.toString()[0].toUpperCase() : '?';
    final int rating = (reviewData['rating'] ?? 0) as int;
    final reviewText = reviewData['review'] ?? '';
    final createdAt = reviewData['createdAt'] as Timestamp?;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE3F2FD),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              reviewText,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF455A64),
                height: 1.5,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
