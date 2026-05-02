import 'package:flutter/material.dart';

import '../models/vpn_node.dart';
import 'node_label.dart';

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
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE11D48).withOpacity(0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NodeLabel(node: node, fontSize: 15),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled
                  ? const Color(0xFF881337)
                  : const Color(0xFF881337).withOpacity(0.35),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
