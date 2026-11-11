package com.bossarman.motohub.boss_arman_motohub

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import android.util.Xml
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import io.flutter.embedding.android.FlutterActivity
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        notifyBackgroundService(isForeground = true)
    }

    override fun onResume() {
        super.onResume()
        notifyBackgroundService(isForeground = true)
    }

    override fun onPause() {
        notifyBackgroundService(isForeground = false)
        super.onPause()
    }

    override fun onDestroy() {
        notifyBackgroundService(isForeground = false)
        super.onDestroy()
    }

    private fun notifyBackgroundService(isForeground: Boolean) {
        try {
            val serviceIntent = Intent(applicationContext, MotoHubNotificationService::class.java).apply {
                putExtra("isForeground", isForeground)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // The service self-promotes to a foreground service; using
                // startForegroundService avoids "not allowed to start service
                // Intent ... while app invisible" / background-start crashes.
                applicationContext.startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not update MotoHubNotificationService: ${e.message}")
        }
    }
}

/**
 * Isolated background/destroyed-state notification listener service running in `:notif` process.
 * Running in `:notif` with a dedicated named FirebaseApp ("motohub_bg_listener") guarantees
 * zero conflict with Flutter's `cloud_firestore` plugin (`setFirestoreSettings`) in the main UI process,
 * while ensuring notifications are still received when the main app is swiped away from Recents.
 */
class MotoHubNotificationService : Service() {
    companion object {
        private const val TAG = "MotoHubNotifService"
        private const val BG_FIREBASE_APP_NAME = "motohub_bg_listener"
        private const val CHANNEL_ID = "high_importance_channel"
        private const val CHANNEL_NAME = "High Importance Notifications"
        private const val PREFS_NAME = "MotoHubBgNotifPrefs"
        private const val PREFS_SEEN_KEY = "motohub_bg_notified_ids"
        private const val KEEPALIVE_NOTIFICATION_ID = 987654
    }

