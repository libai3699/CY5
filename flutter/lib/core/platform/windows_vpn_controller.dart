import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../pages/vpn_home/models/vpn_node.dart';

class WindowsVpnController {
  static Process? _v2rayProcess;
  static const int _localPort = 10808;
  static const int _localHttpPort = 10809;

  /// 启动 V2ray 代理
  static Future<bool> start(VpnNode node) async {
    if (!Platform.isWindows) return false;
    
    try {
      await stop();

      final appDir = await getApplicationSupportDirectory();
      final v2rayDir = Directory(p.join(appDir.path, 'v2ray'));
      if (!await v2rayDir.exists()) {
        await v2rayDir.create(recursive: true);
      }

      final configFile = File(p.join(v2rayDir.path, 'config.json'));
      final configJson = _generateConfig(node);
      await configFile.writeAsString(jsonEncode(configJson));

      String v2rayPath = p.join(Directory.current.path, 'bin', 'windows', 'v2ray.exe');
      if (!await File(v2rayPath).exists()) {
        v2rayPath = p.join(p.dirname(Platform.resolvedExecutable), 'v2ray.exe');
      }

      if (!await File(v2rayPath).exists()) {
        throw Exception('找不到 v2ray.exe');
      }

      // 使用常规模式，不使用 Windows 特有的 .hidden
      _v2rayProcess = await Process.start(
        v2rayPath,
        ['-config', configFile.path],
        runInShell: false,
      );

      _setSystemProxy(true, '127.0.0.1:$_localHttpPort');
      return true;
    } catch (e) {
      print('WindowsVpnController Error: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isWindows) return;
    if (_v2rayProcess != null) {
      _v2rayProcess!.kill();
      _v2rayProcess = null;
    }
    await Process.run('taskkill', ['/F', '/IM', 'v2ray.exe', '/T']);
    _setSystemProxy(false, '');
  }

  static Map<String, dynamic> _generateConfig(VpnNode node) {
    return {
      "log": {"loglevel": "warning"},
      "inbounds": [
        {"port": _localPort, "protocol": "socks", "settings": {"auth": "noauth", "udp": true}},
        {"port": _localHttpPort, "protocol": "http", "settings": {}}
      ],
      "outbounds": [
        {
          "protocol": "vless",
          "settings": {
            "vnext": [{"address": node.address, "port": 443, "users": [{"id": "uuid", "encryption": "none"}]}]
          },
          "streamSettings": {"network": "ws", "security": "tls"}
        },
        {"protocol": "freedom", "tag": "direct"}
      ]
    };
  }

  /// 使用动态库方式设置代理，避免在安卓上报错
  static void _setSystemProxy(bool enabled, String server) {
    if (!Platform.isWindows) return;

    try {
      final advapi32 = DynamicLibrary.open('advapi32.dll');
      final wininet = DynamicLibrary.open('wininet.dll');

      // 这里简化处理，通过命令行修改注册表，这是最兼容跨平台编译的方式
      final enableVal = enabled ? '1' : '0';
      Process.runSync('reg', [
        'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', enableVal, '/f'
      ]);

      if (enabled) {
        Process.runSync('reg', [
          'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
          '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', server, '/f'
        ]);
      }

      // 通知系统刷新设置 (通过 wininet.dll)
      // INTERNET_OPTION_SETTINGS_CHANGED = 39
      // INTERNET_OPTION_REFRESH = 37
      final internetSetOption = wininet.lookupFunction<
          Int8 Function(IntPtr, Uint32, Pointer, Uint32),
          int Function(int, int, Pointer, int)>('InternetSetOptionW');
      
      internetSetOption(0, 39, nullptr, 0);
      internetSetOption(0, 37, nullptr, 0);
      
    } catch (e) {
      print('SetProxy Error: $e');
    }
  }
}
