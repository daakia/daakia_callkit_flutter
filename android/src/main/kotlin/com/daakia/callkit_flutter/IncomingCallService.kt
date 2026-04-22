package com.daakia.callkit_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class IncomingCallService : Service() {
    companion object {
        const val ACTION_SHOW = "com.daakia.callkit_flutter.action.SHOW"
        const val ACTION_ACCEPT = "com.daakia.callkit_flutter.action.ACCEPT"
        const val ACTION_DECLINE = "com.daakia.callkit_flutter.action.DECLINE"
        const val ACTION_END = "com.daakia.callkit_flutter.action.END"
        const val ACTION_CONNECTED = "com.daakia.callkit_flutter.action.CONNECTED"
        const val ACTION_TIMEOUT = "com.daakia.callkit_flutter.action.TIMEOUT"
        const val ACTION_CLOSE_UI = "com.daakia.callkit_flutter.action.CLOSE_UI"

        const val EXTRA_PAYLOAD = "payload"
        const val EXTRA_CALL_ID = "callId"
        const val EXTRA_TIMEOUT_SECONDS = "timeoutSeconds"
        const val EXTRA_ACTION_SOURCE = "actionSource"
        const val EXTRA_SKIP_HOST_LAUNCH = "skipHostLaunch"

        private const val CALL_CHANNEL_ID = "daakia_call_channel_native_v2"
        private const val ACTION_CALL_ACCEPT = "call-accept"
        private const val ACTION_CALL_REJECT = "call-reject"
        private const val ACTION_CALL_TIMEOUT = "call-timeout"
        const val ACTION_SOURCE_ACCEPT = "accept"
        const val ACTION_SOURCE_INCOMING = "incoming"
        private const val DEFAULT_TIMEOUT_SECONDS = 30
        private const val FALLBACK_DISPATCH_DELAY_MS = 1500L

        fun showIncomingCall(context: Context, payloadJson: String, timeoutSeconds: Int) {
            val intent = Intent(context, IncomingCallService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_PAYLOAD, payloadJson)
                putExtra(EXTRA_TIMEOUT_SECONDS, timeoutSeconds)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun endCall(context: Context, callId: String?) {
            val intent = Intent(context, IncomingCallService::class.java).apply {
                action = ACTION_END
                putExtra(EXTRA_CALL_ID, callId)
            }
            context.startService(intent)
        }

        fun setCallConnected(context: Context, callId: String?) {
            val intent = Intent(context, IncomingCallService::class.java).apply {
                action = ACTION_CONNECTED
                putExtra(EXTRA_CALL_ID, callId)
            }
            context.startService(intent)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var timeoutRunnable: Runnable? = null
    private var activeCallId: String? = null
    private var activePayloadJson: String? = null
    private var activeNotificationId: Int? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> handleShow(intent)
            ACTION_ACCEPT -> handleAccept(intent)
            ACTION_DECLINE -> handleDecline()
            ACTION_END -> handleEnd(intent.getStringExtra(EXTRA_CALL_ID))
            ACTION_CONNECTED -> handleConnected(intent.getStringExtra(EXTRA_CALL_ID))
            ACTION_TIMEOUT -> handleTimeout()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        cancelTimeout()
        stopAlerting()
        super.onDestroy()
    }

    private fun handleShow(intent: Intent) {
        val payloadJson = intent.getStringExtra(EXTRA_PAYLOAD) ?: return
        val payload = payloadMap(payloadJson)
        val callId = payload["callId"]?.toString()
        if (callId.isNullOrBlank()) {
            stopSelf()
            return
        }

        activeCallId = callId
        activePayloadJson = payloadJson
        activeNotificationId = callId.hashCode()

        ensureNotificationChannel()
        startForeground(
            activeNotificationId!!,
            buildIncomingCallNotification(payloadJson, payload)
        )
        startAlerting()
        scheduleTimeout(intent.getIntExtra(EXTRA_TIMEOUT_SECONDS, DEFAULT_TIMEOUT_SECONDS))

        DaakiaCallkitFlutterPlugin.emitEvent("incomingCall", payload)
    }

    private fun handleAccept(intent: Intent?) {
        val payload = currentPayloadMap() ?: return stopServiceState()
        val skipHostLaunch = intent?.getBooleanExtra(EXTRA_SKIP_HOST_LAUNCH, false) ?: false
        sendFallbackWebhookIfEnabled(payload, ACTION_CALL_ACCEPT)
        DaakiaCallkitFlutterPlugin.emitEvent("callAccepted", payload)
        if (!skipHostLaunch) {
            launchHostApp(ACTION_SOURCE_ACCEPT)
        }
        stopServiceState()
    }

    private fun handleDecline() {
        val payload = currentPayloadMap() ?: return stopServiceState()
        sendFallbackWebhookIfEnabled(payload, ACTION_CALL_REJECT)
        DaakiaCallkitFlutterPlugin.emitEvent("callDeclined", payload)
        stopServiceState()
    }

    private fun handleEnd(callId: String?) {
        if (callId != null && activeCallId != null && callId != activeCallId) {
            return
        }
        stopServiceState()
    }

    private fun handleConnected(callId: String?) {
        if (callId != null && activeCallId != null && callId != activeCallId) {
            return
        }
        stopServiceState()
    }

    private fun handleTimeout() {
        val payload = currentPayloadMap()
        if (payload != null) {
            val updatedPayload = HashMap(payload)
            updatedPayload["reason"] = "timeout"
            sendFallbackWebhookIfEnabled(updatedPayload, ACTION_CALL_TIMEOUT)
            DaakiaCallkitFlutterPlugin.emitEvent("callEnded", updatedPayload)
        }
        stopServiceState()
    }

    private fun stopServiceState() {
        cancelTimeout()
        stopAlerting()
        broadcastCloseUi()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        activeCallId = null
        activePayloadJson = null
        activeNotificationId = null
    }

    private fun startAlerting() {
        stopAlerting()

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        if (ringtoneUri != null) {
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, ringtoneUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        }

        val pattern = longArrayOf(0, 1000, 1000)
        val currentVibrator = vibratorService()
        vibrator = currentVibrator
        if (currentVibrator?.hasVibrator() == true) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                currentVibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                currentVibrator.vibrate(pattern, 0)
            }
        }
    }

    private fun stopAlerting() {
        mediaPlayer?.runCatching {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    private fun scheduleTimeout(timeoutSeconds: Int) {
        cancelTimeout()
        timeoutRunnable = Runnable {
            val timeoutIntent = Intent(this, IncomingCallService::class.java).apply {
                action = ACTION_TIMEOUT
            }
            startService(timeoutIntent)
        }
        mainHandler.postDelayed(
            timeoutRunnable!!,
            timeoutSeconds.coerceAtLeast(1) * 1000L
        )
    }

    private fun cancelTimeout() {
        timeoutRunnable?.let(mainHandler::removeCallbacks)
        timeoutRunnable = null
    }

    private fun buildIncomingCallNotification(
        payloadJson: String,
        payload: Map<String, Any?>
    ): Notification {
        val callerName = payload["title"]?.toString()
            ?: payload["callerName"]?.toString()
            ?: "Incoming Call"
        val body = payload["body"]?.toString() ?: "Tap to answer"

        val launchIntent = Intent(this, IncomingCallActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_PAYLOAD, payloadJson)
            putExtra(EXTRA_ACTION_SOURCE, ACTION_SOURCE_INCOMING)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            activeNotificationId ?: 0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val acceptIntent = Intent(this, IncomingCallActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_PAYLOAD, payloadJson)
            putExtra(EXTRA_ACTION_SOURCE, ACTION_SOURCE_ACCEPT)
        }
        val acceptPendingIntent = PendingIntent.getActivity(
            this,
            (activeNotificationId ?: 0) + 1,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val declineIntent = Intent(this, IncomingCallService::class.java).apply {
            action = ACTION_DECLINE
        }
        val declinePendingIntent = PendingIntent.getService(
            this,
            (activeNotificationId ?: 0) + 2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val person = Person.Builder().setName(callerName).build()
        return NotificationCompat.Builder(this, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(callerName)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setStyle(
                NotificationCompat.CallStyle.forIncomingCall(
                    person,
                    declinePendingIntent,
                    acceptPendingIntent
                )
            )
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CALL_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Daakia Calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Incoming call notifications"
            setSound(null, null)
            enableLights(false)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun launchHostApp(actionSource: String) {
        val payloadJson = activePayloadJson ?: return
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        )
        launchIntent.putExtra(EXTRA_PAYLOAD, payloadJson)
        launchIntent.putExtra(EXTRA_ACTION_SOURCE, actionSource)
        startActivity(launchIntent)
    }

    private fun broadcastCloseUi() {
        val intent = Intent(ACTION_CLOSE_UI).apply {
            setPackage(packageName)
            putExtra(EXTRA_CALL_ID, activeCallId)
        }
        sendBroadcast(intent)
    }

    private fun currentPayloadMap(): Map<String, Any?>? {
        val payloadJson = activePayloadJson ?: return null
        return payloadMap(payloadJson)
    }

    private fun payloadMap(payloadJson: String): Map<String, Any?> {
        val json = JSONObject(payloadJson)
        return jsonObjectToMap(json)
    }

    private fun sendFallbackWebhookIfEnabled(payload: Map<String, Any?>, action: String) {
        val context = applicationContext
        val config = DaakiaCallkitFlutterPlugin.fallbackConfig(context) ?: return
        if (!config.actions.contains(action)) return

        val meetingUid = payload["callId"]?.toString().orEmpty()
        if (meetingUid.isBlank()) return
        if (DaakiaCallkitFlutterPlugin.wasCallEventSent(context, meetingUid, action)) return

        Thread {
            runCatching {
                Thread.sleep(FALLBACK_DISPATCH_DELAY_MS)
                if (DaakiaCallkitFlutterPlugin.wasCallEventSent(context, meetingUid, action)) {
                    return@runCatching
                }
                val metadata = buildFallbackMetadata(payload, config.metadataJson)
                val requestBody = JSONObject().apply {
                    put("meeting_uid", meetingUid)
                    put(
                        "data",
                        JSONObject().apply {
                            put("action", action)
                            put("meta-data", metadata)
                        }
                    )
                }

                val connection = (URL(resolveWebhookUrl(config.baseUrl)).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 15000
                    readTimeout = 15000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("secret", config.secret)
                }

                connection.outputStream.bufferedWriter(Charsets.UTF_8).use { writer ->
                    writer.write(requestBody.toString())
                }

                val responseCode = connection.responseCode
                val responseText = (if (responseCode in 200..299) {
                    connection.inputStream
                } else {
                    connection.errorStream
                })?.bufferedReader()?.use { it.readText() }.orEmpty()

                if (responseCode in 200..299 && responseText.isNotBlank()) {
                    val responseJson = JSONObject(responseText)
                    if (responseJson.optInt("success") == 1) {
                        DaakiaCallkitFlutterPlugin.markCallEventSent(
                            context,
                            meetingUid,
                            action
                        )
                    }
                }
                connection.disconnect()
            }
        }.start()
    }

    private fun resolveWebhookUrl(baseUrl: String): String {
        return "${baseUrl.trimEnd('/')}/v2.0/rtc/call/webhook"
    }

    private fun buildFallbackMetadata(
        payload: Map<String, Any?>,
        metadataJson: String
    ): JSONObject {
        val metadata = runCatching { JSONObject(metadataJson) }.getOrElse { JSONObject() }
        payload["callerId"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            metadata.put("caller_id", it)
        }
        payload["receiverId"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            metadata.put("receiver_id", it)
        }
        payload["callTimestamp"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            metadata.put("call_timestamp", it)
        }
        metadata.put("delivery_mode", "fallback")
        metadata.put("platform", "android")
        return metadata
    }

    private fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.opt(key)
            map[key] = when (value) {
                is JSONObject -> jsonObjectToMap(value)
                JSONObject.NULL -> null
                else -> value
            }
        }
        return map
    }

    private fun vibratorService(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}
