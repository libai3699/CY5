import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_config.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.deviceId,
    required this.isRefreshingLines,
    required this.onLoginPressed,
    required this.onChatGptPressed,
    required this.onDevicesPressed,
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
  final bool isRefreshingLines;
  final VoidCallback onLoginPressed;
  final VoidCallback onChatGptPressed;
  final VoidCallback onDevicesPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback onNoticesPressed;
  final VoidCallback onPurchasePressed;
  final VoidCallback onRefreshLines;
  final String planLevel;
  final String remainingTimeText;
  final String trafficRemaining;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.75;

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
                        const Icon(Icons.copy_rounded, color: Colors.white70, size: 13),
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
                      leading: const Icon(Icons.account_circle_rounded, color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '登录账号',
                        style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                      onTap: onLoginPressed,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.account_circle_rounded, color: Color(0xFFE11D48), size: 24),
                      title: Text(
                        '已登录：$username',
                        style: const TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (username != null && username!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.devices_rounded, color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '已登录设备',
                        style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                        onDevicesPressed();
                      },
                    ),
                  if (username != null && username!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 24),
                      title: const Text(
                        '退出当前设备',
                        style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onLogoutPressed();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.smart_toy_rounded, color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      'ChatGPT',
                      style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      onChatGptPressed();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_rounded, color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      '消息通知',
                      style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      onNoticesPressed();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      '购买套餐',
                      style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      onPurchasePressed();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune_rounded, color: Color(0xFFE11D48), size: 24),
                    title: const Text(
                      '线路配置',
                      style: TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: isRefreshingLines
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE11D48)),
                          )
                        : IconButton(
                            tooltip: '刷新线路',
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFE11D48), size: 20),
                            onPressed: onRefreshLines,
                          ),
                    onTap: isRefreshingLines ? null : onRefreshLines,
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
