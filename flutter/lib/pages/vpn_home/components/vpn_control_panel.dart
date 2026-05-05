import 'package:flutter/material.dart';

import '../models/vpn_node.dart';
import '../models/vpn_status.dart';
import 'node_selector.dart';
import 'power_button.dart';

class VpnControlPanel extends StatelessWidget {
  const VpnControlPanel({
    super.key,
    required this.hasNodes,
    required this.isBusy,
    required this.isLoadingNodes,
    required this.message,
    required this.node,
    required this.onNodePressed,
    required this.onPowerPressed,
    required this.onReloadNodes,
    required this.remainingTimeText,
    required this.status,
    required this.trafficRemaining,
  });

  final bool hasNodes;
  final bool isBusy;
  final bool isLoadingNodes;
  final String? message;
  final VpnNode? node;
  final VoidCallback onNodePressed;
  final VoidCallback onPowerPressed;
  final VoidCallback onReloadNodes;
  final String remainingTimeText;
  final VpnStatus status;
  final String trafficRemaining;

  @override
  Widget build(BuildContext context) {
    final connected = status == VpnStatus.connected;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 720;
    final statusText = switch (status) {
      VpnStatus.disconnected => '点击连接',
      VpnStatus.connecting => '连接中',
      VpnStatus.connected => '点击关闭',
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 6, 20, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * (compact ? 0.58 : 0.66),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PowerButton(
              connected: connected,
              busy: isBusy,
              compact: compact,
              onPressed: onPowerPressed,
            ),
            SizedBox(height: compact ? 14 : 22),
            Text(
              statusText,
              style: const TextStyle(
                color: Color(0xFF881337),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12),
              ),
            ],
            SizedBox(height: compact ? 20 : 34),
            Column(
              children: [
                _InfoChip(
                  icon: Icons.wifi_rounded,
                  label: '流量',
                  value: trafficRemaining,
                ),
                const SizedBox(height: 10),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '时长',
                  value: remainingTimeText,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isLoadingNodes)
              const CircularProgressIndicator(color: Color(0xFFE11D48))
            else if (node != null)
              NodeSelector(
                node: node!,
                enabled: !connected && !isBusy,
                onPressed: onNodePressed,
              )
            else
              Column(
                children: [
                  if (message != null) ...[
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: onReloadNodes,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(hasNodes ? '重新加载线路' : '加载线路'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE11D48)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 28),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF881337), fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
