import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/platform_utils.dart';
import '../data/api_config.dart';
import 'app_toast.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.deviceId,
    required this.inviteCode,
    required this.isRefreshingLines,
    required this.onLoginPressed,
    required this.onChatGptPressed,
    required this.onDevicesPressed,
    required this.onDiscoverPressed,
    required this.onInvitePressed,
    required this.onLogoutPressed,
    required this.onNoticesPressed,
    required this.onPurchasePressed,
    required this.onRefreshLines,
    required this.planLevel,
    required this.remainingTimeText,
    required this.trafficRemaining,
    required this.username,
  });

  final String deviceId;
  final String inviteCode;
  final bool isRefreshingLines;
  final VoidCallback onLoginPressed;
  final VoidCallback onChatGptPressed;
  final VoidCallback onDevicesPressed;
  final VoidCallback onDiscoverPressed;
  final VoidCallback onInvitePressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback onNoticesPressed;
  final VoidCallback onPurchasePressed;
  final VoidCallback onRefreshLines;
  final String planLevel;
  final String remainingTimeText;
  final String trafficRemaining;
  final String? username;

  Widget _buildDrawerV2(BuildContext context, double width) {
    final loggedIn = username != null && username!.isNotEmpty;
    final headerPlanText = loggedIn ? planLevel : '未登录';
    final accountText = loggedIn ? username! : '免费体验';

    // 顶部较深粉 → 底部很浅粉白
    return SizedBox(
      width: width,
      child: Drawer(
        elevation: 0,
        backgroundColor: const Color(0xFFFFF8F9),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFD6E0),
                Color(0xFFFFE4EC),
                Color(0xFFFFF0F3),
                Color(0xFFFFF7F8),
                Color(0xFFFFFCFD),
              ],
              stops: [0, 0.22, 0.48, 0.76, 1],
            ),
          ),
          child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        const Color(0xFFFFE4EC).withValues(alpha: 0.48),
                        Colors.white.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF881337).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _drawerCopyRowV2(
                                  context,
                                  value: accountText,
                                  copiedMessage: '账号已复制',
                                  copyEnabled: loggedIn,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  headerPlanText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFBE5A74),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _drawerMetricV2(
                              '剩余流量',
                              trafficRemaining,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _drawerMetricV2(
                              '剩余时长',
                              remainingTimeText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _drawerCopyRowV2(
                        context,
                        label: '设备 ID',
                        value: deviceId,
                        copiedMessage: '设备 ID 已复制',
                        copyEnabled:
                            deviceId.isNotEmpty && deviceId != '读取中',
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                  children: [
                    if (!loggedIn)
                      _drawerItemV2(
                        icon: Icons.account_circle_rounded,
                        title: '登录账号',
                        onTap: onLoginPressed,
                      ),
                    if (loggedIn)
                      _drawerItemV2(
                        icon: Icons.devices_rounded,
                        title: '登录设备',
                        onTap: () {
                          Navigator.of(context).pop();
                          onDevicesPressed();
                        },
                      ),
                    _drawerItemV2(
                      icon: Icons.shopping_bag_rounded,
                      title: '购买套餐',
                      onTap: () {
                        Navigator.of(context).pop();
                        onPurchasePressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.explore_rounded,
                      title: '发现宝藏',
                      onTap: () {
                        Navigator.of(context).pop();
                        onDiscoverPressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.card_giftcard_rounded,
                      title: '邀请好友',
                      onTap: () {
                        Navigator.of(context).pop();
                        onInvitePressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.sync_rounded,
                      title: '刷新线路',
                      onTap: isRefreshingLines ? null : onRefreshLines,
                      trailing: isRefreshingLines
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE11D48),
                              ),
                            )
                          : null,
                    ),
                    if (loggedIn) ...[
                      const Divider(height: 22, color: Color(0xFFFFD5DF)),
                      _drawerItemV2(
                        icon: Icons.logout_rounded,
                        title: '退出当前设备',
                        onTap: () => _confirmLogout(context),
                        danger: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定退出当前设备？退出后需要重新登录。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认退出'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    onLogoutPressed();
  }

  Widget _drawerCopyRowV2(
    BuildContext context, {
    String label = '',
    required String value,
    required String copiedMessage,
    bool copyEnabled = true,
    bool light = false,
  }) {
    final canCopy = copyEnabled &&
        value.isNotEmpty &&
        value != '未登录' &&
        value != '免费体验' &&
        value != '读取中';

    final textStyle = TextStyle(
      color: light
          ? Colors.white.withValues(alpha: 0.96)
          : const Color(0xFF881337),
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );
    final iconColor = light
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFFBE5A74);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canCopy
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              AppToast.show(context, copiedMessage);
            }
          : null,
      child: Row(
        children: [
          Expanded(
            child: label.isEmpty
                ? Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: label, style: textStyle),
                        TextSpan(
                          text: '  ',
                          style: textStyle,
                        ),
                        TextSpan(text: value, style: textStyle),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (canCopy)
            SizedBox(
              width: 28,
              child: Icon(Icons.copy_rounded, color: iconColor, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _drawerMetricV2(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFFBE5A74), fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF881337),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItemV2({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Widget? trailing,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFE11D48) : const Color(0xFF8A4A52);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0x33E11D48),
          highlightColor: const Color(0x14E11D48),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Icon(icon, color: color, size: 22),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Center(
                    child: trailing ??
                        Icon(Icons.chevron_right_rounded,
                            color: color.withValues(alpha: 0.55), size: 19),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = PlatformUtils.getDrawerWidth(screenWidth);
    return _buildDrawerV2(context, width);
  }

  Widget _buildLegacyDrawerUnused(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = PlatformUtils.getDrawerWidth(screenWidth);

    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: const Color(0xFFFFF1F2),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(1),
            bottomRight: Radius.circular(1),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5C8A), Color(0xFFE11D48)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '套餐：$planLevel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '剩余流量：$trafficRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '剩余时长：$remainingTimeText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (deviceId != '读取中') {
                        Clipboard.setData(ClipboardData(text: deviceId));
                        AppToast.show(context, '设备 ID 已复制');
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '设备 ID：$deviceId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded,
                            color: Colors.white70, size: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (username == null || username!.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.account_circle_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '登录账号',
                        style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: Colors.grey),
                      onTap: onLoginPressed,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.account_circle_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: Text(
                        '已登录：$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  // ChatGPT 入口暂时隐藏（webview_flutter 在 Windows 不支持，待后续处理）
                  // ListTile(
                  //   leading: const Icon(Icons.smart_toy_rounded, color: Color(0xFFE11D48), size: 24),
                  //   title: const Text(
                  //     'ChatGPT',
                  //     style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                  //   ),
                  //   trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                  //   onTap: () {
                  //     Navigator.of(context).pop();
                  //     onChatGptPressed();
                  //   },
                  // ),
                  if (false) // 消息通知入口暂时隐藏
                    ListTile(
                      leading: const Icon(Icons.notifications_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '消息通知',
                        style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        onNoticesPressed();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.shopping_bag_rounded,
                        color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      '购买套餐',
                      style: TextStyle(
                          color: Color(0xFF881337),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      onPurchasePressed();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.explore_rounded,
                        color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      '\u53d1\u73b0\u5b9d\u85cf',
                      style: TextStyle(
                          color: Color(0xFF881337),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      onDiscoverPressed();
                    },
                  ),
                  if (username != null && username!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.card_giftcard_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '邀请有奖',
                        style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: inviteCode.isNotEmpty
                          ? Text('邀请码：$inviteCode',
                              style: const TextStyle(
                                  color: Color(0xFFBE5A74), fontSize: 12))
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        onInvitePressed();
                      },
                    ),
                  if (username != null && username!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.devices_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '已登录设备',
                        style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        onDevicesPressed();
                      },
                    ),
                  if (username != null && username!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.logout_rounded,
                          color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '退出当前设备',
                        style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onLogoutPressed();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Text(
                'v$kAppVersion',
                style: TextStyle(
                  color: const Color(0xFF881337).withOpacity(0.5),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
