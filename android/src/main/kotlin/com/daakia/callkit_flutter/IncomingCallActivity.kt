package com.daakia.callkit_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject

class IncomingCallActivity : AppCompatActivity() {
    private var callId: String? = null
    private var receiverRegistered = false

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val closingCallId = intent?.getStringExtra(IncomingCallService.EXTRA_CALL_ID)
            if (closingCallId == null || closingCallId == callId) {
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        showOverLockScreen()

        val payloadJson = intent.getStringExtra(IncomingCallService.EXTRA_PAYLOAD).orEmpty()
        val payload = payloadMap(payloadJson)
        callId = payload["callId"]?.toString()

        setContentView(buildContent(payloadJson, payload))
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(IncomingCallService.ACTION_CLOSE_UI)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(closeReceiver, filter)
        }
        receiverRegistered = true
    }

    override fun onStop() {
        if (receiverRegistered) {
            unregisterReceiver(closeReceiver)
            receiverRegistered = false
        }
        super.onStop()
    }

    private fun buildContent(payloadJson: String, payload: Map<String, Any?>): LinearLayout {
        val callerName = payload["title"]?.toString()
            ?: payload["callerName"]?.toString()
            ?: "Incoming Call"
        val body = payload["body"]?.toString() ?: "Respond to join or decline the call"

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#10151D"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding(48, 96, 48, 96)

            addView(TextView(context).apply {
                text = callerName
                textSize = 30f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            })

            addView(TextView(context).apply {
                text = body
                textSize = 16f
                setTextColor(Color.parseColor("#B7C1CC"))
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.topMargin = 32
                layoutParams = params
            })

            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.topMargin = 72
                layoutParams = params

                addView(Button(context).apply {
                    text = "Decline"
                    setBackgroundColor(Color.parseColor("#D14343"))
                    setTextColor(Color.WHITE)
                    setOnClickListener {
                        startService(
                            Intent(context, IncomingCallService::class.java).apply {
                                action = IncomingCallService.ACTION_DECLINE
                            }
                        )
                        finish()
                    }
                })

                addView(Button(context).apply {
                    text = "Accept"
                    setBackgroundColor(Color.parseColor("#2E9E58"))
                    setTextColor(Color.WHITE)
                    val buttonParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                    buttonParams.marginStart = 32
                    layoutParams = buttonParams
                    setOnClickListener {
                        startService(
                            Intent(context, IncomingCallService::class.java).apply {
                                action = IncomingCallService.ACTION_ACCEPT
                                putExtra(IncomingCallService.EXTRA_PAYLOAD, payloadJson)
                            }
                        )
                        finish()
                    }
                })
            })
        }
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    private fun payloadMap(payloadJson: String): Map<String, Any?> {
        if (payloadJson.isBlank()) return emptyMap()
        val json = JSONObject(payloadJson)
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.opt(key)
            map[key] = if (value == JSONObject.NULL) null else value
        }
        return map
    }
}
