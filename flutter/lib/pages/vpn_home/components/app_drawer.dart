import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/platform_utils.dart';
import '../data/api_config.dart';

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
    return SizedBox(
      width: width,
      child: Drawer(
        elevation: 0,
        backgroundColor: const Color(0xFFFFF8FA),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3F1723), Color(0xFF881337)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
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
                              Text(
                                planLevel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                loggedIn ? '会员已登录' : '未登录',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFD5DF),
                                  fontSize: 11,
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
                            '\u5269\u4f59\u6d41\u91cf',
                            trafficRemaining,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _drawerMetricV2(
                            '\u5269\u4f59\u65f6\u957f',
                            remainingTimeText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _drawerCopyRowV2(
                      context,
                      label: '账号',
                      value: loggedIn ? username! : '未登录',
                      copiedMessage: '账号已复制',
                      copyEnabled: loggedIn,
                    ),
                    const SizedBox(height: 8),
                    _drawerCopyRowV2(
                      context,
                      label: '设备 ID',
                      value: deviceId,
                      copiedMessage: '设备 ID 已复制',
                      copyEnabled: deviceId.isNotEmpty && deviceId != '读取中',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                  children: [
                    if (!loggedIn)
                      _drawerItemV2(
                        icon: Icons.account_circle_rounded,
                        title: '\u767b\u5f55\u8d26\u53f7',
                        onTap: onLoginPressed,
                      ),
                    if (loggedIn)
                      _drawerItemV2(
                        icon: Icons.devices_rounded,
                        title: '\u5df2\u767b\u5f55\u8bbe\u5907',
                        onTap: () {
                          Navigator.of(context).pop();
                          onDevicesPressed();
                        },
                      ),
                    _drawerItemV2(
                      icon: Icons.shopping_bag_rounded,
                      title: '\u8d2d\u4e70\u5957\u9910',
                      onTap: () {
                        Navigator.of(context).pop();
                        onPurchasePressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.explore_rounded,
                      title: '\u53d1\u73b0\u5b9d\u85cf',
                      onTap: () {
                        Navigator.of(context).pop();
                        onDiscoverPressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.card_giftcard_rounded,
                      title: '\u9080\u8bf7\u597d\u53cb',
                      onTap: () {
                        Navigator.of(context).pop();
                        onInvitePressed();
                      },
                    ),
                    _drawerItemV2(
                      icon: Icons.sync_rounded,
                      title: '\u5237\u65b0\u7ebf\u8def',
                      onTap: isRefreshingLines ? null : onRefreshLines,
                      trailing: isRefreshingLines
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    if (loggedIn) ...[
                      const Divider(height: 22, color: Color(0xFFFFD5DF)),
                      _drawerItemV2(
                        icon: Icons.logout_rounded,
                        title: '\u9000\u51fa\u5f53\u524d\u8bbe\u5907',
                        onTap: () {
                          Navigator.of(context).pop();
                          onLogoutPressed();
                        },
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
    );
  }

  Widget _drawerCopyRowV2(
    BuildContext context, {
    required String label,
    required String value,
    required String copiedMessage,
    bool copyEnabled = true,
  }) {
    final canCopy = copyEnabled &&
        value.isNotEmpty &&
        value != '未登录' &&
        value != '读取中';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canCopy
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(copiedMessage),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label  $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canCopy)
            const SizedBox(
              width: 28,
              child: Icon(Icons.copy_rounded, color: Colors.white70, size: 17),
            ),
        ],
      ),
    );
  }

  Widget _drawerMetricV2(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 9)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
    final color = danger ? const Color(0xFFE11D48) : const Color(0xFF6F4B57);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('设备 ID 已复制'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
