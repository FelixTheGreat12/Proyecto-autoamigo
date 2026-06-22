const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Inicializamos el SDK de Firebase Admin para interactuar con Firestore y Messaging
admin.initializeApp();

// Definimos el secreto de Stripe
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

// Limitamos las instancias para evitar cobros sorpresa (buena práctica)
setGlobalOptions({ maxInstances: 10 });

/**
 * Endpoint para generar el PaymentIntent (Intención de Pago) de Stripe.
 * Este backend crea el secreto seguro que la app de Flutter necesita para mostrar
 * la pasarela de pagos, garantizando que nadie pueda manipular el monto de cobro.
 */
exports.createPaymentIntent = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  // 1. Verificamos que el usuario esté autenticado (Medida de seguridad fuerte)
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para realizar un pago."
    );
  }

  try {
    const stripe = require("stripe")(stripeSecretKey.value());
    const { amount, currency, ownerId } = request.data;
    const amountInCents = Math.round(amount * 100);

    // 2. Creamos la intención de cobro con captura manual (Pre-autorización)
    const payload = {
      amount: amountInCents, // Convertimos el flotante a entero
      currency: currency || "mxn",
      capture_method: "manual", // Retiene el dinero en la tarjeta sin cobrarlo todavía
      metadata: {
        userId: request.auth.uid,
      },
    };

    // Si tenemos al dueño, buscamos su cuenta conectada de Stripe
    // (Comentado temporalmente por restricciones de Stripe Connect)
    /*
    if (ownerId) {
      const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (ownerDoc.exists && ownerDoc.data().stripeAccountId) {
        payload.transfer_data = {
          destination: ownerDoc.data().stripeAccountId,
        };
        // Comisión de plataforma del 20% en pago inmediato
        payload.application_fee_amount = Math.round(amountInCents * 0.20);
      }
    }
    */

    const paymentIntent = await stripe.paymentIntents.create(payload);

    // 3. Devolvemos el "clientSecret" y el "ID" que Flutter usará y guardará
    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    };
  } catch (error) {
    logger.error("Error al crear PaymentIntent:", error);
    throw new HttpsError("internal", "No se pudo iniciar el proceso de pago.");
  }
});

/**
 * Endpoint para CAPTURAR (Cobrar) el monto final exacto de un PaymentIntent retenido
 * al finalizar un viaje. Esto liberará automáticamente la diferencia sobrante.
 */
exports.capturePayment = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión para cobrar.");
  }

  const { paymentIntentId, finalAmount, ownerId } = request.data;

  if (!paymentIntentId || !finalAmount) {
    throw new HttpsError("invalid-argument", "Falta el paymentIntentId o el finalAmount.");
  }

  try {
    const stripe = require("stripe")(stripeSecretKey.value());
    const finalAmountInCents = Math.round(finalAmount * 100);
    logger.info(`Capturing payment ${paymentIntentId} for ${finalAmountInCents} cents`);
    
    const payload = {
      amount_to_capture: finalAmountInCents, // Monto REAL consumido
    };

    // Si el pago va a un arrendador con Stripe Connect, retenemos la comisión del 20%
    /*
    if (ownerId) {
      const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (ownerDoc.exists && ownerDoc.data().stripeAccountId) {
        // Calculamos la comisión de la app, que se queda en la plataforma
        payload.application_fee_amount = Math.round(finalAmountInCents * 0.20);
      }
    }
    */

    const intent = await stripe.paymentIntents.capture(paymentIntentId, payload);

    logger.info(`Payment captured successfully. Status: ${intent.status}, Amount captured: ${intent.amount_captured}`);
    return { success: true, status: intent.status, amountCaptured: intent.amount_captured };
  } catch (error) {
    logger.error("Error al capturar los fondos:", error);
    throw new HttpsError("internal", "Error al capturar los fondos: " + error.message);
  }
});

