package com.example.cy_vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.util.Log
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "MainActivity configureFlutterEngine")

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
                    val nodeName = call.argument<String>("name") ?: "VPN Server"

                    if (rawUri.isBlank()) {
                        result.success("线路配置为空")
                        return@setMethodCallHandler
                    }

                    try {
                        sendVpnStatus("connecting")
                        // TODO: 实现VPN连接逻辑
                        // 这里需要集成实际的VPN库（如V2ray、Clash等）
                        Log.d(TAG, "VPN start requested for $nodeName")
                        
                        // 模拟连接成功
                        android.os.Handler(mainLooper).postDelayed({
                            sendVpnStatus("connected")
                        }, 1000)
                        
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "StartVpn failed", e)
                        sendVpnStatus("error:${e.message ?: "启动失败"}")
                        result.success("启动失败: ${e.message}")
                    }
                }

                "stopVpn" -> {
                    // TODO: 实现VPN断开逻辑
                    Log.d(TAG, "VPN stop requested")
                    sendVpnStatus("disconnected")
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

    private fun sendVpnStatus(status: String) {
        runOnUiThread {
            Log.d(TAG, "sendVpnStatus: $status")
            statusEventSink?.success(status)
        }
    }
}
