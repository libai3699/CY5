import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/api_config.dart';
import 'skeleton_box.dart';

class NoticeBar extends StatefulWidget {
  const NoticeBar({super.key, this.token, this.onStatusUpdate});

  final String? token;
  final void Function(String msg)? onStatusUpdate;

  @override
  State<NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<NoticeBar> {
  static const _carouselInterval = Duration(seconds: 3);

  List<String> _notices = [];
  int _current = 0;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCarousel() {
    _timer?.cancel();
    if (_notices.length <= 1) return;
    _timer = Timer.periodic(_carouselInterval, (_) {
      if (!mounted || _notices.length <= 1) return;
      setState(() => _current = (_current + 1) % _notices.length);
    });
  }

  List<String> _parseNoticeContents(dynamic data) {
    final dynamic list =
        data is Map && data['list'] is List ? data['list'] : data;
    if (list is! List) return const [];

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => e['content']?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _load() async {
    _timer?.cancel();
    if (mounted) {
      setState(() => _loading = true);
    }

    final url = widget.token == null ? kNoticesApiUrl : kUserNoticesApiUrl;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (widget.token != null) {
        request.headers.set('Authorization', 'Bearer ${widget.token}');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(body);
      final contents = _parseNoticeContents(decoded?['data']);
      if (!mounted) return;

      setState(() {
        _notices = contents;
        _current = 0;
        _loading = false;
      });
      _startCarousel();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _notices.isEmpty) return _buildSkeleton();
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
          const Icon(Icons.campaign_rounded,
              color: Color(0xFFE11D48), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 36,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(animation);
                  return ClipRect(
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: Align(
                  key: ValueKey<String>('$_current-${_notices[_current]}'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _notices[_current],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Color(0xFF881337),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_notices.length > 1) ...[
            const SizedBox(width: 8),
            Text(
              '${_current + 1}/${_notices.length}',
              style: const TextStyle(
                color: Color(0xFFBE5A74),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: SkeletonBox(
                width: double.infinity, height: 13, borderRadius: 6),
          ),
        ],
      ),
    );
  }
}
