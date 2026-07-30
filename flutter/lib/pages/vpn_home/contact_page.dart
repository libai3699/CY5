import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/platform_utils.dart';
import 'components/app_toast.dart';
import 'components/common_page_top_bar.dart';
import 'data/contact_service.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<ContactItem> _items = const [];
  bool _loading = true;
  bool _isRefreshing = false;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final items = await ContactService.instance.getContacts();

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _fromCache = false;
    });
  }

  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);

    final items = await ContactService.instance.refresh();

    if (!mounted) return;
    setState(() {
      if (items.isNotEmpty) {
        _items = items;
      }
      _isRefreshing = false;
      _fromCache = false;
    });
  }

  Future<void> _copyContact(ContactItem item) async {
    await Clipboard.setData(ClipboardData(text: item.value));
    if (!mounted) return;
    AppToast.show(context, '已复制 ${item.label}');
  }

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
                  title: '联系我们',
                  showRightButton: true,
                  rightIcon: Icons.refresh_rounded,
                  onRightPressed: _isRefreshing ? null : _refresh,
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE11D48)),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: const Color(0xFFE11D48).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '暂时无法加载联系方式',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请连接 VPN 后重试，或直接搜索我们的官方频道',
                style: TextStyle(
                  color: const Color(0xFF9F1239).withOpacity(0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isRefreshing ? null : _refresh,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
        ),
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
                  onPressed: () => _copyContact(item),
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
      return const Icon(
        Icons.mark_chat_unread_rounded,
        color: Color(0xFFE11D48),
        size: 32,
      );
    }
    return Image.asset(asset, width: 34, height: 34, fit: BoxFit.contain);
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
