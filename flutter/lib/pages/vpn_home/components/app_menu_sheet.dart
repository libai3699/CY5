import 'package:flutter/material.dart';

class AppMenuSheet extends StatelessWidget {
  const AppMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.tune_rounded, '线路配置'),
      (Icons.security_rounded, '隐私政策'),
      (Icons.description_rounded, '用户协议'),
      (Icons.info_rounded, '关于9点9 VPN'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              ListTile(
                leading: Icon(item.$1, color: const Color(0xFFE11D48)),
                title: Text(item.$2),
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
