import 'dart:async';
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
  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    print('[QUOTE] loading from: $kQuoteApiUrl');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(Uri.parse(kQuoteApiUrl))
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      print('[QUOTE] status: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        final data = decoded?['data'];
        if (data is Map<String, dynamic> && mounted) {
          setState(() {
            _content = data['content']?.toString();
            _loading = false;
          });
          print('[QUOTE] content: $_content');
        }
      }
    } catch (e) {
      print('[QUOTE] error: $e');
    } finally {
      client.close(force: true);
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _content == null || _content!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _content!,
                style: const TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: const Color(0xFF9F1239).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
