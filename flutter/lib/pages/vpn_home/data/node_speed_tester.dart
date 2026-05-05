import 'dart:async';
import 'dart:io';

import '../models/vpn_node.dart';

class NodeSpeedTester {
  const NodeSpeedTester();

  /// 测试单个节点的延迟
  Future<int?> testNode(VpnNode node) async {
    try {
      final address = node.address;
      if (address.isEmpty) return null;

      // 提取主机名和端口
      final uri = Uri.tryParse('tcp://$address');
      if (uri == null) return null;

      final host = uri.host.isNotEmpty ? uri.host : address.split(':').first;
      final port = uri.hasPort ? uri.port : 443;

      // TCP 连接测速
      final stopwatch = Stopwatch()..start();
      
      Socket? socket;
      try {
        socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } finally {
        socket?.destroy();
      }
    } catch (e) {
      print('[SPEED_TEST] ${node.name} failed: $e');
      return null;
    }
  }

  /// 批量测试所有节点并返回排序后的列表
  Future<List<VpnNode>> testAndSortNodes(List<VpnNode> nodes) async {
    if (nodes.isEmpty) return nodes;

    print('[SPEED_TEST] 开始测速 ${nodes.length} 个节点');

    // 并发测试所有节点（最多同时测 10 个）
    final results = <VpnNode>[];
    final batchSize = 10;
    
    for (var i = 0; i < nodes.length; i += batchSize) {
      final batch = nodes.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((node) async {
          final latency = await testNode(node);
          return node.copyWith(latency: latency);
        }),
      );
      results.addAll(batchResults);
    }

    // 按延迟排序：有延迟的在前，延迟小的在前，无延迟的在后
    results.sort((a, b) {
      if (a.latency == null && b.latency == null) return 0;
      if (a.latency == null) return 1;
      if (b.latency == null) return -1;
      return a.latency!.compareTo(b.latency!);
    });

    print('[SPEED_TEST] 测速完成，最快: ${results.first.name} (${results.first.latency}ms)');
    
    return results;
  }
}
