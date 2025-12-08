package com.atomictask.do_now

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        const val CHANNEL = "com.donow.app/android_notification"
        const val TAG = "MainActivity"
    }
    
    private var methodChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTaskNotification" -> {
                    val taskTitle = call.argument<String>("taskTitle") ?: ""
                    val currentStep = call.argument<String>("currentStep") ?: ""
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val endTime = call.argument<Double>("endTime") ?: 0.0
                    
                    startTaskService(taskTitle, currentStep, progress, (endTime * 1000).toLong())
                    result.success(true)
                }
                "updateTaskNotification" -> {
                    val currentStep = call.argument<String>("currentStep") ?: ""
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val endTime = call.argument<Double>("endTime") ?: 0.0
                    
                    updateTaskService(currentStep, progress, (endTime * 1000).toLong())
                    result.success(true)
                }
                "stopTaskNotification" -> {
                    stopTaskService()
                    result.success(true)
                }
                "checkPendingAction" -> {
                    val action = checkAndClearPendingAction()
                    result.success(action)
                }
                "isServiceRunning" -> {
                    result.success(TaskForegroundService.isRunning())
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Check for pending action when app resumes
        checkAndNotifyPendingAction()
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Check if opened from notification
        if (intent.getBooleanExtra("from_notification", false)) {
            checkAndNotifyPendingAction()
        }
    }
    
    private fun startTaskService(taskTitle: String, currentStep: String, progress: Double, endTimeMillis: Long) {
        Log.d(TAG, "Starting task service: $taskTitle")
        
        val serviceIntent = Intent(this, TaskForegroundService::class.java).apply {
            action = TaskForegroundService.ACTION_START
            putExtra(TaskForegroundService.EXTRA_TASK_TITLE, taskTitle)
            putExtra(TaskForegroundService.EXTRA_CURRENT_STEP, currentStep)
            putExtra(TaskForegroundService.EXTRA_PROGRESS, progress)
            putExtra(TaskForegroundService.EXTRA_END_TIME, endTimeMillis)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun updateTaskService(currentStep: String, progress: Double, endTimeMillis: Long) {
        if (!TaskForegroundService.isRunning()) return
        
        val serviceIntent = Intent(this, TaskForegroundService::class.java).apply {
            action = TaskForegroundService.ACTION_UPDATE
            putExtra(TaskForegroundService.EXTRA_CURRENT_STEP, currentStep)
            putExtra(TaskForegroundService.EXTRA_PROGRESS, progress)
            putExtra(TaskForegroundService.EXTRA_END_TIME, endTimeMillis)
        }
        startService(serviceIntent)
    }
    
    private fun stopTaskService() {
        Log.d(TAG, "Stopping task service")
        
        val serviceIntent = Intent(this, TaskForegroundService::class.java).apply {
            action = TaskForegroundService.ACTION_STOP
        }
        startService(serviceIntent)
    }
    
    private fun checkAndClearPendingAction(): String? {
        val prefs = getSharedPreferences(NotificationActionReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val action = prefs.getString(NotificationActionReceiver.KEY_PENDING_ACTION, null)
        
        if (action != null) {
            // Clear the pending action
            prefs.edit().remove(NotificationActionReceiver.KEY_PENDING_ACTION).apply()
            Log.d(TAG, "Found and cleared pending action: $action")
        }
        
        return action
    }
    
    private fun checkAndNotifyPendingAction() {
        val action = checkAndClearPendingAction()
        if (action != null) {
            // Notify Flutter about the pending action
            methodChannel?.invokeMethod("onNotificationAction", action)
        }
    }
}
