const String kApiBaseUrl = 'https://vpnapi.wangwei.tech';
//const String kApiBaseUrl = 'http://192.168.70.54:8989';

// ── 公开接口（无需登录/签名）──────────────────────────────────
const String kDeviceRegisterUrl = '$kApiBaseUrl/api/public/device/register';
const String kAuthLoginUrl = '$kApiBaseUrl/api/public/auth/login';
const String kAuthRegisterUrl = '$kApiBaseUrl/api/public/auth/register';
const String kVpnLineApiUrl = '$kApiBaseUrl/api/public/lines/default';
const String kAppStatusApiUrl = '$kApiBaseUrl/api/public/status';
const String kAppConfigApiUrl = '$kApiBaseUrl/api/public/config';
const String kNoticesApiUrl = '$kApiBaseUrl/api/public/notices';
const String kPlansApiUrl = '$kApiBaseUrl/api/public/plans';
const String kQuoteApiUrl = '$kApiBaseUrl/api/public/quote';
const String kPaymentConfigsApiUrl = '$kApiBaseUrl/api/public/payment-configs';
const String kContactApiUrl = '$kApiBaseUrl/api/public/contact';
const String kUserNoticesApiUrl = '$kApiBaseUrl/api/public/user/notices';
const String kUserStatusApiUrl = '$kApiBaseUrl/api/public/user/status';
const String kUserHeartbeatApiUrl = '$kApiBaseUrl/api/public/user/heartbeat';
const String kUserDevicesApiUrl = '$kApiBaseUrl/api/public/user/devices';
const String kUserLogoutApiUrl = '$kApiBaseUrl/api/public/user/logout';
const String kMarkNoticeReadUrl =
    '$kApiBaseUrl/api/app/user/notices'; // + /{id}/read
const String kMarkAllReadUrl = '$kApiBaseUrl/api/app/user/notices/read-all';
const String kTrackEventUrl = '$kApiBaseUrl/api/public/track';

/// App 版本号 — 与 pubspec.yaml 的 version 字段保持一致
/// 只需在这里改一处，Drawer 底部版本号自动更新
const String kAppVersion = '0.0.4';

/// Flavor 标识，通过 --dart-define=FLAVOR=vpn/acc 注入
const String kFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'vpn');
