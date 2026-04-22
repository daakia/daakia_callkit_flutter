package com.daakia.callkit_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
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

        if (handleLaunchIntent(intent)) {
            return
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
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
        val callerName = resolveCallerName(payload)
        val title = payload["title"]?.toString()
            ?: "Incoming Call"
        val body = payload["body"]?.toString() ?: "Respond to join or decline the call"
        val initial = callerName.firstOrNull()?.uppercase() ?: "?"

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(
                    Color.parseColor("#121212"),
                    Color.parseColor("#0A2A43")
                )
            )
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding(dp(24), dp(32), dp(24), dp(24))

            addView(spacer(1f))

            addView(FrameLayout(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(128), dp(128))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#455A64"))
                    setStroke(dp(2), Color.parseColor("#3DFFFFFF"))
                }
                elevation = dp(6).toFloat()

                addView(TextView(context).apply {
                    text = initial
                    textSize = 44f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                })
            })

            addView(TextView(context).apply {
                text = callerName
                textSize = 32f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.topMargin = dp(24)
                layoutParams = params
            })

            addView(TextView(context).apply {
                text = title
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Color.parseColor("#B3FFFFFF"))
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dp(20).toFloat()
                    setColor(Color.parseColor("#1FFFFFFF"))
                }
                setPadding(dp(16), dp(8), dp(16), dp(8))
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.topMargin = dp(10)
                layoutParams = params
            })

            addView(spacer(1f))

            addView(TextView(context).apply {
                text = body
                textSize = 14f
                setTextColor(Color.parseColor("#99FFFFFF"))
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.bottomMargin = dp(20)
                layoutParams = params
            })

            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )

                addView(buildActionColumn(
                    label = "Decline",
                    backgroundColor = Color.parseColor("#E53935"),
                    iconRes = android.R.drawable.ic_menu_close_clear_cancel
                ) {
                    startService(
                        Intent(context, IncomingCallService::class.java).apply {
                            action = IncomingCallService.ACTION_DECLINE
                        }
                    )
                    finish()
                })

                addView(buildActionColumn(
                    label = "Accept",
                    backgroundColor = Color.parseColor("#43A047"),
                    iconRes = android.R.drawable.sym_action_call
                ) {
                    acceptCall(payloadJson)
                })
            })

            addView(View(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(8)
                )
            })
        }
    }

    private fun buildActionColumn(
        label: String,
        backgroundColor: Int,
        iconRes: Int,
        onClick: () -> Unit
    ): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )

            addView(FrameLayout(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(56), dp(56))
                val shapeDrawable = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(backgroundColor)
                }
                background = RippleDrawable(
                    ColorStateList.valueOf(Color.parseColor("#33FFFFFF")),
                    shapeDrawable,
                    null
                )
                elevation = dp(6).toFloat()
                isClickable = true
                isFocusable = true
                setOnClickListener { onClick() }

                addView(ImageView(context).apply {
                    setImageResource(iconRes)
                    setColorFilter(Color.WHITE)
                    layoutParams = FrameLayout.LayoutParams(
                        dp(24),
                        dp(24),
                        Gravity.CENTER
                    )
                })
            })

            addView(TextView(context).apply {
                text = label
                textSize = 14f
                setTextColor(Color.parseColor("#B3FFFFFF"))
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.topMargin = dp(10)
                layoutParams = params
            })
        }
    }

    private fun resolveCallerName(payload: Map<String, Any?>): String {
        val senderValue = payload["sender"]
        if (senderValue is String && senderValue.isNotBlank()) {
            runCatching {
                val senderJson = JSONObject(senderValue)
                val senderName = senderJson.optString("userName")
                if (senderName.isNotBlank()) {
                    return senderName
                }
            }
        }
        return payload["callerName"]?.toString()
            ?: payload["title"]?.toString()
            ?: "Unknown"
    }

    private fun handleLaunchIntent(intent: Intent): Boolean {
        val payloadJson = intent.getStringExtra(IncomingCallService.EXTRA_PAYLOAD).orEmpty()
        if (payloadJson.isBlank()) {
            finish()
            return true
        }

        val payload = payloadMap(payloadJson)
        callId = payload["callId"]?.toString()

        if (intent.getStringExtra(IncomingCallService.EXTRA_ACTION_SOURCE) ==
            IncomingCallService.ACTION_SOURCE_ACCEPT
        ) {
            acceptCall(payloadJson)
            return true
        }

        setContentView(buildContent(payloadJson, payload))
        return false
    }

    private fun acceptCall(payloadJson: String) {
        startService(
            Intent(this, IncomingCallService::class.java).apply {
                action = IncomingCallService.ACTION_ACCEPT
                putExtra(IncomingCallService.EXTRA_SKIP_HOST_LAUNCH, true)
            }
        )
        launchHostApp(payloadJson, IncomingCallService.ACTION_SOURCE_ACCEPT)
        finish()
    }

    private fun launchHostApp(payloadJson: String, actionSource: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        )
        launchIntent.putExtra(IncomingCallService.EXTRA_PAYLOAD, payloadJson)
        launchIntent.putExtra(IncomingCallService.EXTRA_ACTION_SOURCE, actionSource)
        startActivity(launchIntent)
    }

    private fun spacer(weight: Float): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                weight
            )
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
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
