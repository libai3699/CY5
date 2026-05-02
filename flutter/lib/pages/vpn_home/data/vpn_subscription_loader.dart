import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/vpn_node.dart';

class VpnSubscriptionLoader {
  const VpnSubscriptionLoader();

  Future<List<VpnNode>> load(String subscriptionUrl) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25);

    try {
      final request = await client.getUrl(Uri.parse(subscriptionUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'YuexiaVpn/1.0');
      request.headers.set(HttpHeaders.acceptHeader, '*/*');

      final response = await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 25));

      debugPrint('[SUBSCRIPTION] status: ${response.statusCode}, body length: ${body.length}');
      debugPrint('[SUBSCRIPTION] body preview: ${body.substring(0, body.length.clamp(0, 200))}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('订阅请求失败：HTTP ${response.statusCode}');
      }

      final content = _decodeSubscriptionBody(body);
      debugPrint('[SUBSCRIPTION] decoded length: ${content.length}');
      debugPrint('[SUBSCRIPTION] decoded preview: ${content.substring(0, content.length.clamp(0, 300))}');

      final nodes = _parseNodes(content);
      debugPrint('[SUBSCRIPTION] parsed nodes: ${nodes.length}');

      if (nodes.isEmpty) {
        throw Exception('订阅中没有解析到可用线路，内容开头：${_previewContent(content)}');
      }

      return nodes;
    } on SocketException catch (error) {
      throw Exception('订阅连接超时或网络不可达：${error.message}');
    } on HttpException catch (error) {
      throw Exception('订阅请求异常：${error.message}');
    } on HandshakeException catch (error) {
      throw Exception('订阅证书握手失败：${error.message}');
    } on TlsException catch (error) {
      throw Exception('订阅 TLS 连接失败：${error.message}');
    } on FormatException catch (error) {
      throw Exception('订阅格式解析失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _decodeSubscriptionBody(String body) {
    final trimmed = body.trim();

    // 如果内容已经是明文协议行（包含 ://），直接返回
    if (trimmed.contains('://')) {
      return trimmed;
    }

    // 尝试 base64 解码（订阅通常是 base64 编码的）
    try {
      // 去掉换行符后再解码（有些订阅会有换行）
      final noNewlines = trimmed.replaceAll(RegExp(r'\s'), '');
      final normalized = base64.normalize(noNewlines);
      final decoded = utf8.decode(base64.decode(normalized));
      debugPrint('[SUBSCRIPTION] base64 decoded, length: ${decoded.length}');
      return decoded;
    } on FormatException {
      // base64 解码失败，原样返回
      debugPrint('[SUBSCRIPTION] not base64, using raw content');
      return trimmed;
    }
  }

  List<VpnNode> _parseNodes(String content) {
    final uriNodes = _parseUriNodes(content);
    if (uriNodes.isNotEmpty) {
      return uriNodes;
    }

    final jsonNodes = _parseJsonNodes(content);
    if (jsonNodes.isNotEmpty) {
      return jsonNodes;
    }

    final clashNodes = _parseClashYamlNodes(content);
    if (clashNodes.isNotEmpty) {
      return clashNodes;
    }

    return const [];
  }

  List<VpnNode> _parseUriNodes(String content) {
    final lines = const LineSplitter()
        .convert(content)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(_isSupportedNodeLine)
        .toList();

    return [
      for (var i = 0; i < lines.length; i++) _parseNodeLine(lines[i], i),
    ];
  }

  List<VpnNode> _parseClashYamlNodes(String content) {
    final lines = const LineSplitter().convert(content);
    final nodes = <VpnNode>[];
    Map<String, String>? currentProxy;
    var inProxies = false;

    void commitCurrentProxy() {
      final proxy = currentProxy;
      if (proxy == null) {
        return;
      }

      final type = proxy['type'];
      final name = proxy['name'];

      if (type == null || name == null) {
        currentProxy = null;
        return;
      }

      nodes.add(
        VpnNode(
          id: 'clash-${nodes.length}',
          name: name,
          region: name,
          protocol: type.toUpperCase(),
          address: proxy['server'] ?? '',
          rawUri: jsonEncode(proxy),
        ),
      );
      currentProxy = null;
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trimRight();

      if (trimmed == 'proxies:') {
        inProxies = true;
        continue;
      }

      if (!inProxies) {
        continue;
      }

      if (trimmed.isNotEmpty && !rawLine.startsWith(' ') && trimmed != 'proxies:') {
        commitCurrentProxy();
        break;
      }

      final line = trimmed.trimLeft();
      if (line.startsWith('- ')) {
        commitCurrentProxy();
        currentProxy = {};
        _readYamlKeyValue(line.substring(2), currentProxy!);
        continue;
      }

      if (currentProxy != null) {
        _readYamlKeyValue(line, currentProxy!);
      }
    }

    commitCurrentProxy();
    return nodes;
  }

  List<VpnNode> _parseJsonNodes(String content) {
    try {
      final decoded = jsonDecode(content);
      final items = _extractJsonNodeItems(decoded);

      return [
        for (var i = 0; i < items.length; i++) _parseJsonNode(items[i], i),
      ];
    } on Object {
      return const [];
    }
  }

  List<Map<String, dynamic>> _extractJsonNodeItems(Object? decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in ['nodes', 'proxies', 'servers', 'data']) {
        final value = decoded[key];
        if (value is List) {
          final items = value.whereType<Map<String, dynamic>>().toList();
          if (items.isNotEmpty) {
            return items;
          }
        }
      }
    }

    return const [];
  }

  VpnNode _parseJsonNode(Map<String, dynamic> json, int index) {
    final name = _readFirstString(json, ['name', 'ps', 'remarks', 'remark', 'tag']) ?? '线路 ${index + 1}';
    final protocol = _readFirstString(json, ['type', 'protocol', 'network']) ?? 'UNKNOWN';
    final address = _readFirstString(json, ['server', 'address', 'add', 'host']) ?? '';

    return VpnNode(
      id: 'json-$index',
      name: name,
      region: name,
      protocol: protocol.toUpperCase(),
      address: address,
      rawUri: jsonEncode(json),
    );
  }

  bool _isSupportedNodeLine(String line) {
    return line.startsWith('ss://') ||
        line.startsWith('vmess://') ||
        line.startsWith('vless://') ||
        line.startsWith('trojan://');
  }

  VpnNode _parseNodeLine(String line, int index) {
    final protocol = line.substring(0, line.indexOf('://')).toUpperCase();
    final name = _readNodeName(line, protocol, index);

    return VpnNode(
      id: 'remote-$index',
      name: name,
      region: name,
      protocol: protocol,
      address: _readHost(line),
      rawUri: line,
    );
  }

  String _readNodeName(String line, String protocol, int index) {
    if (protocol == 'VMESS') {
      final name = _readVmessName(line);
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    final fragmentIndex = line.indexOf('#');
    if (fragmentIndex >= 0 && fragmentIndex < line.length - 1) {
      return Uri.decodeComponent(line.substring(fragmentIndex + 1));
    }

    return '$protocol ${index + 1}';
  }

  String? _readVmessName(String line) {
    try {
      final encoded = line.substring('vmess://'.length);
      final decoded = utf8.decode(base64.decode(base64.normalize(encoded)));
      final json = jsonDecode(decoded);

      if (json is Map<String, dynamic>) {
        return json['ps']?.toString();
      }
    } on Object {
      return null;
    }

    return null;
  }

  String _readHost(String line) {
    try {
      final uri = Uri.parse(line);
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
    } on FormatException {
      return '';
    }

    return '';
  }

  void _readYamlKeyValue(String line, Map<String, String> target) {
    final separatorIndex = line.indexOf(':');
    if (separatorIndex <= 0) {
      return;
    }

    final key = line.substring(0, separatorIndex).trim();
    final value = line.substring(separatorIndex + 1).trim();
    if (key.isEmpty || value.isEmpty) {
      return;
    }

    target[key] = _cleanYamlValue(value);
  }

  String _cleanYamlValue(String value) {
    var cleaned = value.trim();

    if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length >= 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    if (cleaned.startsWith("'") && cleaned.endsWith("'") && cleaned.length >= 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    return cleaned;
  }

  String? _readFirstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return null;
  }

  String _previewContent(String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 160) {
      return compact;
    }

    return '${compact.substring(0, 160)}...';
  }
}
