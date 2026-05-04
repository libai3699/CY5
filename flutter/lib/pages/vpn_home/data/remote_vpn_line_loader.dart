import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'vpn_subscription_loader.dart';
import '../models/vpn_node.dart';

class RemoteVpnLineLoader {
  const RemoteVpnLineLoader();

  static const VpnSubscriptionLoader _subscriptionLoader = VpnSubscriptionLoader();

  Future<List<VpnNode>> load() async {
    try {
      final node = await _fetchRemoteLine();
      debugPrint('[VPN_LINE] fetched: ${jsonEncode(node.toJson())}');

      final rawUri = node.rawUri.trim();
      if (rawUri.startsWith('http://') || rawUri.startsWith('https://')) {
        debugPrint('[VPN_LINE] subscription url: $rawUri');
        final allNodes = await _subscriptionLoader.load(rawUri);
        debugPrint('[VPN_LINE] total parsed: ${allNodes.length}');

        // 过滤：只保留能识别出地区的节点（国旗不是默认 🌐）
        final filtered = allNodes.where((n) => _hasKnownRegion(n.name)).toList();
        debugPrint('[VPN_LINE] after filter: ${filtered.length}');

        if (filtered.isEmpty) {
          debugPrint('[VPN_LINE] filter result empty');
          await _saveCacheList(const []);
          return const [];
        }

        final normalized = _normalizeNodeIds(_compactNodes(filtered));
        await _saveCacheList(normalized);
        return normalized;
      }

      // rawUri 是直接的协议链接（vmess:// 等）
      debugPrint('[VPN_LINE] parsed direct: ${jsonEncode(node.toJson())}');
      await _saveCacheList([node]);
      return [node];
    } catch (e) {
      debugPrint('[VPN_LINE] load error: $e');
      final cached = await _readCacheList();
      if (cached != null && cached.isNotEmpty) {
        final filteredCached = _normalizeNodeIds(
          _compactNodes(cached.where((n) => _hasKnownRegion(n.name)).toList()),
        );
        debugPrint('[VPN_LINE] using filtered cached ${filteredCached.length} nodes');
        return filteredCached;
      }
      rethrow;
    }
  }

  /// 判断节点名称是否包含可识别的地区关键词
  bool _hasKnownRegion(String name) {
    final lower = name.toLowerCase();
    const keywords = [
      'japan', 'jp', '日本',
      'korea', 'kr', '韩国',
      'hongkong', 'hong kong', 'hk', '香港',
      'taiwan', 'tw', '台湾',
      'singapore', 'sg', '新加坡',
      'usa', 'us', 'united states', '美国',
      'uk', 'united kingdom', 'britain', '英国',
      'germany', 'de', '德国',
      'france', 'fr', '法国',
      'canada', 'ca', '加拿大',
      'australia', 'au', '澳大利亚',
      'russia', 'ru', '俄罗斯',
      'india', 'in', '印度',
      'brazil', 'br', '巴西',
      'netherlands', 'nl', '荷兰',
      'turkey', 'tr', '土耳其',
      'vietnam', 'vn', '越南',
      'thailand', 'th', '泰国',
      'philippines', 'ph', '菲律宾',
      'indonesia', 'id', '印尼',
      'malaysia', 'my', '马来西亚',
      'argentina', 'ar', '阿根廷',
      'mexico', 'mx', '墨西哥',
      'uae', '阿联酋',
      'china', 'cn', '中国',
    ];

    // 也接受名称开头有国旗 emoji（区域指示符）
    final hasFlag = RegExp(r'^[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true).hasMatch(name.trim());
    if (hasFlag) return true;

    for (final kw in keywords) {
      // 用单词边界匹配，避免 "in" 匹配 "line" 等
      if (kw.length <= 2) {
        // 短缩写：要求前后是非字母
        final pattern = RegExp('(?<![a-z])${RegExp.escape(kw)}(?![a-z])');
        if (pattern.hasMatch(lower)) return true;
      } else {
        if (lower.contains(kw)) return true;
      }
    }
    return false;
  }

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
    // URL decode
    try { name = Uri.decodeComponent(name); } catch (_) {}
    // 去掉 | 或 ' - ' 后面的内容
    for (final separator in ['|', ' - ']) {
      final index = name.indexOf(separator);
      if (index > 0) name = name.substring(0, index).trim();
    }
    // 去掉倍率后缀，如 -0.1倍、x0.5、×2（必须有倍/x/×字符才去掉）
    name = name.replaceAll(RegExp(r'[-_\s]*[\d.]+\s*[xX×倍][^\s]*'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    final flag = RegExp(r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*', unicode: true).firstMatch(name);
    if (flag == null) return name;
    final rest = name.substring(flag.end).trim();
    return rest.isEmpty ? flag.group(1)! : '${flag.group(1)!} $rest';
  }

  Future<VpnNode> _fetchRemoteLine() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(kVpnLineApiUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
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

  // ── 缓存（存整个过滤后的列表）────────────────────────────────

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
