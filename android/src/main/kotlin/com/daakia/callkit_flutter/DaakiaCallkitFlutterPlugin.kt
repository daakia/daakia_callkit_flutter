package com.daakia.callkit_flutter

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DaakiaCallkitFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "daakia_callkit_flutter/android_call"
        private const val PREFS_NAME = "daakia_callkit_flutter_call_events"
        private const val KEY_BASE_URL = "fallback_base_url"
        private const val KEY_SECRET = "fallback_secret"
        private const val KEY_ACTIONS = "fallback_actions"
        private const val KEY_METADATA = "fallback_metadata"
        private const val KEY_SENT_EVENTS = "sent_events"

        private var eventChannel: MethodChannel? = null
        private var applicationContext: Context? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private val pendingEvents = mutableListOf<Pair<String, Map<String, Any?>>>()

        fun emitEvent(method: String, payload: Map<String, Any?>) {
            val eventPayload = HashMap(payload)
            val currentChannel = eventChannel
            if (currentChannel == null) {
                pendingEvents.add(method to eventPayload)
                return
            }

            mainHandler.post {
                currentChannel.invokeMethod(method, eventPayload)
            }
        }

        fun appContext(): Context? = applicationContext

        private fun prefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        fun fallbackConfig(context: Context): FallbackConfig? {
            val prefs = prefs(context)
            val baseUrl = prefs.getString(KEY_BASE_URL, null).orEmpty()
            val secret = prefs.getString(KEY_SECRET, null).orEmpty()
            if (baseUrl.isBlank() || secret.isBlank()) {
                return null
            }

            return FallbackConfig(
                baseUrl = baseUrl,
                secret = secret,
                actions = prefs.getStringSet(KEY_ACTIONS, emptySet()) ?: emptySet(),
                metadataJson = prefs.getString(KEY_METADATA, "{}").orEmpty()
            )
        }

        fun configureFallback(
            context: Context,
            baseUrl: String,
            secret: String,
            actions: Set<String>,
            metadataJson: String
        ) {
            prefs(context).edit()
                .putString(KEY_BASE_URL, baseUrl)
                .putString(KEY_SECRET, secret)
                .putStringSet(KEY_ACTIONS, actions)
                .putString(KEY_METADATA, metadataJson)
                .apply()
        }

        fun clearFallback(context: Context) {
            prefs(context).edit()
                .remove(KEY_BASE_URL)
                .remove(KEY_SECRET)
                .remove(KEY_ACTIONS)
                .remove(KEY_METADATA)
                .apply()
        }

        fun wasCallEventSent(context: Context, meetingUid: String, action: String): Boolean {
            return sentEvents(context).contains("$meetingUid::$action")
        }

        fun markCallEventSent(context: Context, meetingUid: String, action: String) {
            val updated = sentEvents(context).toMutableList()
            val key = "$meetingUid::$action"
            if (!updated.contains(key)) {
                updated.add(key)
            }
            val trimmed = updated.takeLast(100).toSet()
            prefs(context).edit().putStringSet(KEY_SENT_EVENTS, trimmed).apply()
        }

        private fun sentEvents(context: Context): Set<String> {
            return prefs(context).getStringSet(KEY_SENT_EVENTS, emptySet()) ?: emptySet()
        }

        fun clearSentEvents(context: Context) {
            prefs(context).edit().remove(KEY_SENT_EVENTS).apply()
        }
    }

    private var instanceChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        instanceChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (eventChannel === instanceChannel) {
            eventChannel = null
        }
        instanceChannel?.setMethodCallHandler(null)
        instanceChannel = null
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext
        if (context == null) {
            result.error("no_context", "Android plugin context is not available", null)
            return
        }

        when (call.method) {
            "register" -> {
                eventChannel = instanceChannel
                flushPendingEvents()
                result.success(null)
            }
            "showIncomingCall" -> {
                val payloadJson = call.argument<String>("payload")
                val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 30
                if (payloadJson.isNullOrBlank()) {
                    result.error("invalid_payload", "payload is required", null)
                    return
                }
                IncomingCallService.showIncomingCall(context, payloadJson, timeoutSeconds)
                result.success(null)
            }
            "endCall" -> {
                val callId = call.argument<String>("callId")
                IncomingCallService.endCall(context, callId)
                result.success(null)
            }
            "setCallConnected" -> {
                val callId = call.argument<String>("callId")
                IncomingCallService.setCallConnected(context, callId)
                result.success(null)
            }
            "canUseFullScreenIntent" -> {
                result.success(canUseFullScreenIntent(context))
            }
            "openFullScreenIntentSettings" -> {
                result.success(openFullScreenIntentSettings(context))
            }
            "configureCallEventFallback" -> {
                val baseUrl = call.argument<String>("baseUrl").orEmpty()
                val secret = call.argument<String>("secret").orEmpty()
                val actions = call.argument<List<String>>("actions")?.toSet() ?: emptySet()
                val metadata = call.argument<Map<String, Any?>>("metadata") ?: emptyMap()
                configureFallback(
                    context = context,
                    baseUrl = baseUrl,
                    secret = secret,
                    actions = actions,
                    metadataJson = org.json.JSONObject(metadata).toString()
                )
                result.success(null)
            }
            "clearCallEventFallback" -> {
                clearFallback(context)
                result.success(null)
            }
            "wasCallEventSent" -> {
                val meetingUid = call.argument<String>("meetingUid").orEmpty()
                val action = call.argument<String>("action").orEmpty()
                result.success(wasCallEventSent(context, meetingUid, action))
            }
            "markCallEventSent" -> {
                val meetingUid = call.argument<String>("meetingUid").orEmpty()
                val action = call.argument<String>("action").orEmpty()
                markCallEventSent(context, meetingUid, action)
                result.success(null)
            }
            "clearSentCallEventCache" -> {
                clearSentEvents(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notificationManager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return false
        }
        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return runCatching {
            context.startActivity(intent)
            true
        }.getOrElse { false }
    }

    private fun flushPendingEvents() {
        val currentChannel = eventChannel ?: return
        if (pendingEvents.isEmpty()) return

        val events = pendingEvents.toList()
        pendingEvents.clear()
        mainHandler.post {
            for ((method, payload) in events) {
                currentChannel.invokeMethod(method, payload)
            }
        }
    }

    data class FallbackConfig(
        val baseUrl: String,
        val secret: String,
        val actions: Set<String>,
        val metadataJson: String
    )
}
