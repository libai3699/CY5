import 'package:flutter/material.dart';

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(LoginDevice device) async {
    await _authService.removeDevice(widget.token, device.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F2),
        foregroundColor: const Color(0xFF881337),
        elevation: 0,
        title: const Text('已登录设备'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
          : _message != null
              ? Center(child: Text(_message!, style: const TextStyle(color: Color(0xFF881337))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      tileColor: Colors.white.withOpacity(0.78),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: const Icon(Icons.devices_rounded, color: Color(0xFFE11D48)),
                      title: Text(device.name, style: const TextStyle(color: Color(0xFF881337), fontWeight: FontWeight.w700)),
                      subtitle: Text('设备ID：${device.displayId}\n最后在线：${device.lastSeenAt.isEmpty ? '未知' : device.lastSeenAt}'),
                      trailing: IconButton(
                        tooltip: '移除设备',
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
                        onPressed: () => _remove(device),
                      ),
                    );
                  },
                ),
    );
  }
}
