// functions/src/index.ts
import {setGlobalOptions} from "firebase-functions/v2/options";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();
setGlobalOptions({region: "asia-east1"});

type NotificationDoc = {
  to?: string;
  notification?: { title?: string; body?: string };
  data?: Record<string, string>;
  sent?: boolean;
  error?: string;
  errorCode?: string;
  sentAt?: FirebaseFirestore.FieldValue | Date;
  response?: string;
};

// 🔔 新增 notifications/{id} 就發送推播
export const sendNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event): Promise<void> => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notificationData = snapshot.data() as NotificationDoc | undefined;
    if (!notificationData) return;

    const {to, notification, data, sent} = notificationData;

    if (sent === true) return;

    if (!to) {
      await snapshot.ref.update({
        sent: true,
        error: "Missing recipient token",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
      return;
    }

    if (!notification || !notification.title) {
      await snapshot.ref.update({
        sent: true,
        error: "Missing notification content",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
      return;
    }

    const message: admin.messaging.Message = {
      token: to,
      notification: {
        title: notification.title,
        body: notification.body || "",
      },
      data: (data as Record<string, string>) || {},
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "chat_channel",
          priority: "high",
        },
      },
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    };

    try {
      const response = await admin.messaging().send(message);
      await snapshot.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        response,
      } as NotificationDoc);
    } catch (error: any) {
      await snapshot.ref.update({
        sent: true,
        error: error?.message || "Unknown error",
        errorCode: error?.code || "unknown",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
    }
  }
);

// 🧹 每天 02:00 清理 7 天前已發送的通知
export const cleanupOldNotifications = onSchedule(
  {schedule: "0 2 * * *", timeZone: "Asia/Taipei"},
  async (): Promise<void> => {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const qs = await admin
      .firestore()
      .collection("notifications")
      .where("sent", "==", true)
      .where("sentAt", "<", sevenDaysAgo)
      .limit(500)
      .get();

    if (qs.empty) return;

    const batch = admin.firestore().batch();
    qs.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
);

// 🔔 新增配對請求就寫入一筆通知，由 sendNotification 發送
export const notifyPairRequest = onDocumentCreated(
  "pairRequests/{requestId}",
  async (event): Promise<void> => {
    const snap = event.data;
    if (!snap) return;

    const {toUserId, fromUserName} = snap.data() as {
      toUserId: string;
      fromUserName: string;
    };

    const userDoc = await admin.firestore().collection("users").doc(toUserId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;

    await admin.firestore().collection("notifications").add({
      to: fcmToken,
      notification: {
        title: "新的配對請求",
        body: `${fromUserName} 想要與您配對`,
      },
      data: {
        type: "pair_request",
        requestId: event.params.requestId,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sent: false,
    } as NotificationDoc);
  }
);
