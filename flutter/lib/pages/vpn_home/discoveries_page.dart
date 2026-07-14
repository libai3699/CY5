import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/platform_utils.dart';
import 'components/common_page_top_bar.dart';
import 'data/api_config.dart';

class DiscoveryItem {
  const DiscoveryItem({
    required this.name,
    required this.iconUrl,
    required this.h5Url,
  });

  final String name;
  final String iconUrl;
  final String h5Url;

  factory DiscoveryItem.fromJson(Map<String, dynamic> json) => DiscoveryItem(
        name: json['name']?.toString() ?? '',
        iconUrl: json['icon_url']?.toString() ?? '',
        h5Url: json['h5_url']?.toString() ?? '',
      );
}

class DiscoveriesPage extends StatefulWidget {
  const DiscoveriesPage({super.key});

  @override
  State<DiscoveriesPage> createState() => _DiscoveriesPageState();
}

class _DiscoveriesPageState extends State<DiscoveriesPage> {
  late Future<List<DiscoveryItem>> _future = _load();

  Future<List<DiscoveryItem>> _load() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(Uri.parse(kDiscoveriesApiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException('request failed');
      }
      final decoded = jsonDecode(body);
      final raw = decoded is Map<String, dynamic> ? decoded['data'] : decoded;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => DiscoveryItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.name.isNotEmpty && item.h5Url.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final contentMaxWidth = PlatformUtils.getContentMaxWidth();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: contentMaxWidth ?? double.infinity,
            ),
            child: Column(
              children: [
                CommonPageTopBar(
                  title: '\u53d1\u73b0\u5b9d\u85cf',
                  showRightButton: true,
                  rightIcon: Icons.refresh_rounded,
                  onRightPressed: _retry,
                ),
                Expanded(
                  child: FutureBuilder<List<DiscoveryItem>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE11D48),
                          ),
                        );
                      }
                      final items = snapshot.data ?? const [];
                      if (items.isEmpty) {
                        return const _StatusView(
                          icon: Icons.explore_outlined,
                          text: '\u6682\u65e0\u53ef\u53d1\u73b0\u7684\u5185\u5bb9',
                        );
                      }
                      return RefreshIndicator(
                        color: const Color(0xFFE11D48),
                        onRefresh: () async {
                          _retry();
                          await _future;
                        },
                        child: GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 22, 16, 28),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 20,
                            childAspectRatio: .72,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _DiscoveryTile(item: items[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryTile extends StatelessWidget {
  const _DiscoveryTile({required this.item});

  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DiscoveryWebPage(title: item.name, url: item.h5Url),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x120F172A), blurRadius: 18, offset: Offset(0, 7)),
              ],
            ),
            child: Image.network(
              item.iconUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.widgets_rounded, color: Color(0xFFE11D48), size: 30),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w600, color: Color(0xFF27272A)),
          ),
        ],
      ),
    );
  }
}

class DiscoveryWebPage extends StatefulWidget {
  const DiscoveryWebPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<DiscoveryWebPage> createState() => _DiscoveryWebPageState();
}

class _DiscoveryWebPageState extends State<DiscoveryWebPage> {
  WebViewController? _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onProgress: (value) => mounted ? setState(() => _progress = value) : null,
        ))
        ..loadRequest(Uri.parse(widget.url));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '\u5237\u65b0',
            onPressed: _controller?.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 2),
              )
            : null,
      ),
      body: _controller == null
          ? Center(
              child: FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('\u5728\u6d4f\u89c8\u5668\u4e2d\u6253\u5f00'),
              ),
            )
          : WebViewWidget(controller: _controller!),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFA1A1AA)),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: Color(0xFF71717A))),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('\u91cd\u8bd5')),
          ],
        ],
      ),
    );
  }
}
