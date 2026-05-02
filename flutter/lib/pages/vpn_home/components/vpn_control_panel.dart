import 'package:flutter/material.dart';

import '../models/vpn_node.dart';
import '../models/vpn_status.dart';
import 'node_selector.dart';
import 'power_button.dart';

class VpnControlPanel extends StatelessWidget {
  const VpnControlPanel({
    super.key,
    required this.status,
    required this.node,
    required this.message,
    required this.isLoadingNodes,
    required this.isBusy,
    required this.hasNodes,
    required this.onReloadNodes,
    required this.onPowerPressed,
    required this.onNodePressed,
  });

  final VpnStatus status;
  final VpnNode? node;
  final String? message;
  final bool isLoadingNodes;
  final bool isBusy;
  final bool hasNodes;
  final VoidCallback onReloadNodes;
  final VoidCallback onPowerPressed;
  final VoidCallback onNodePressed;

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
      padding: EdgeInsets.fromLTRB(20, compact ? 8 : 12, 20, 24),
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
          const Text(
            '剩余流量 1024.00 GB',
            style: TextStyle(
              color: Color(0xFF881337),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
