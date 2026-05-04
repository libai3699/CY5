import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/api_config.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  String? _content;
  String? _author;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(kQuoteApiUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        final data = decoded?['data'];
        if (data is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _content = data['content']?.toString();
              _author = data['author']?.toString();
              _loading = false;
            });
          }
        }
      }
    } catch (_) {
      // 静默失败，不显示语录卡片
    } finally {
      client.close(force: true);
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _content == null || _content!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: const Color(0xFFE11D48).withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                '每日一言',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _content!,
            style: const TextStyle(
              color: Color(0xFF881337),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (_author != null && _author!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '—— $_author',
              style: TextStyle(
                color: const Color(0xFF9F1239).withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
