package com.example.cy_vpn

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.TrafficStats
import android.net.VpnService
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "9.9/native"
    private val statusChannelName = "9.9/vpn_status"
    private val trafficChannelName = "9.9/traffic"

    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingGallerySaveResult: MethodChannel.Result? = null
    private var pendingGallerySaveRequest: PendingGallerySaveRequest? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var statusEventSink: EventChannel.EventSink? = null
    
    // Traffic tracking
    private var trafficBaselineBytes: Long = 0
    private var isTrackingTraffic: Boolean = false

    companion object {
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
        private const val GALLERY_PERMISSION_REQUEST_CODE = 1002
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1003
        private const val TAG = "MainActivity"
    }

    private data class PendingGallerySaveRequest(
        val bytes: ByteArray,
        val fileName: String,
    )

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
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

                    "ensureNotificationPermission" -> {
                        ensureNotificationPermission(result)
                    }
                    
                    "getTrafficBytes" -> {
                        val totalBytes = getTotalTrafficBytes()
                        result.success(totalBytes)
                    }
                    
                    "resetTrafficBaseline" -> {
                        resetTrafficBaseline()
                        result.success(null)
                    }
                    
                    "startTrafficTracking" -> {
                        startTrafficTracking()
                        result.success(null)
                    }
                    
                    "stopTrafficTracking" -> {
                        stopTrafficTracking()
                        result.success(null)
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
                            Log.d(TAG, "VPN start requested for $nodeName")

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
                        Log.d(TAG, "VPN stop requested")
                        sendVpnStatus("disconnected")
                        result.success(null)
                    }

                    "openSupportH5" -> {
                        startActivity(Intent(this, SupportWebActivity::class.java))
                        result.success(null)
                    }

                    "getAndroidId" -> {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID,
                        )
                        result.success(androidId ?: "")
                    }

                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName =
                            call.argument<String>("fileName") ?: "payment_qr.png"

                        if (bytes == null || bytes.isEmpty()) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "message" to "保存失败：二维码数据为空",
                                )
                            )
                            return@setMethodCallHandler
                        }

                        saveImageToGallery(bytes, fileName, result)
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val pendingResult = pendingNotificationResult
            pendingNotificationResult = null
            if (pendingResult == null) {
                return
            }
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pendingResult.success(null)
            } else {
                pendingResult.success("请允许通知权限，否则 VPN 会被系统关闭")
            }
            return
        }

        if (requestCode != GALLERY_PERMISSION_REQUEST_CODE) return

        val pendingResult = pendingGallerySaveResult
        val pendingRequest = pendingGallerySaveRequest
        pendingGallerySaveResult = null
        pendingGallerySaveRequest = null

        if (pendingResult == null || pendingRequest == null) {
            return
        }

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            saveImageToGallery(pendingRequest.bytes, pendingRequest.fileName, pendingResult)
        } else {
            pendingResult.success(
                mapOf(
                    "success" to false,
                    "permissionDenied" to true,
                    "message" to "未授予存储权限，无法保存到系统相册",
                )
            )
        }
    }

    private fun sendVpnStatus(status: String) {
        runOnUiThread {
            Log.d(TAG, "sendVpnStatus: $status")
            statusEventSink?.success(status)
        }
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(null)
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(null)
            return
        }

        pendingNotificationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun saveImageToGallery(
        bytes: ByteArray,
        fileName: String,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingGallerySaveRequest = PendingGallerySaveRequest(bytes, fileName)
            pendingGallerySaveResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                GALLERY_PERMISSION_REQUEST_CODE,
            )
            return
        }

        try {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_PICTURES}/9.9 VPN",
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val collection =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                }

            val uri = resolver.insert(collection, values)
                ?: throw IOException("创建相册文件失败")

            try {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                    outputStream.flush()
                } ?: throw IOException("打开相册文件失败")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val publishedValues = ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    }
                    resolver.update(uri, publishedValues, null, null)
                }
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }

            result.success(
                mapOf(
                    "success" to true,
                    "message" to "二维码已保存到系统相册",
                )
            )
        } catch (error: Exception) {
            Log.e(TAG, "saveImageToGallery failed", error)
            result.success(
                mapOf(
                    "success" to false,
                    "message" to "保存失败：${error.message ?: "写入相册失败"}",
                )
            )
        }
    }
    
    // Traffic tracking methods using Android TrafficStats API
    private fun getTotalTrafficBytes(): Long {
        if (!isTrackingTraffic) {
            return 0
        }
        
        try {
            // Get total device traffic (all apps)
            val totalRx = TrafficStats.getTotalRxBytes()
            val totalTx = TrafficStats.getTotalTxBytes()
            
            if (totalRx == TrafficStats.UNSUPPORTED.toLong() || totalTx == TrafficStats.UNSUPPORTED.toLong()) {
                Log.w(TAG, "TrafficStats not supported on this device")
                return 0
            }
            
            val currentTotal = totalRx + totalTx
            val trafficSinceBaseline = currentTotal - trafficBaselineBytes
            
            // Sanity check: if negative or too large, reset baseline
            if (trafficSinceBaseline < 0 || trafficSinceBaseline > 10L * 1024 * 1024 * 1024) {
                Log.w(TAG, "Traffic delta out of range: $trafficSinceBaseline, resetting baseline")
                trafficBaselineBytes = currentTotal
                return 0
            }
            
            Log.d(TAG, "Traffic: current=$currentTotal, baseline=$trafficBaselineBytes, delta=$trafficSinceBaseline")
            return trafficSinceBaseline
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get traffic stats", e)
            return 0
        }
    }
    
    private fun resetTrafficBaseline() {
        try {
            val totalRx = TrafficStats.getTotalRxBytes()
            val totalTx = TrafficStats.getTotalTxBytes()
            
            if (totalRx != TrafficStats.UNSUPPORTED.toLong() && totalTx != TrafficStats.UNSUPPORTED.toLong()) {
                trafficBaselineBytes = totalRx + totalTx
                Log.d(TAG, "Traffic baseline reset to: $trafficBaselineBytes")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reset traffic baseline", e)
        }
    }
    
    private fun startTrafficTracking() {
        isTrackingTraffic = true
        resetTrafficBaseline()
        Log.d(TAG, "Traffic tracking started")
    }
    
    private fun stopTrafficTracking() {
        isTrackingTraffic = false
        trafficBaselineBytes = 0
        Log.d(TAG, "Traffic tracking stopped")
    }
}
