import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatGptPage extends StatelessWidget {
  const ChatGptPage({super.key});

  static const String chatGptUrl = 'https://chatgpt.com/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F2),
        foregroundColor: const Color(0xFF881337),
        elevation: 0,
        title: const Text('ChatGPT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ChatGPT',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '当前版本未内置 WebView 依赖，可复制地址到浏览器打开。',
                style: TextStyle(color: Color(0xFF9F1239), fontSize: 14),
              ),
              const SizedBox(height: 16),
              SelectableText(
                chatGptUrl,
                style: const TextStyle(
                  color: Color(0xFFE11D48),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: chatGptUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ChatGPT 地址已复制'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制 ChatGPT 地址'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
