import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../widgets/car_image_loader.dart';
import 'resenas_usuario_screen.dart';

class RentarAutoScreen extends StatelessWidget {
  final String autoId;
  final Map<String, dynamic> carData;
  final double pricePerDay;

  const RentarAutoScreen({
    super.key,
    required this.autoId,
    required this.carData,
    required this.pricePerDay,
  });

  // Obtiene datos del dueño
  Future<Map<String, dynamic>?> _getOwnerData() async {
    try {
      final ownerId = carData['userId'] as String?;
      if (ownerId == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();

      return doc.data();
    } catch (e) {
      debugPrint('Error getting owner data: $e');
      return null;
    }
  }

  Future<void> _solicitarRenta(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
    double total,
    String paymentMethod, {
    String? paymentIntentId,
    double? securityDepositAmount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para rentar')),
      );
      return;
    }

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Crear solicitud en Firestore
      final docRef = await FirebaseFirestore.instance.collection('rentals').add({
        'autoId': autoId,
        'tenantId': user.uid,
        'ownerId': carData['userId'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'pricePerDay': pricePerDay,
        'estimatedTotal': total,
        'securityDeposit': securityDepositAmount ?? 1500.0,
        'paymentMethod': paymentMethod,
        'stripePaymentIntentId': paymentIntentId,
        'kmLimit': carData['kmLimit'] ?? 500.0,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'carBrand': carData['brand'],
        'carModel': carData['model'],
        'carYear': carData['year'],
        'carColor': carData['color'],
      });

      // Crear notificación para el dueño
      await FirebaseFirestore.instance
          .collection('users')
          .doc(carData['userId'])
          .collection('notifications')
          .add({
        'title': 'Nueva Solicitud de Renta',
        'body': 'Han solicitado rentar tu ${carData['brand']} ${carData['model']}.',
        'type': 'rental_request',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': docRef.id,
      });

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de renta enviada con éxito'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Regresar al Home
        Navigator.pop(context);
        Navigator.pop(context); // Cerrar el bottomsheet de checkout
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading si falla

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar renta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPriceRow(String label, String value, {bool isFee = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isFee ? Colors.grey[700] : Colors.black87,
                  ),
                ),
              ),
              if (isFee) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isFee ? Colors.grey[700] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _iniciarPagoStripe(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
    double totalWithDeposit,
  ) async {
    try {
      // 1. Mostrar un loader mientras preparamos el pago
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // 2. Leer el depósito de seguridad para guardarlo
      double securityDepositAmount = 1500.0;
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('variables')
            .get();
        if (settingsDoc.exists) {
          securityDepositAmount = (settingsDoc.data()?['securityDeposit'] ?? 1500).toDouble();
        }
      } catch (_) {}

      // 3. Llamar a la Cloud Function para crear el Payment Intent
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createPaymentIntent');

      final result = await callable.call({
        'amount': totalWithDeposit,
        'currency': 'mxn',
        'ownerId': carData['userId'],
      });

      final String clientSecret = result.data['clientSecret'];
      final String paymentIntentId = result.data['paymentIntentId'];

      // 3. Ocultar el loader superior
      if (context.mounted) {
        Navigator.pop(context);
      }

      // 4. Configurar la hoja de pagos de Stripe (PaymentSheet)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'AutoAmigo',
          style: ThemeMode.light, // Puedes usar dark si es necesario
        ),
      );

      // 5. Presentar el formulario de pago y esperar confirmación
      await Stripe.instance.presentPaymentSheet();

