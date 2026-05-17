import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatGptPage extends StatefulWidget {
  const ChatGptPage({super.key});

  @override
  State<ChatGptPage> createState() => _ChatGptPageState();
}

class _ChatGptPageState extends State<ChatGptPage> {
  static const String chatGptUrl = 'https://chatgpt.com/';

  // WebView 仅在支持的平台（Android / iOS）上使用
  static bool get _supportsWebView =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_supportsWebView) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(chatGptUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE11D48),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('ChatGPT'),
        actions: [
          if (_supportsWebView)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
              tooltip: '刷新',
            ),
        ],
      ),
      body: _supportsWebView ? _buildWebView() : _buildDesktopFallback(context),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE11D48),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopFallback(BuildContext context) {
    // Windows / macOS / Linux：WebView 不可用，引导用户用系统浏览器打开
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_browser_rounded,
              size: 64,
              color: Color(0xFFE11D48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Windows 版暂不支持内嵌浏览器',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF881337),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              chatGptUrl,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF9F1239).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _openInBrowser(context),
              icon: const Icon(Icons.launch_rounded),
              label: const Text('用系统浏览器打开'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInBrowser(BuildContext context) {
    // 用 Process.run 调用系统默认浏览器（Windows / macOS / Linux 均适用）
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', chatGptUrl]);
      } else if (Platform.isMacOS) {
        Process.run('open', [chatGptUrl]);
      } else {
        Process.run('xdg-open', [chatGptUrl]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法打开浏览器：$e'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }
}
