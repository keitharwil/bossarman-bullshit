package com.bossarman.motohub.boss_arman_motohub

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Received broadcast action: $action")
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "com.bossarman.motohub.RESTART_NOTIF_SERVICE"
        ) {
            try {
                val serviceIntent = Intent(context, MotoHubNotificationService::class.java).apply {
                    putExtra("isForeground", false)
                }
                context.startService(serviceIntent)
                Log.d(TAG, "Started MotoHubNotificationService successfully from action: $action")
            } catch (e: Exception) {
                Log.w(TAG, "Could not start MotoHubNotificationService on $action: ${e.message}")
            }
        }
    }
}
