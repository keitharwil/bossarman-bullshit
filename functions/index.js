/**
 * Boss Arman MotoHub - Push Notification Delivery Engine
 * Cloud Functions for Firebase (v2, Node.js 20)
 *
 * Triggered on creation of documents in the top-level 'notifications' collection:
 * notifications/{notificationId}: {
 *   targetUserId: string | null,
 *   targetRole: 'admin' | 'cashier' | 'mechanic' | 'customer' | null,
 *   title: string,
 *   body: string,
 *   payload: Map<string, any> | string,
 *   createdAt: Timestamp,
 *   status: string
 * }
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

exports.deliverPushNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-southeast1", // Manila / Southeast Asia low-latency region
    maxInstances: 10,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const data = snap.data();
    const notificationId = event.params.notificationId;

    // Prevent re-processing if already handled
    if (data.status === "delivered" || data.status === "processing") {
      return null;
    }

    await snap.ref.update({ status: "processing" });

    const targetUserId = data.targetUserId;
    const targetRole = data.targetRole;
    const title = data.title || "Boss Arman MotoHub";
    const body = data.body || data.message || "";

    // Parse and flatten payload into Map<string, string> for FCM data compatibility
    const dataPayload = {};
    if (data.payload) {
      let rawPayload = data.payload;
      if (typeof rawPayload === "string") {
        try {
          rawPayload = JSON.parse(rawPayload);
        } catch (_) {
          rawPayload = { raw: rawPayload };
        }
      }
      if (typeof rawPayload === "object" && rawPayload !== null) {
        for (const [key, value] of Object.entries(rawPayload)) {
          dataPayload[key] = typeof value === "string" ? value : JSON.stringify(value);
        }
      }
    }

    // Ensure core routing fields exist in data payload
    dataPayload.notificationId = notificationId;
    dataPayload.title = title;
    dataPayload.body = body;
    if (targetRole) dataPayload.targetRole = targetRole;
    if (targetUserId) dataPayload.targetUserId = targetUserId;

    // Gather destination tokens from user_bindings
    const tokenToUserMap = new Map(); // token -> appUserId for stale pruning
    const tokenSet = new Set();

    try {
      if (targetUserId) {
        // Direct recipient targeting by document ID
        const userDoc = await db.collection("user_bindings").doc(targetUserId).get();
        if (userDoc.exists) {
          const userBindings = userDoc.data();
          const tokens = userBindings.fcmTokens || [];
          for (const token of tokens) {
            if (token && typeof token === "string") {
              tokenSet.add(token);
              tokenToUserMap.set(token, targetUserId);
            }
          }
        } else {
          // Fallback: check by appUserId field
          const byAppUserId = await db
            .collection("user_bindings")
            .where("appUserId", "==", targetUserId)
            .get();
          for (const doc of byAppUserId.docs) {
            const userBindings = doc.data();
            const tokens = userBindings.fcmTokens || [];
            for (const token of tokens) {
              if (token && typeof token === "string") {
                tokenSet.add(token);
                tokenToUserMap.set(token, doc.id);
              }
            }
          }
        }

        // If targetUserId is 'admin' or 'staff', also gather admin role devices
        if (targetUserId.toLowerCase() === "admin" || targetUserId.toLowerCase() === "staff") {
          const adminQuery = await db
            .collection("user_bindings")
            .where("role", "==", "admin")
            .get();
          for (const doc of adminQuery.docs) {
            const userBindings = doc.data();
            const tokens = userBindings.fcmTokens || [];
            for (const token of tokens) {
              if (token && typeof token === "string") {
                tokenSet.add(token);
                tokenToUserMap.set(token, doc.id);
              }
            }
          }
        }
      }

      if (
        targetRole &&
        (!targetUserId ||
          targetUserId.toLowerCase() === "admin" ||
          targetUserId.toLowerCase() === "staff")
      ) {
        // Role-wide broadcast targeting
        const roleQuery = await db
          .collection("user_bindings")
          .where("role", "==", targetRole)
          .get();

        for (const doc of roleQuery.docs) {
          const userBindings = doc.data();
          const tokens = userBindings.fcmTokens || [];
          for (const token of tokens) {
            if (token && typeof token === "string") {
              tokenSet.add(token);
              tokenToUserMap.set(token, doc.id);
            }
          }
        }
      }

      // If no tokens found yet and it's a general or shop alert, deliver to admins
      if (tokenSet.size === 0 && (!targetUserId || targetUserId.toLowerCase() === "admin")) {
        const adminQuery = await db
          .collection("user_bindings")
          .where("role", "==", "admin")
          .get();
        for (const doc of adminQuery.docs) {
          const userBindings = doc.data();
          const tokens = userBindings.fcmTokens || [];
          for (const token of tokens) {
            if (token && typeof token === "string") {
              tokenSet.add(token);
              tokenToUserMap.set(token, doc.id);
            }
          }
        }
      }

      const allTokens = Array.from(tokenSet);

      if (allTokens.length === 0) {
        console.log(`[PushEngine] No active FCM tokens found for targetUser: ${targetUserId}, targetRole: ${targetRole}`);
        await snap.ref.update({
          status: "no_tokens",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return null;
      }

      console.log(`[PushEngine] Delivering notification "${title}" to ${allTokens.length} device(s)`);

      // Chunk tokens into batches of 500 (FCM sendEachForMulticast limit)
      const CHUNK_SIZE = 500;
      let totalSuccess = 0;
      let totalFailure = 0;
      const staleTokensByUser = new Map(); // appUserId -> [staleTokens]

      for (let i = 0; i < allTokens.length; i += CHUNK_SIZE) {
        const batchTokens = allTokens.slice(i, i + CHUNK_SIZE);

        const multicastMessage = {
          tokens: batchTokens,
          notification: {
            title: title,
            body: body,
          },
          data: dataPayload,
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              sound: "default",
              defaultSound: true,
              defaultVibrateTimings: true,
              priority: "max",
              visibility: "public",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                contentAvailable: true,
                // Deliver immediately when the app is in background/terminated
                // state instead of letting iOS defer it to a background fetch.
                "content-available": 1,
              },
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
            },
          },
        };

        const response = await messaging.sendEachForMulticast(multicastMessage);
        totalSuccess += response.successCount;
        totalFailure += response.failureCount;

        // Collect unregistered or invalid tokens for automatic cleanup
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const errorCode = resp.error.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              const failedToken = batchTokens[idx];
              const userId = tokenToUserMap.get(failedToken);
              if (userId) {
                if (!staleTokensByUser.has(userId)) {
                  staleTokensByUser.set(userId, []);
                }
                staleTokensByUser.get(userId).push(failedToken);
              }
            }
          }
        });
      }

      // Prune stale tokens from user_bindings
      for (const [userId, staleTokens] of staleTokensByUser.entries()) {
        try {
          await db
            .collection("user_bindings")
            .doc(userId)
            .update({
              fcmTokens: FieldValue.arrayRemove(...staleTokens),
              updatedAt: FieldValue.serverTimestamp(),
            });
          console.log(`[PushEngine] Pruned ${staleTokens.length} stale token(s) for user: ${userId}`);
        } catch (pruneErr) {
          console.error(`[PushEngine] Error pruning stale tokens for ${userId}:`, pruneErr);
        }
      }

      // Final status write-back
      await snap.ref.update({
        status: totalSuccess > 0 ? "delivered" : "failed",
        deliveredAt: FieldValue.serverTimestamp(),
        successCount: totalSuccess,
        failureCount: totalFailure,
      });

      return { success: totalSuccess, failure: totalFailure };
    } catch (err) {
      console.error(`[PushEngine] Critical delivery error for notification ${notificationId}:`, err);
      await snap.ref.update({
        status: "error",
        error: err.message || String(err),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return null;
    }
  }
);

