import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';

/// 联系方式数据模型
class ContactItem {
  const ContactItem({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;

  factory ContactItem.fromJson(Map<String, dynamic> json) => ContactItem(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'value': value,
      };
}

/// 联系方式服务
///
/// 职责：
/// 1. 首页启动时调用 [prefetch]，后台静默拉取并写入磁盘缓存
/// 2. [ContactPage] 调用 [getContacts]，优先返回内存缓存，
///    其次磁盘缓存，最后才发起网络请求
/// 3. 网络失败时自动降级到缓存，永远不会让页面空白
class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  // 内存缓存
  List<ContactItem>? _memCache;

  static const String _cacheFileName = 'contact_cache.json';
  static const Duration _networkTimeout = Duration(seconds: 6);

  // ── 公开 API ──────────────────────────────────────────────────────────────

  /// 首页启动时调用，后台静默预加载，不阻塞 UI
  Future<void> prefetch() async {
    // 已有内存缓存就不重复请求
    if (_memCache != null && _memCache!.isNotEmpty) return;
    // 先从磁盘加载到内存，让 ContactPage 能立即拿到数据
    await _loadFromDisk();
    // 再后台刷新一次网络数据
    _fetchFromNetwork().ignore();
  }

  /// 获取联系方式列表
  ///
  /// 返回顺序：内存缓存 → 磁盘缓存 → 网络请求 → 空列表
  Future<List<ContactItem>> getContacts() async {
    // 1. 内存缓存命中
    if (_memCache != null && _memCache!.isNotEmpty) {
      // 后台刷新，不阻塞返回
      _fetchFromNetwork().ignore();
      return List.unmodifiable(_memCache!);
    }

    // 2. 磁盘缓存
    final disk = await _loadFromDisk();
    if (disk.isNotEmpty) {
      _fetchFromNetwork().ignore();
      return List.unmodifiable(disk);
    }

    // 3. 直接网络请求（首次安装、缓存被清除）
    final fresh = await _fetchFromNetwork();
    return List.unmodifiable(fresh);
  }

  /// 强制刷新（用户手动点击刷新按钮）
  Future<List<ContactItem>> refresh() async {
    final fresh = await _fetchFromNetwork();
    return List.unmodifiable(fresh.isNotEmpty ? fresh : (_memCache ?? []));
  }

  // ── 内部实现 ──────────────────────────────────────────────────────────────

  Future<List<ContactItem>> _fetchFromNetwork() async {
    final client = HttpClient()
      ..connectionTimeout = _networkTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse(kContactApiUrl))
          .timeout(_networkTimeout);
      final response =
          await request.close().timeout(_networkTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _memCache ?? [];
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      final list = decoded?['data'];
      if (list is! List || list.isEmpty) return _memCache ?? [];

      final items = list
          .whereType<Map<String, dynamic>>()
          .map(ContactItem.fromJson)
          .where((c) => c.label.isNotEmpty)
          .toList();

      if (items.isNotEmpty) {
        _memCache = items;
        await _saveToDisk(items);
      }

      return items;
    } catch (_) {
      // 网络失败静默降级
      return _memCache ?? [];
    } finally {
      client.close(force: true);
    }
  }

  Future<List<ContactItem>> _loadFromDisk() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(ContactItem.fromJson)
          .where((c) => c.label.isNotEmpty)
          .toList();
      if (items.isNotEmpty) _memCache = items;
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToDisk(List<ContactItem> items) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode(items.map((c) => c.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
      // 写入失败不影响功能
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _cacheFileName));
  }
}
