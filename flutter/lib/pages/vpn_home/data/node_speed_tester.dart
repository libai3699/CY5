import 'dart:async';
import 'dart:io';

import '../models/vpn_node.dart';

class NodeSpeedTester {
  const NodeSpeedTester({
    this.connectTimeout = const Duration(milliseconds: 1800),
    this.maxNodesToTest = 24,
    this.maxConcurrency = 16,
  });

  final Duration connectTimeout;
  final int maxNodesToTest;
  final int maxConcurrency;

  /// 测试单个节点的延迟
  Future<int?> testNode(VpnNode node) async {
    try {
      final address = node.address;
      if (address.isEmpty) return null;

      final uri = Uri.tryParse('tcp://$address');
      if (uri == null) return null;

      final host = uri.host.isNotEmpty ? uri.host : address.split(':').first;
      final port = uri.hasPort ? uri.port : 443;

      final stopwatch = Stopwatch()..start();

      Socket? socket;
      try {
        socket = await Socket.connect(
          host,
          port,
          timeout: connectTimeout,
        );
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } finally {
        socket?.destroy();
      }
    } catch (_) {
      return null;
    }
  }

  /// 批量测试节点并返回排序后的列表
  Future<List<VpnNode>> testAndSortNodes(List<VpnNode> nodes) async {
    if (nodes.isEmpty) return nodes;

    final targets = nodes.take(maxNodesToTest).toList();
    final rest = nodes.skip(maxNodesToTest).toList();
    final tested = await _testInParallel(targets);
    return _sortNodes([...tested, ...rest]);
  }

  Future<List<VpnNode>> _testInParallel(List<VpnNode> nodes) async {
    if (nodes.isEmpty) return nodes;

    final results = List<VpnNode?>.filled(nodes.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex += 1;
        if (index >= nodes.length) return;

        final latency = await testNode(nodes[index]);
        results[index] = nodes[index].copyWith(latency: latency);
      }
    }

    final workers = List<Future<void>>.generate(
      maxConcurrency.clamp(1, nodes.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    return [
      for (final node in results)
        if (node != null) node,
    ];
  }

  List<VpnNode> _sortNodes(List<VpnNode> nodes) {
    final sorted = [...nodes];
    sorted.sort((a, b) {
      if (a.latency == null && b.latency == null) return 0;
      if (a.latency == null) return 1;
      if (b.latency == null) return -1;
      return a.latency!.compareTo(b.latency!);
    });
    return sorted;
  }
}
