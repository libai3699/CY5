import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';
import 'vpn_subscription_loader.dart';
import '../components/node_label.dart';
import '../models/vpn_node.dart';

class RemoteVpnLineLoader {
  const RemoteVpnLineLoader();

  static const VpnSubscriptionLoader _subscriptionLoader = VpnSubscriptionLoader();

  Future<List<VpnNode>> load() async {
    try {
      final node = await _fetchRemoteLine();

      var rawUri = node.rawUri.trim();
      if (rawUri.isEmpty &&
          node.protocol.toUpperCase() == 'SUBSCRIPTION' &&
          node.address.isNotEmpty) {
        final addr = node.address.trim();
        rawUri = addr.startsWith('http://') || addr.startsWith('https://')
            ? addr
            : 'https://$addr';
      }

      if (rawUri.startsWith('http://') || rawUri.startsWith('https://')) {
        final allNodes = await _subscriptionLoader.load(rawUri);

        final filtered = allNodes.where((n) => _hasKnownRegion(n)).toList();
        final nodesToUse = filtered.isNotEmpty ? filtered : allNodes;

        if (nodesToUse.isEmpty) {
          return _loadFromCacheOrEmpty();
        }

        final normalized = _normalizeNodeIds(_compactNodes(nodesToUse));
        await _saveCacheList(normalized);
        return normalized;
      }

      await _saveCacheList([node]);
      return [node];
    } catch (e) {
      final fallback = await _loadFromCacheOrEmpty();
      if (fallback.isNotEmpty) {
        return fallback;
      }
      rethrow;
    }
  }

  Future<List<VpnNode>> _loadFromCacheOrEmpty() async {
    final cached = await _readCacheList();
    if (cached != null && cached.isNotEmpty) {
      final filteredCached = _normalizeNodeIds(
        _compactNodes(cached.where((n) => _hasKnownRegion(n)).toList()),
      );
      if (filteredCached.isNotEmpty) {
        return filteredCached;
      }
      return _normalizeNodeIds(_compactNodes(cached));
    }
    return const [];
  }

  bool _hasKnownRegion(VpnNode node) =>
      hasRecognizableRegion(node.name, hintRegion: node.region);

  List<VpnNode> _normalizeNodeIds(List<VpnNode> nodes) {
    return [
      for (var i = 0; i < nodes.length; i++)
        VpnNode(
          id: nodes[i].id.startsWith('filtered-') ? nodes[i].id : 'filtered-$i-${nodes[i].id}',
          name: nodes[i].name,
          region: nodes[i].region,
          protocol: nodes[i].protocol,
          address: nodes[i].address,
          rawUri: nodes[i].rawUri,
        ),
    ];
  }

  List<VpnNode> _compactNodes(List<VpnNode> nodes) {
    final seen = <String>{};
    final result = <VpnNode>[];
    for (final node in nodes) {
      final name = _displayNodeName(node.name);
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      result.add(VpnNode(
        id: node.id,
        name: name,
        region: node.region,
        protocol: node.protocol,
        address: node.address,
        rawUri: node.rawUri,
      ));
    }
    return result;
  }

  String _displayNodeName(String rawName) {
    var name = rawName.trim();
    try {
      name = Uri.decodeComponent(name);
    } catch (_) {}
    for (final separator in ['|', ' - ']) {
      final index = name.indexOf(separator);
      if (index > 0) name = name.substring(0, index).trim();
    }
    name = name.replaceAll(RegExp(r'[-_\s]*[\d.]+\s*[xX×倍][^\s]*'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    final flag = RegExp(r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*', unicode: true).firstMatch(name);
    if (flag == null) return name;
    final rest = name.substring(flag.end).trim();
    return rest.isEmpty ? flag.group(1)! : '${flag.group(1)!} $rest';
  }

  Future<VpnNode> _fetchRemoteLine() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(Uri.parse(kVpnLineApiUrl))
          .timeout(const Duration(seconds: 10));
      final response = await request
          .close()
          .timeout(const Duration(seconds: 10));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('线路接口请求失败：${response.statusCode}');
      }

      final decoded = jsonDecode(body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is! Map<String, dynamic>) {
        throw Exception('线路接口数据格式错误');
      }

      return VpnNode(
        id: data['id']?.toString() ?? 'default',
        name: data['name']?.toString() ?? '默认线路',
        region: data['region']?.toString() ?? 'Auto',
        protocol: data['protocol']?.toString() ?? 'VMESS',
        address: data['address']?.toString() ?? '',
        rawUri: data['raw_uri']?.toString() ?? '',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'vpn_nodes_cache.json'));
  }

  Future<void> _saveCacheList(List<VpnNode> nodes) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(nodes.map((n) => n.toJson()).toList()));
  }

  Future<List<VpnNode>?> _readCacheList() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(VpnNode.fromJson)
            .toList();
      }
    } catch (_) {}
    return null;
  }
}
