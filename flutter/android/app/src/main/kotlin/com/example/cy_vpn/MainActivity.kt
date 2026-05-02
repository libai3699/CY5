package com.example.cy_vpn

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.util.Log
import dev.dev7.lib.v2ray.V2rayController
import dev.dev7.lib.v2ray.utils.V2rayConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "cy_vpn/native"
    private val statusChannelName = "cy_vpn/vpn_status"

    private var pendingVpnResult: MethodChannel.Result? = null
    private var statusEventSink: EventChannel.EventSink? = null

    companion object {
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
        private const val TAG = "MainActivity"
    }

    private val v2rayStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                val extras = intent?.extras ?: return
                val state = extras.getSerializable(
                    V2rayConstants.SERVICE_CONNECTION_STATE_BROADCAST_EXTRA
                ) as? V2rayConstants.CONNECTION_STATES ?: return

                Log.d(TAG, "v2rayStateReceiver received: $state")

                when (state) {
                    V2rayConstants.CONNECTION_STATES.CONNECTED -> sendVpnStatus("connected")
                    V2rayConstants.CONNECTION_STATES.CONNECTING -> sendVpnStatus("connecting")
                    V2rayConstants.CONNECTION_STATES.DISCONNECTED -> sendVpnStatus("disconnected")
                }
            } catch (e: Exception) {
                Log.w(TAG, "v2rayStateReceiver error: ${e.message}")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        registerV2rayReceiver()
    }

    override fun onPause() {
        try {
            unregisterReceiver(v2rayStateReceiver)
        } catch (_: Exception) {}
        super.onPause()
    }

    private fun registerV2rayReceiver() {
        try {
            unregisterReceiver(v2rayStateReceiver)
        } catch (_: Exception) {}
        val filter = IntentFilter(V2rayConstants.V2RAY_SERVICE_STATICS_BROADCAST_INTENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(v2rayStateReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(v2rayStateReceiver, filter)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化 V2ray
        V2rayController.init(this, R.mipmap.ic_launcher, "9点9 VPN")
        Log.d(TAG, "V2rayController.init done")

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, statusChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    statusEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val prepareIntent = VpnService.prepare(this)
                    if (prepareIntent == null) {
                        result.success(null)
                    } else {
                        pendingVpnResult = result
                        startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
                    }
                }

                "startVpn" -> {
                    val rawUri = call.argument<String>("rawUri") ?: ""
                    val nodeName = call.argument<String>("name") ?: "V2ray Server"

                    if (rawUri.isBlank()) {
                        result.success("线路配置为空")
                        return@setMethodCallHandler
                    }

                    try {
                        sendVpnStatus("connecting")

                        // 注意：使用大写的 StartV2ray (跳过内置权限检查，因为我们自己处理了)
                        @Suppress("DEPRECATION")
                        V2rayController.StartV2ray(this, nodeName, rawUri, null)

                        Log.d(TAG, "V2rayController.StartV2ray called for $nodeName")
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "StartV2ray failed", e)
                        sendVpnStatus("error:${e.message ?: "启动失败"}")
                        result.success("启动失败: ${e.message}")
                    }
                }

                "stopVpn" -> {
                    V2rayController.stopV2ray(this)
                    result.success(null)
                }

                "openSupportH5" -> {
                    startActivity(Intent(this, SupportWebActivity::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val pending = pendingVpnResult
            pendingVpnResult = null
            if (resultCode == Activity.RESULT_OK) {
                pending?.success(null)
            } else {
                pending?.success("用户拒绝了权限")
            }
        }
    }

    fun sendVpnStatus(status: String) {
        runOnUiThread {
            Log.d(TAG, "sendVpnStatus: $status")
            statusEventSink?.success(status)
        }
    }
}