/**
 * Endpoint para CANCELAR (Liberar) un PaymentIntent retenido.
 * Útil cuando el arrendador rechaza la solicitud de renta.
 */
exports.cancelPayment = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión para cancelar un pago.");
  }

  const { paymentIntentId } = request.data;
  if (!paymentIntentId) {
    throw new HttpsError("invalid-argument", "Falta el paymentIntentId.");
  }

  try {
    const stripe = require("stripe")(stripeSecretKey.value());
    const intent = await stripe.paymentIntents.cancel(paymentIntentId);
    return { success: true, status: intent.status };
  } catch (error) {
    logger.error("Error al cancelar el PaymentIntent:", error);
    throw new HttpsError("internal", "Error al cancelar el pago: " + error.message);
  }
});

/**
 * Endpoint para generar el enlace de registro de cuenta de Stripe para arrendadores.
 * Esto conecta su CLABE interbancaria al sistema.
 */
exports.getStripeAccountLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión para configurar pagos.");
  }
  
  try {
    const uid = request.auth.uid;
    const userRef = admin.firestore().collection("users").doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Usuario no encontrado.");
    }
    const userData = userDoc.data();
    let accountId = userData.stripeAccountId;

    // Si aún no tiene cuenta conectada, creamos una Express en Stripe
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: "MX",
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_type: "individual",
        email: userData.email,
      });
      accountId = account.id;
      // Guardamos la referencia en el perfil del usuario para futuras operaciones
      await userRef.update({ stripeAccountId: accountId });
    }

    // Generamos un enlace de onboarding/login para el usuario
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: "https://autoamigo.page.link/retry", // Reemplazar en producción
      return_url: "https://autoamigo.page.link/success", // Reemplazar con app link real
      type: "account_onboarding",
    });

    return { url: accountLink.url };
  } catch (error) {
    logger.error("Error obteniendo enlace de Stripe:", error);
    if (error?.type === "StripeInvalidRequestError" &&
        typeof error?.message === "string" &&
        error.message.includes("signed up for Connect")) {
      throw new HttpsError(
        "failed-precondition",
        "Stripe Connect no esta activado en tu cuenta. Activalo en dashboard.stripe.com/connect."
      );
    }

    throw new HttpsError("internal", "No se pudo conectar con Stripe.");
  }
});

exports.onNotificationCreated = onDocumentCreated("users/{userId}/notifications/{notificationId}", 
  async (event) => {
    // 1. Obtenemos los datos de la notificación guardada
    const notificationData = event.data.data();
    const userId = event.params.userId;

    logger.info(`Nueva notificación detectada para el usuario: ${userId}`);

    try {
      // 2. Obtenemos el perfil del dueño de la notificación para sacar su "fcmToken"
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      
      if (!userDoc.exists) {
        logger.warn("El usuario destino no existe. Abortando.");
        return null;
      }

      const userData = userDoc.data();
      const token = userData.fcmToken;

      // Si el usuario nunca ha abierto la app con notificaciones permitidas, no tendrá token
      if (!token) {
        logger.info(`El usuario ${userId} no tiene un token FCM guardado. Imposible enviar push.`);
        return null;
      }

      // 3. Preparamos el "Paquete" del mensaje Push
      const payload = {
        token: token,
        notification: {
          title: notificationData.title || "Notificación de AutoAmigo",
          body: notificationData.body || "Tienes una nueva actualización.",
        },
        data: {
          // Información invisible para que flutter sepa a qué pantalla ir al tocarla
          type: notificationData.type || "general",
          referenceId: notificationData.referenceId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
      };

      // 4. Se lo pasamos a Firebase Cloud Messaging para que se lo envíe al celular
      const response = await admin.messaging().send(payload);
      logger.info(`Notificación push enviada con éxito al dispositivo. ID: ${response}`);
      
      return null;

    } catch (error) {
      logger.error("Error crítico al intentar enviar la notificación push:", error);
      return null;
    }
  }
);
