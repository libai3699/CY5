import 'package:flutter/material.dart';

import '../models/vpn_node.dart';

class NodeSelector extends StatelessWidget {
  const NodeSelector({
    super.key,
    required this.node,
    required this.enabled,
    required this.onPressed,
  });

  final VpnNode node;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF881337),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择线路',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }
}
