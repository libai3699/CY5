import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.onMenuPressed,
    required this.onSupportPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onSupportPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu_rounded),
            tooltip: '菜单',
            color: const Color(0xFF9F1239),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              '9点9 VPN',
              style: TextStyle(
                color: Color(0xFF881337),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onSupportPressed,
            icon: const Icon(Icons.chat_bubble_rounded),
            tooltip: 'QQ客服',
            color: const Color(0xFF9F1239),
          ),
        ],
      ),
    );
  }
}
