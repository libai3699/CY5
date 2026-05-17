import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';
import 'components/common_page_top_bar.dart';
import 'data/api_config.dart';
import 'data/auth_service.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<_NoticeItem> _items = [];
  bool _loading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await const AuthService().loadSession();
    _token = session?.token;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = HttpClient();
    try {
      final url = _token != null ? kUserNoticesApiUrl : kNoticesApiUrl;
      final request = await client.getUrl(Uri.parse(url));
      if (_token != null) {
        request.headers.set('Authorization', 'Bearer $_token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(body);
      final data = decoded?['data'];

      List<dynamic> list;
      if (data is Map && data['list'] is List) {
        list = data['list'] as List;
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      if (mounted) {
        setState(() {
          _items = list
              .whereType<Map<String, dynamic>>()
              .map(_NoticeItem.fromJson)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _markRead(int id) async {
    if (_token == null) return;
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$kMarkNoticeReadUrl/$id/read'),
      );
      request.headers.set('Authorization', 'Bearer $_token');
      await (await request.close()).drain<void>();
      // 本地更新
      setState(() {
        for (final item in _items) {
          if (item.id == id) item.isRead = true;
        }
      });
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _markAllRead() async {
    if (_token == null) return;
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(kMarkAllReadUrl));
      request.headers.set('Authorization', 'Bearer $_token');
      await (await request.close()).drain<void>();
      setState(() {
        for (final item in _items) {
          item.isRead = true;
        }
      });
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  int get _unreadCount => _items.where((e) => !e.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: PlatformUtils.getContentMaxWidth() ?? double.infinity,
            ),
            child: Column(
              children: [
                CommonPageTopBar(
                  title: '消息通知',
                  showRightButton: _token != null && _unreadCount > 0,
                  rightIcon: Icons.done_all_rounded,
                  onRightPressed: _markAllRead,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)));
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFFE8B4BE)),
            SizedBox(height: 12),
            Text('暂无通知', style: TextStyle(color: Color(0xFF9F1239), fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return GestureDetector(
          onTap: () => _markRead(item.id),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.isRead
                  ? Colors.white.withOpacity(0.6)
                  : Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.isRead
                    ? Colors.transparent
                    : const Color(0xFFE11D48).withOpacity(0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 未读红点
                Container(
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isRead
                        ? Colors.transparent
                        : const Color(0xFFE11D48),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.type == 2)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '重要',
                                style: TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.content,
                              style: TextStyle(
                                color: item.isRead
                                    ? const Color(0xFF9F1239).withOpacity(0.6)
                                    : const Color(0xFF881337),
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.createdAt,
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
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

class _NoticeItem {
  _NoticeItem({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  final int id;
  final String content;
  final int type;
  final String createdAt;
  bool isRead;

  factory _NoticeItem.fromJson(Map<String, dynamic> json) => _NoticeItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        content: json['content']?.toString() ?? '',
        type: (json['type'] as num?)?.toInt() ?? 1,
        createdAt: _formatDate(json['created_at']?.toString() ?? ''),
        isRead: json['is_read'] == true,
      );

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}
