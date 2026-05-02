import 'package:flutter/material.dart';

import '../models/vpn_node.dart';
import 'node_label.dart';

class NodePickerSheet extends StatelessWidget {
  const NodePickerSheet({
    super.key,
    required this.nodes,
    required this.selectedNode,
    required this.onSelected,
  });

  final List<VpnNode> nodes;
  final VpnNode selectedNode;
  final ValueChanged<VpnNode> onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择线路',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF881337),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: nodes.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Color(0xFFF3D4DC),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final node = nodes[index];
                      final isSelected = node.id == selectedNode.id;

                      return GestureDetector(
                        onTap: () => onSelected(node),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE11D48).withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE11D48).withOpacity(0.25)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: NodeLabel(node: node, fontSize: 15)),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFE11D48),
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
