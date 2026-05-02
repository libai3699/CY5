import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.75;

    // 统一 Record 格式为 (IconData, String, String?)
    const items = [
      (Icons.tune_rounded, '线路配置', null),
      (Icons.language_rounded, '语言设置', '中文'),
      (Icons.security_rounded, '隐私政策', null),
      (Icons.description_rounded, '用户协议', null),
      (Icons.info_rounded, '关于我们', null),
    ];

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
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5C8A), Color(0xFFE11D48)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '9点9',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final item in items)
                    ListTile(
                      leading: Icon(item.$1, color: const Color(0xFFE11D48), size: 24),
                      title: Text(
                        item.$2,
                        style: const TextStyle(
                          color: Color(0xFF881337),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: item.$3 != null 
                        ? Text(
                            item.$3!,
                            style: TextStyle(
                              color: const Color(0xFF881337).withOpacity(0.5),
                              fontSize: 13,
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                '版本 v0.0.3',
                style: TextStyle(
                  color: const Color(0xFF881337).withOpacity(0.5),
                  fontSize: 12,
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
