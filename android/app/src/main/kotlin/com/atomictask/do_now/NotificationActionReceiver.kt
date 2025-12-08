package com.atomictask.do_now

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationActionReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "NotificationAction"
        
        // Shared preferences key for pending action
        const val PREFS_NAME = "donow_prefs"
        const val KEY_PENDING_ACTION = "pending_action"
    }
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        Log.d(TAG, "Received action: ${intent.action}")
        
        when (intent.action) {
            "com.atomictask.do_now.ACTION_COMPLETE_STEP" -> {
                // Store pending action
                savePendingAction(context, "complete")
                // Open the app
                openApp(context)
            }
            "com.atomictask.do_now.ACTION_CANCEL_TASK" -> {
                // Store pending action
                savePendingAction(context, "cancel")
                // Open the app
                openApp(context)
            }
        }
    }
    
    private fun savePendingAction(context: Context, action: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_PENDING_ACTION, action).apply()
        Log.d(TAG, "Saved pending action: $action")
    }
    
    private fun openApp(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_notification", true)
        }
        context.startActivity(launchIntent)
    }
}
