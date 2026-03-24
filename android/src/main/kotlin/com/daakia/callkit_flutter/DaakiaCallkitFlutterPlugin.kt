package com.daakia.callkit_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DaakiaCallkitFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "daakia_callkit_flutter/android_call"

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
            else -> result.notImplemented()
        }
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
}
