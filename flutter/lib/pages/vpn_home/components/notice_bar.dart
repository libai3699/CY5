import 'package:flutter/material.dart';

class NoticeBar extends StatelessWidget {
  const NoticeBar({
    super.key,
    required this.subscriptionUrl,
  });

  final String subscriptionUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '通知：正在使用订阅链接加载线路。',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF881337), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