      // 6. ¡Éxito! El cobro se procesó al inicio. Proceder con la solicitud de renta.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago pre-autorizado. Registrando solicitud...'),
            backgroundColor: Colors.green,
          ),
        );
        // Terminamos de generar el viaje en Firestore guardando el paymentIntentId
        await _solicitarRenta(
          context,
          startDate,
          endDate,
          totalWithDeposit,
          'Tarjeta',
          paymentIntentId: paymentIntentId,
          securityDepositAmount: securityDepositAmount,
        );
      }

    } on StripeException catch (e) {
      if (context.mounted) {
        // En caso de que se aborte la PaymentSheet y ya tuviésemos el loading abierto,
        // no pasa nada, ya se cerró arriba. Si hay error en Stripe:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pago cancelado o fallido (${e.error.localizedMessage})'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Si el loading seguía activo, cerrarlo
        // A veces falla la CF y el loader sigue
        Navigator.of(context, rootNavigator: true).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error interno en el cobro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarCheckoutFront(BuildContext context) async {
    // 0. Leer el depósito de seguridad desde system_settings
    double securityDeposit = 1500.0;
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('variables')
          .get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        securityDeposit = (data?['securityDeposit'] ?? 1500).toDouble();
      }
    } catch (e) {
      debugPrint('Error reading securityDeposit: $e');
    }

    // 1. Mostrar selector de fechas
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona las fechas de renta',
      cancelText: 'CERRAR',
      confirmText: 'CONTINUAR',
      saveText: 'LISTO',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return; // El usuario canceló la selección de fechas

    // 2. Calcular días iniciales
    final int days =
        picked.end.difference(picked.start).inDays +
        1; // +1 si rentar hoy y devolver hoy es 1 día

    String metodoPago = 'Efectivo';

    // Función auxiliar para meses
    String obtenerMes(int mes) {
      const meses = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return meses[mes - 1];
    }

    // 3. Mostrar BottomSheet interactivo como Checkout
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Cálculo de tarifa por días
            final double baseCost = pricePerDay * days;
            final double comisionAutoAmigo =
                baseCost * 0.20; // 20% de comisión
            final double totalRenta =
                baseCost + comisionAutoAmigo;
            final double totalWithDeposit =
                totalRenta + securityDeposit;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom:
                    MediaQuery.of(bottomSheetContext).padding.bottom +
                    MediaQuery.of(bottomSheetContext).viewInsets.bottom +
                    24, // Área segura inferior y teclado
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manija superior
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Título y Cerrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confirma tu renta',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Fechas en tarjetas llamativas
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.blue[800],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ENTREGA',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${picked.start.day} ${obtenerMes(picked.start.month)} ${picked.start.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      size: 16,
                                      color: Colors.blue[800],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'DEVOLUCIÓN',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${picked.end.day} ${obtenerMes(picked.end.month)} ${picked.end.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Desglose de pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Desglose de precios
                    _buildPriceRow(
                      'Tarifa diaria ($days días)',
                      '\$${baseCost.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 12),
                    _buildPriceRow(
                      'Comisión por uso (20%)',
                      '\$${comisionAutoAmigo.toStringAsFixed(2)}',
                      isFee: true,
                    ),
                    const SizedBox(height: 12),
                    _buildPriceRow(
                      'Depósito seguridad',
                      '\$${securityDeposit.toStringAsFixed(2)}',
                      isFee: true,
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Total a Retener',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '\$${totalWithDeposit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '* El depósito de seguridad se retiene y se devuelve al finalizar el viaje sin daños.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Método de pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Row(
                              children: [
                                Icon(Icons.money, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Efectivo'),
                              ],
                            ),
                            value: 'Efectivo',
                            groupValue: metodoPago,
                            onChanged: (val) {
                              if (val != null) setState(() => metodoPago = val);
                            },
                            activeColor: const Color(0xFF1565C0),
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: const Row(
                              children: [
                                Icon(Icons.credit_card, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Tarjeta'),
                              ],
                            ),
                            value: 'Tarjeta',
                            groupValue: metodoPago,
                            onChanged: (val) {
                              if (val != null) setState(() => metodoPago = val);
                            },
                            activeColor: const Color(0xFF1565C0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (metodoPago == 'Tarjeta') {
                            await _iniciarPagoStripe(
                              context,
                              picked.start,
                              picked.end,
                              totalWithDeposit,
                            );
                          } else {
                            _solicitarRenta(
                              context,
                              picked.start,
                              picked.end,
                              totalRenta,
                              metodoPago,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Confirmar y Solicitar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = carData['brand'] ?? 'N/A';
    final model = carData['model'] ?? 'N/A';
    final year = carData['year'] ?? 'N/A';
    final color = carData['color'] ?? 'N/A';
    final transmission = carData['transmission'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // 1. GALERÍA DE IMÁGENES (CARRUSEL)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Stack(
              children: [
                CarImageLoader(autoId: autoId, fit: BoxFit.cover),
              ],
            ),
          ),

          // Gradiente oscuro para que se vean los iconos blancos
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Botón de regreso
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. CONTENIDO SCROLLABLE CON TARJETA FLOTANTE
          Positioned.fill(
            top: 220, // Subido de 280
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TÍTULO Y PRECIO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$brand $model',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF263238),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  year.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$$pricePerDay',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            Text(
                              'MXN / día',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // PERFIL DEL DUEÑO
                    const Text(
                      'Propietario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getOwnerData(),
                      builder: (context, snapshot) {
                        final ownerData = snapshot.data;
                        // Corrección: Usar 'fullName' que es como se guarda en el registro
                        final fullName =
                            ownerData?['fullName'] as String? ??
                            'Usuario AutoAmigo';

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildOwnerSkeleton();
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(carData['userId'])
                              .collection('reviews')
                              .where('roleEvaluated', isEqualTo: 'owner')
                              .snapshots(),
                          builder: (context, reviewSnapshot) {
                            double average = 0.0;
                            int total = 0;
                            if (reviewSnapshot.hasData) {
                              final docs = reviewSnapshot.data!.docs;
                              total = docs.length;
                              if (total > 0) {
                                double sum = 0;
                                for (var doc in docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  sum += (data['rating'] as num?)?.toDouble() ?? 0.0;
                                }
                                average = sum / total;
                              }
                            }
                            final String displayRating = total > 0 ? average.toStringAsFixed(1) : 'Nuevo';
                            final String reviewsText = total > 0 ? ' ($total reseñas)' : '';

                            return InkWell(
                              onTap: () {
                                if (ownerData != null && carData['userId'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResenasUsuarioScreen(
                                        userId: carData['userId'],
                                        role: 'owner',
                                      ),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Avatar Owner
                                    Container(
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue[100],
                                        image: const DecorationImage(
                                          // Placeholder image de perfil
                                          image: NetworkImage(
                                            'https://i.pravatar.cc/150?img=11',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Info Owner
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName.isNotEmpty
                                                ? fullName
                                                : 'Cargando...',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF263238),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Colors.amber,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                displayRating,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                reviewsText,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // CARACTERÍSTICAS GRID
                    const Text(
                      'Características del Auto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFeatureCard(
                          Icons.calendar_today,
                          'Año',
                          year.toString(),
                        ),
                        _buildFeatureCard(
                          Icons.speed,
                          'Transmisión',
                          transmission,
                        ),
                        _buildFeatureCard(
                          Icons.palette_outlined,
                          'Color',
                          color,
                        ),
                        _buildFeatureCard(
                          Icons.local_gas_station_outlined,
                          'Combustible',
                          'Gasolina',
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // DESCRIPCIÓN
                    const Text(
                      'Descripción del Propietario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este auto se encuentra en excelentes condiciones mecánicas y estéticas. Ideal para viajes largos o uso diario en la ciudad. Cuenta con seguro vigente y todos los servicios al día.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // BOTÓN FLOTANTE INFERIOR
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: carData['status'] == 'ocupado'
                    ? null // Deshabilitado si está ocupado
                    : () => _mostrarCheckoutFront(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: carData['status'] == 'ocupado'
                      ? Colors.grey[400]
                      : const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: carData['status'] == 'ocupado' ? 0 : 5,
                  shadowColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
                ),
                child: Text(
                  carData['status'] == 'ocupado'
                      ? 'Auto Ocupado'
                      : 'Solicitar Renta ahora',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 16, color: Colors.grey[200]),
              const SizedBox(height: 8),
              Container(width: 80, height: 14, color: Colors.grey[200]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA), // Gris muy muy claro
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 24),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
