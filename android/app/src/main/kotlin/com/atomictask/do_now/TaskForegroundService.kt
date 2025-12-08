package com.atomictask.do_now

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import android.graphics.Color

class TaskForegroundService : Service() {
    
    companion object {
        const val CHANNEL_ID = "donow_task_channel"
        const val NOTIFICATION_ID = 1001
        
        const val ACTION_START = "com.atomictask.do_now.ACTION_START"
        const val ACTION_UPDATE = "com.atomictask.do_now.ACTION_UPDATE"
        const val ACTION_STOP = "com.atomictask.do_now.ACTION_STOP"
        
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_CURRENT_STEP = "current_step"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_END_TIME = "end_time"
        
        private var instance: TaskForegroundService? = null
        
        fun isRunning(): Boolean = instance != null
    }
    
    private var taskTitle: String = ""
    private var currentStep: String = ""
    private var progress: Double = 0.0
    private var endTimeMillis: Long = 0
    
    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Task"
                currentStep = intent.getStringExtra(EXTRA_CURRENT_STEP) ?: ""
                progress = intent.getDoubleExtra(EXTRA_PROGRESS, 0.0)
                endTimeMillis = intent.getLongExtra(EXTRA_END_TIME, 0)
                
                startForeground(NOTIFICATION_ID, buildNotification())
                startPeriodicUpdates()
            }
            ACTION_UPDATE -> {
                currentStep = intent.getStringExtra(EXTRA_CURRENT_STEP) ?: currentStep
                progress = intent.getDoubleExtra(EXTRA_PROGRESS, progress)
                endTimeMillis = intent.getLongExtra(EXTRA_END_TIME, endTimeMillis)
                
                updateNotification()
            }
            ACTION_STOP -> {
                stopPeriodicUpdates()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        stopPeriodicUpdates()
        instance = null
        super.onDestroy()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Task Timer",
                NotificationManager.IMPORTANCE_LOW // Low importance to avoid sound
            ).apply {
                description = "Shows current task progress"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun buildNotification(): Notification {
        // Calculate remaining time
        val remainingMs = if (endTimeMillis > 0) endTimeMillis - System.currentTimeMillis() else 0
        val remainingSeconds = (remainingMs / 1000).coerceAtLeast(0)
        val minutes = remainingSeconds / 60
        val seconds = remainingSeconds % 60
        val timeString = String.format("%02d:%02d", minutes, seconds)
        
        // Intent to open app
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Complete Step Action
        val completeIntent = Intent(this, NotificationActionReceiver::class.java).apply {
            action = "com.atomictask.do_now.ACTION_COMPLETE_STEP"
        }
        val completePendingIntent = PendingIntent.getBroadcast(
            this, 1, completeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Cancel Task Action
        val cancelIntent = Intent(this, NotificationActionReceiver::class.java).apply {
            action = "com.atomictask.do_now.ACTION_CANCEL_TASK"
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            this, 2, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Build notification
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setContentTitle("$taskTitle • $timeString")
            .setContentText(currentStep)
            .setSubText("进行中")
            .setProgress(100, (progress * 100).toInt(), false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openPendingIntent)
            .setColor(Color.BLACK)
            .addAction(
                android.R.drawable.ic_menu_send,
                "✓ 完成步骤",
                completePendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "✕ 放弃",
                cancelPendingIntent
            )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("$taskTitle • $timeString")
                    .bigText("当前步骤: $currentStep\n进度: ${(progress * 100).toInt()}%")
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
        
        return builder.build()
    }
    
    private fun updateNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildNotification())
    }
    
    private fun startPeriodicUpdates() {
        stopPeriodicUpdates()
        updateRunnable = object : Runnable {
            override fun run() {
                updateNotification()
                handler.postDelayed(this, 1000) // Update every second
            }
        }
        handler.post(updateRunnable!!)
    }
    
    private fun stopPeriodicUpdates() {
        updateRunnable?.let { handler.removeCallbacks(it) }
        updateRunnable = null
    }
}
