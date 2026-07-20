/// Flavor 配置 — 通过 --dart-define=FLAVOR=vpn 或 --dart-define=FLAVOR=acc 注入
/// 构建命令：
///   flutter build apk --release --flavor vpn --dart-define=FLAVOR=vpn
///   flutter build apk --release --flavor acc --dart-define=FLAVOR=acc

const String _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'vpn');

class FlavorConfig {
  FlavorConfig._();

  /// 当前是否为加速器版本
  static bool get isAcc => _flavor == 'acc';

  /// 应用名称
  static String get appName => isAcc ? '9点9 加速器' : '9点9 VPN';

  /// 应用副标题（Drawer 底部等）
  static String get appSubtitle => isAcc ? '9点9 Accelerator' : '9点9 VPN';
}
