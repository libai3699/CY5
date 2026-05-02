import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/api_config.dart';

class NoticeBar extends StatefulWidget {
  const NoticeBar({super.key, this.token});

  final String? token;

  @override
  State<NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<NoticeBar> {
  List<String> _notices = [];
  int _current = 0;
  Timer? _timer;
  WebSocket? _socket;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
  }

  @override
  void didUpdateWidget(covariant NoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _load();
      _connectSocket();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socket?.close();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    final client = HttpClient();
    try {
      final url = widget.token == null ? kNoticesApiUrl : kUserNoticesApiUrl;
      final request = await client.getUrl(Uri.parse(url));
      if (widget.token != null) {
        request.headers.set('Authorization', 'Bearer ${widget.token}');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(body);
      final data = decoded?['data'];
      final list = data is Map && data['list'] is List ? data['list'] : data;
      if (list is List && mounted) {
        final contents = list
            .whereType<Map<String, dynamic>>()
            .map((e) => e['content']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();

        setState(() {
          _notices = contents;
          _current = 0;
        });
        if (contents.length > 1) {
          _timer = Timer.periodic(const Duration(seconds: 4), (_) {
            if (!mounted) return;
            setState(() {
              _current = (_current + 1) % _notices.length;
            });
          });
        }
      }
    } catch (_) {
      // 静默处理通知加载失败。
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _connectSocket() async {
    await _socket?.close();
    _socket = null;
    final token = widget.token;
    if (token == null || token.isEmpty) return;

    try {
      final base = Uri.parse(kApiBaseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/api/public/ws/notices',
        queryParameters: {'token': token},
      );
      final socket = await WebSocket.connect(uri.toString());
      _socket = socket;
      socket.listen(
        (_) => _load(),
        onDone: () {
          if (mounted && identical(_socket, socket)) _socket = null;
        },
        onError: (_) {
          if (mounted && identical(_socket, socket)) _socket = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      // 静默处理实时通知连接失败。
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notices.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey(_current);
                  final offset = Tween<Offset>(
                    begin: Offset(0, isIncoming ? 1 : -1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return SlideTransition(position: offset, child: child);
                },
                child: Align(
                  key: ValueKey(_current),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _notices[_current],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(color: Color(0xFF881337), fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
