import 'package:flutter/material.dart';

import '../models/vpn_node.dart';

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: nodes.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF3D4DC),
                    ),
                    itemBuilder: (context, index) {
                      final node = nodes[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: node.id == selectedNode.id
                            ? const Icon(Icons.check_circle, color: Color(0xFFE11D48))
                            : null,
                        onTap: () => onSelected(node),
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
