import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';
import 'data/auth_service.dart';

class LoginDevicesPage extends StatefulWidget {
  const LoginDevicesPage({super.key, required this.token});

  final String token;

  @override
  State<LoginDevicesPage> createState() => _LoginDevicesPageState();
}

class _LoginDevicesPageState extends State<LoginDevicesPage> {
  final AuthService _authService = const AuthService();
  List<LoginDevice> _devices = const [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final devices = await _authService.loadDevices(widget.token);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '\u8bbe\u5907\u5217\u8868\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
        _loading = false;
      });
    }
  }

  Future<void> _remove(LoginDevice device) async {
    await _authService.removeDevice(widget.token, device.id);
    await _load();
  }

  String _friendlyDeviceName(LoginDevice device) {
    final raw = device.name.trim();
    final lower = raw.toLowerCase();
    if (lower.contains('android')) return '\u5b89\u5353';
    if (lower.contains('windows')) return '\u7535\u8111';
    if (lower.contains('iphone') || lower.contains('ios')) return 'iPhone';
    if (lower.contains('mac')) return '\u7535\u8111';
    if (raw.isEmpty || lower == 'localhost') return '\u672a\u77e5\u8bbe\u5907';
    final cleaned = raw
        .replaceAll(
          RegExp('localhost', caseSensitive: false),
          '',
        )
        .trim();
    return cleaned.isEmpty ? '\u672a\u77e5\u8bbe\u5907' : cleaned;
  }

  IconData _deviceIcon(LoginDevice device) {
    final name = _friendlyDeviceName(device).toLowerCase();
    if (name.contains('windows') || name.contains('mac')) {
      return Icons.laptop_rounded;
    }
    return Icons.smartphone_rounded;
  }

  Widget _buildPageV2(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F2),
        foregroundColor: const Color(0xFF881337),
        elevation: 0,
        title: const Text('\u5df2\u767b\u5f55\u8bbe\u5907'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: PlatformUtils.getContentMaxWidth() ?? double.infinity,
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : _message != null
                  ? Center(
                      child: Text(_message!,
                          style: const TextStyle(color: Color(0xFF881337))))
                  : _devices.isEmpty
                      ? const Center(
                          child: Text(
                              '\u6682\u65e0\u5df2\u767b\u5f55\u8bbe\u5907',
                              style: TextStyle(color: Color(0xFF8A6872))))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFFFD5DF)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE4EA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(_deviceIcon(device),
                                        color: const Color(0xFFE11D48)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _friendlyDeviceName(device),
                                              style: const TextStyle(
                                                color: Color(0xFF3F1723),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (device.location.isNotEmpty) ...[
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  device.location,
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  style: const TextStyle(
                                                    color: Color(0xFFE11D48),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                            '\u8bbe\u5907\u7f16\u53f7  ${device.displayId.isEmpty ? '-' : device.displayId}',
                                            style: const TextStyle(
                                                color: Color(0xFF8A6872),
                                                fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '\u6700\u540e\u6d3b\u8dc3  ${device.lastSeenAt.isEmpty ? '\u672a\u77e5' : device.lastSeenAt}',
                                            style: const TextStyle(
                                                color: Color(0xFF8A6872),
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '\u79fb\u9664\u8bbe\u5907',
                                    onPressed: () => _remove(device),
                                    icon: const Icon(Icons.logout_rounded,
                                        color: Color(0xFFE11D48)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPageV2(context);
  }

  Widget _buildLegacyPageUnused(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F2),
        foregroundColor: const Color(0xFF881337),
        elevation: 0,
        title: const Text('已登录设备'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: PlatformUtils.getContentMaxWidth() ?? double.infinity,
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : _message != null
                  ? Center(
                      child: Text(_message!,
                          style: const TextStyle(color: Color(0xFF881337))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return ListTile(
                          tileColor: Colors.white.withOpacity(0.78),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          leading: const Icon(Icons.devices_rounded,
                              color: Color(0xFFE11D48)),
                          title: Text(device.name,
                              style: const TextStyle(
                                  color: Color(0xFF881337),
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '设备ID：${device.displayId}\n最后在线：${device.lastSeenAt.isEmpty ? '未知' : device.lastSeenAt}'),
                          trailing: IconButton(
                            tooltip: '移除设备',
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFE11D48)),
                            onPressed: () => _remove(device),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
