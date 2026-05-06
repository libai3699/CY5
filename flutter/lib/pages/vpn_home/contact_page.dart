import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/common_page_top_bar.dart';
import 'data/api_config.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<_ContactItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(kContactApiUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final decoded = jsonDecode(body);
      final list = decoded?['data'];
      if (list is List && mounted) {
        setState(() {
          _items = list
              .whereType<Map<String, dynamic>>()
              .map(_ContactItem.fromJson)
              .toList();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Column(
          children: [
            const CommonPageTopBar(title: '联系我们', showRightButton: false),
            Expanded(child: _buildBody()),
          ],
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
        child: Text('暂无联系方式', style: TextStyle(color: Color(0xFF9F1239))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final isEmpty = item.value.isEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildIcon(item.key),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEmpty ? '未配置' : item.value,
                      style: TextStyle(
                        color: isEmpty
                            ? const Color(0xFFBB8899)
                            : const Color(0xFF881337),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEmpty)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已复制 ${item.label}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: const Color(0xFF9F1239),
                  tooltip: '复制',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(String key) {
    final asset = _assetFor(key);
    if (asset == null) {
      return const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFFE11D48), size: 32);
    }

    return Image.asset(
      asset,
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    );
  }

  String? _assetFor(String key) {
    if (key.contains('telegram') || key.contains('subscription')) {
      return 'assets/images/contact/telegram.png';
    }
    if (key.contains('wechat')) return 'assets/images/contact/wechat.png';
    if (key.contains('email')) return 'assets/images/contact/gmail.png';
    if (key.contains('qq')) return 'assets/images/contact/qq.png';
    return null;
  }
}

class _ContactItem {
  const _ContactItem({required this.key, required this.label, required this.value});
  final String key;
  final String label;
  final String value;

  factory _ContactItem.fromJson(Map<String, dynamic> json) => _ContactItem(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}