    @Volatile
    private var isMainAppForeground: Boolean = false
    private var listenerRegistration: ListenerRegistration? = null
    private val seenIds = mutableSetOf<String>()
    private var initialSnapshotProcessed = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        loadSeenIds()
        ensureFirebaseAndListen()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.hasExtra("isForeground")) {
            isMainAppForeground = intent.getBooleanExtra("isForeground", false)
        }
        // MUST be called within ~5s of a startForegroundService() call or the
        // system throws ANR/crash on Android 8+. This also keeps the Firestore
        // listener alive when the app process is cached after being swiped away.
        promoteToForeground()
        ensureFirebaseAndListen()
        return START_STICKY
    }

    private fun promoteToForeground() {
        try {
            createNotificationChannel()
            val launchIntent = Intent(applicationContext, MainActivity::class.java)
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getActivity(
                applicationContext, 1000, launchIntent, piFlags
            )
            val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(applicationContext.applicationInfo.loadLabel(packageManager))
                .setContentText("Listening for order & shop updates")
                .setOngoing(true)
                .setSilent()
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setContentIntent(pendingIntent)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    KEEPALIVE_NOTIFICATION_ID, notification,
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
                )
            } else {
                startForeground(KEEPALIVE_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.w(TAG, "promoteToForeground notice: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        isMainAppForeground = false
        try {
            val restartIntent = Intent(applicationContext, BootReceiver::class.java).apply {
                action = "com.bossarman.motohub.RESTART_NOTIF_SERVICE"
                putExtra("isForeground", false)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                1001,
                restartIntent,
                flags
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 1000L,
                pendingIntent
            )
        } catch (e: Exception) {
            Log.w(TAG, "onTaskRemoved restart schedule notice: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        listenerRegistration?.remove()
        listenerRegistration = null
        super.onDestroy()
    }

    private fun loadSeenIds() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val saved = prefs.getStringSet(PREFS_SEEN_KEY, emptySet()) ?: emptySet()
            seenIds.addAll(saved)
        } catch (_: Exception) {}
    }

    private fun saveSeenId(id: String) {
        seenIds.add(id)
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val trimmed = if (seenIds.size > 300) {
                seenIds.toList().takeLast(250).toSet()
            } else {
                seenIds.toSet()
            }
            prefs.edit().putStringSet(PREFS_SEEN_KEY, trimmed).apply()
        } catch (_: Exception) {}
    }

    private fun getOrCreateBackgroundFirebaseApp(): FirebaseApp? {
        val defaultApp = if (FirebaseApp.getApps(applicationContext).isEmpty()) {
            FirebaseApp.initializeApp(applicationContext)
        } else {
            FirebaseApp.getInstance()
        } ?: return null

        return try {
            FirebaseApp.getInstance(BG_FIREBASE_APP_NAME)
        } catch (_: IllegalStateException) {
            FirebaseApp.initializeApp(
                applicationContext,
                defaultApp.options,
                BG_FIREBASE_APP_NAME
            )
        }
    }

    private fun ensureFirebaseAndListen() {
        if (listenerRegistration != null) return
        try {
            val bgApp = getOrCreateBackgroundFirebaseApp() ?: return
            val auth = FirebaseAuth.getInstance(bgApp)
            if (auth.currentUser != null) {
                attachFirestoreListener(bgApp)
            } else {
                auth.signInAnonymously()
                    .addOnSuccessListener { attachFirestoreListener(bgApp) }
                    .addOnFailureListener { attachFirestoreListener(bgApp) }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Firebase init notice: ${e.message}")
        }
    }

    private fun attachFirestoreListener(bgApp: FirebaseApp) {
        if (listenerRegistration != null) return
        try {
            initialSnapshotProcessed = false
            listenerRegistration = FirebaseFirestore.getInstance(bgApp)
                .collection("notifications")
                .addSnapshotListener { snapshot, error ->
                    if (error != null || snapshot == null) {
                        return@addSnapshotListener
                    }

                    // On initial snapshot when the service attaches, record all existing IDs
                    // so we only alert on newly arriving notifications.
                    if (!initialSnapshotProcessed) {
                        for (doc in snapshot.documents) {
                            seenIds.add(doc.id)
                        }
                        initialSnapshotProcessed = true
                        saveSeenId("__init__")
                        return@addSnapshotListener
                    }

                    for (change in snapshot.documentChanges) {
                        if (change.type == DocumentChange.Type.REMOVED) continue
                        val doc = change.document
                        val docId = doc.id
                        if (seenIds.contains(docId)) continue

                        val isRead = doc.getBoolean("isRead") ?: false
                        saveSeenId(docId)
                        if (isRead) continue

                        // If the Flutter Activity is currently in the foreground, Dart's
                        // MotoHubViewModel listener handles displaying the notification.
                        if (isMainAppForeground) continue

                        val title = doc.getString("title") ?: "Boss Arman MotoHub"
                        val message = doc.getString("message") ?: ""
                        val payload = doc.getString("payload")
                        val targetUserId = doc.getString("targetUserId")
                        val targetRole = doc.getString("targetRole")
                        val category = doc.getString("category") ?: ""
                        val branch = doc.getString("branch") ?: "both"

                        if (shouldNotifyCurrentSession(
                                targetUserId = targetUserId,
                                targetRole = targetRole,
                                category = category,
                                notifBranch = branch
                            )
                        ) {
                            showSystemNotification(
                                docId = docId,
                                title = title,
                                body = message,
                                payload = payload
                            )
                        }
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "attachFirestoreListener error: ${e.message}")
        }
    }

    /**
     * Reads the latest FlutterSharedPreferences.xml directly from disk so cross-process
     * changes made in the main UI process are visible immediately in `:notif`.
     */
    private fun readFlutterPrefsFromDisk(): Map<String, String> {
        val result = mutableMapOf<String, String>()
        try {
            val prefsFile = File(applicationInfo.dataDir, "shared_prefs/FlutterSharedPreferences.xml")
            if (prefsFile.exists()) {
                FileInputStream(prefsFile).use { fis ->
                    val parser = Xml.newPullParser()
                    parser.setInput(fis, "UTF-8")
                    var eventType = parser.eventType
                    while (eventType != XmlPullParser.END_DOCUMENT) {
                        if (eventType == XmlPullParser.START_TAG && parser.name == "string") {
                            val nameAttr = parser.getAttributeValue(null, "name")
                            val textVal = parser.nextText()
                            if (!nameAttr.isNullOrEmpty()) {
                                result[nameAttr] = textVal ?: ""
                            }
                        }
                        eventType = parser.next()
                    }
                }
                return result
            }
        } catch (_: Exception) {}

        // Fallback to standard SharedPreferences if XML read fails
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            for ((k, v) in prefs.all) {
                if (v is String) {
                    result[k] = v
                }
            }
        } catch (_: Exception) {}
        return result
    }

    private fun shouldNotifyCurrentSession(
        targetUserId: String?,
        targetRole: String?,
        category: String,
        notifBranch: String
    ): Boolean {
        val prefsMap = readFlutterPrefsFromDisk()
        val isCustomerApp = applicationContext.packageName.endsWith(".rider")

        val myId: String
        val myUsername: String
        val myRole: String
        val myBranch = (prefsMap["flutter.cached_branch"] ?: "patimbao").trim().lowercase()

        if (isCustomerApp) {
            myId = (prefsMap["flutter.cached_customer_user_id"] ?: "").trim().lowercase()
            myUsername = (prefsMap["flutter.cached_customer_user"] ?: "").trim().lowercase()
            myRole = (prefsMap["flutter.cached_customer_role"] ?: "customer").trim().lowercase()
        } else {
            myId = (prefsMap["flutter.cached_internal_user_id"] ?: "").trim().lowercase()
            myUsername = (prefsMap["flutter.cached_internal_user"] ?: "").trim().lowercase()
            myRole = (prefsMap["flutter.cached_internal_role"] ?: "").trim().lowercase()
        }

        // If no user is logged into this app flavor, do not show notifications
        if (myId.isEmpty() && myUsername.isEmpty()) {
            return false
        }

        val isAdmin = !isCustomerApp && (myRole == "admin" || myUsername == "bossarman" || myUsername == "lanceadmin" || myUsername == "keithadmin")
        val cleanTargetUser = targetUserId?.trim()?.lowercase() ?: ""
        val cleanTargetRole = targetRole?.trim()?.lowercase() ?: ""
        val cleanCategory = category.trim().lowercase()
        val cleanBranch = notifBranch.trim().lowercase()

        if (cleanTargetUser.isNotEmpty()) {
            val matchesUser = (myId.isNotEmpty() && cleanTargetUser == myId) ||
                (myUsername.isNotEmpty() && cleanTargetUser == myUsername)
            val matchesAdminAlias = isAdmin && (cleanTargetUser == "admin" || cleanTargetUser == "staff")
            if (!matchesUser && !matchesAdminAlias) {
                return false
            }
        }

        if (cleanTargetRole.isNotEmpty()) {
            if (isCustomerApp) {
                if (cleanTargetRole != "customer") return false
            } else {
                val effectiveRole = if (myRole.isNotEmpty()) myRole else if (isAdmin) "admin" else ""
                val matchesRole = cleanTargetRole == effectiveRole ||
                    (isAdmin && (cleanTargetRole == "admin" || cleanCategory == "booking" || cleanCategory == "job_order" || cleanCategory == "reservation"))
                if (!matchesRole) return false
            }
        } else if (isCustomerApp && cleanTargetUser.isEmpty()) {
            // Customer app should not receive untargeted internal staff notifications
            return false
        }

        val isBranchLocked = !isCustomerApp && (myRole == "cashier" || myRole == "mechanic")
        if (isBranchLocked) {
            return cleanBranch == myBranch || cleanBranch == "both"
        }

        return true
    }

    private fun showSystemNotification(
        docId: String,
        title: String,
        body: String,
        payload: String?
    ) {
        try {
            createNotificationChannel()
            val launchIntent = Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (!payload.isNullOrEmpty()) {
                    putExtra("payload", payload)
                }
            }
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                docId.hashCode(),
                launchIntent,
                piFlags
            )

            val builder = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.notify(docId.hashCode() and 0x7FFFFFFF, builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "showSystemNotification failed: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical alerts for job statuses, reservations, and stock levels."
                enableVibration(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }
}
