# ============================================================
# Flutter 基础保留
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-keep class io.flutter.plugin.** { *; }

# ============================================================
# flutter_v2ray / V2Ray VPN 服务保留
# 混淆会导致 VPN Service 类名变化，Android 系统找不到服务 → VPN 断开
# ============================================================
-keep class com.v2ray.** { *; }
-keep class com.github.shadowsocks.** { *; }
-keep class go.** { *; }
-keep class libv2ray.** { *; }

# flutter_v2ray 插件本身
-keep class dev.hexadev.flutter_v2ray.** { *; }
-keep class dev.hexadev.** { *; }

# VPN Service 和 Proxy Service（系统通过 Manifest 反射调用，不能混淆）
-keep class * extends android.net.VpnService { *; }
-keep class * extends android.app.Service { *; }

# ============================================================
# 联系客服页面 / WebView 相关
# 混淆会导致 WebView 相关类找不到 → 空白页
# ============================================================
-keep class android.webkit.** { *; }
-keep class com.example.cy_vpn.SupportWebActivity { *; }

# ============================================================
# Kotlin / Coroutines
# ============================================================
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ============================================================
# JSON 序列化（防止 data class 字段被混淆）
# ============================================================
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ============================================================
# 通用安全规则
# ============================================================
# 保留所有 Parcelable 实现（Intent 传参用）
-keep class * implements android.os.Parcelable { *; }
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留注解
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
