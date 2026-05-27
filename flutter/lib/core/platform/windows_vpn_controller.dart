import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../pages/vpn_home/models/vpn_node.dart';

class WindowsVpnController {
  static const List<String> _coreNames = ['xray.exe', 'v2ray.exe'];
  static const List<String> _corePathEnvKeys = [
    '9.9_CORE_PATH',
    'XRAY_EXE_PATH',
    'V2RAY_EXE_PATH',
  ];
  static const int _localHttpPort = 10809;
  static const int _localSocksPort = 1080;
  static const int _statsPort = 10085;

  static Process? _v2rayProcess;
  static String? _selectedCorePath;
  static String? _selectedConfigPath;
  static void Function()? onProcessExit;

  static Timer? _statsTimer;
  static int _totalUploadBytes = 0;
  static int _totalDownloadBytes = 0;
  static String? _lastErrorMessage;

  static String? consumeLastErrorMessage() {
    final message = _lastErrorMessage;
    _lastErrorMessage = null;
    return message;
  }

  static int get totalTrafficBytes => _totalUploadBytes + _totalDownloadBytes;

  static void _startStatsPolling() {
    _totalUploadBytes = 0;
    _totalDownloadBytes = 0;
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollStats();
    });
  }

  static void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _totalUploadBytes = 0;
    _totalDownloadBytes = 0;
  }

  static Future<void> _pollStats() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$_statsPort/debug/vars'))
          .timeout(const Duration(seconds: 1));
      final response =
          await request.close().timeout(const Duration(seconds: 1));
      if (response.statusCode != 200) return;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;

      final stats = decoded['stats'];
      if (stats is! Map) return;

      var inboundUpload = 0;
      var inboundDownload = 0;
      var outboundUpload = 0;
      var outboundDownload = 0;
      for (final entry in stats.entries) {
        final key = entry.key.toString();
        final value = (entry.value as num?)?.toInt() ?? 0;
        final isInbound = key.contains('inbound>>>');
        final isOutbound = key.contains('outbound>>>');
        if (key.contains('uplink')) {
          if (isOutbound) {
            outboundUpload += value;
          } else if (isInbound) {
            inboundUpload += value;
          }
        } else if (key.contains('downlink')) {
          if (isOutbound) {
            outboundDownload += value;
          } else if (isInbound) {
            inboundDownload += value;
          }
        }
      }

      final inboundTotal = inboundUpload + inboundDownload;
      final outboundTotal = outboundUpload + outboundDownload;
      if (inboundTotal > 0 && outboundTotal > 0) {
        if (outboundTotal <= inboundTotal) {
          _totalUploadBytes = outboundUpload;
          _totalDownloadBytes = outboundDownload;
        } else {
          _totalUploadBytes = inboundUpload;
          _totalDownloadBytes = inboundDownload;
        }
      } else {
        _totalUploadBytes = outboundUpload + inboundUpload;
        _totalDownloadBytes = outboundDownload + inboundDownload;
      }
    } catch (_) {
      // Stats API is optional on Windows; ignore when unavailable.
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> start(VpnNode _, {String? configJson}) async {
    if (!Platform.isWindows) return false;

    try {
      _lastErrorMessage = null;
      await stop();

      final rawConfig = configJson?.trim();
      if (rawConfig == null || rawConfig.isEmpty) {
        throw Exception('Windows 端缺少代理配置');
      }

      final normalizedConfig = _normalizeConfigForWindows(rawConfig);
      final appDir = await getApplicationSupportDirectory();
      final v2rayDir = Directory(p.join(appDir.path, 'v2ray'));
      if (!await v2rayDir.exists()) {
        await v2rayDir.create(recursive: true);
      }

      final configFile = File(p.join(v2rayDir.path, 'config.json'));
      await configFile.writeAsString(normalizedConfig, flush: true);
      _selectedConfigPath = configFile.path;

      await _setSystemProxy(false);

      final corePath = await _resolveCoreExecutable();
      final process = await Process.start(
        corePath,
        ['-config', configFile.path],
        runInShell: false,
        workingDirectory: p.dirname(corePath),
      );

      _v2rayProcess = process;
      _selectedCorePath = corePath;
      await _writeManagedState(
        pid: process.pid,
        corePath: corePath,
        configPath: configFile.path,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          print('[XRAY STDOUT] $data');
        }
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          print('[XRAY STDERR] $data');
        }
      });

      unawaited(process.exitCode.then((code) async {
        if (!identical(_v2rayProcess, process)) return;
        print('[VPN] core exited with code $code');
        _v2rayProcess = null;
        _selectedCorePath = null;
        _selectedConfigPath = null;
        _stopStatsPolling();
        await _clearManagedState();
        await _setSystemProxy(false);
        onProcessExit?.call();
      }));

      final ready = await _waitForLocalProxyReady(process);
      if (!ready) {
        await stop();
        throw Exception('Windows 代理内核启动失败');
      }

      final proxyOk = await _setSystemProxy(
        true,
        _buildProxyServerValue(),
      );
      if (!proxyOk) {
        await stop();
        throw Exception('设置系统代理失败');
      }

      final proxyProbe = await _probeProxyExit();
      if (!proxyProbe.success) {
        await stop();
        throw Exception(proxyProbe.message);
      }

      _startStatsPolling();
      _startProxyGuard(pid, process.pid, configFile.path);
      return true;
    } catch (e) {
      print('WindowsVpnController Error: $e');
      _lastErrorMessage = e.toString();
      await _setSystemProxy(false);
      return false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isWindows) return;

    _stopStatsPolling();

    final process = _v2rayProcess;
    _v2rayProcess = null;
    final state = await _readManagedState();
    final configPath = _selectedConfigPath ?? state?.configPath;

    if (process != null) {
      process.kill();
    }

    if (state != null && state.pid > 0) {
      await _killProcessByPid(state.pid);
    }
    if (configPath != null && configPath.isNotEmpty) {
      await _killManagedProcessesByConfig(configPath);
    }

    _selectedCorePath = null;
    _selectedConfigPath = null;
    await _clearManagedState();
    await _setSystemProxy(false);
  }

  static Future<void> forceCleanup() async {
    if (!Platform.isWindows) return;
    print('[VPN] Performing force cleanup on startup...');
    await stop();
    print('[VPN] Force cleanup completed.');
  }

  static String _normalizeConfigForWindows(String rawConfig) {
    final decoded = jsonDecode(rawConfig);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Windows 端代理配置格式错误');
    }

    final originalInbounds = (decoded['inbounds'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item.cast<String, dynamic>()))
        .toList();

    Map<String, dynamic>? socksInbound;
    for (final inbound in originalInbounds) {
      if (inbound['protocol']?.toString() == 'socks') {
        socksInbound = inbound;
        break;
      }
    }

    socksInbound ??= <String, dynamic>{
      'tag': 'in_proxy',
      'protocol': 'socks',
      'settings': <String, dynamic>{
        'auth': 'noauth',
        'udp': true,
        'userLevel': 8,
      },
      'sniffing': <String, dynamic>{'enabled': false},
    };
    socksInbound['tag'] = 'win_socks';
    socksInbound['port'] = _localSocksPort;
    socksInbound['listen'] = '127.0.0.1';

    final httpInbound = <String, dynamic>{
      'tag': 'win_http',
      'port': _localHttpPort,
      'protocol': 'http',
      'listen': '127.0.0.1',
      'settings': <String, dynamic>{},
      'sniffing': <String, dynamic>{'enabled': false},
    };

    decoded['inbounds'] = <Map<String, dynamic>>[
      socksInbound,
      httpInbound,
    ];

    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static Future<bool> _waitForLocalProxyReady(Process process) async {
    var exited = false;
    unawaited(process.exitCode.then((_) {
      exited = true;
    }));

    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      if (exited) {
        return false;
      }
      if (await _canConnectLocalPort(_localSocksPort) ||
          await _canConnectLocalPort(_localHttpPort)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  static Future<bool> _canConnectLocalPort(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await socket?.close();
    }
  }

  static Future<String> _resolveCoreExecutable() async {
    final candidates = <String>{};

    for (final key in _corePathEnvKeys) {
      final value = Platform.environment[key]?.trim();
      if (value == null || value.isEmpty) continue;
      candidates.addAll(_expandConfiguredPath(value));
    }

    final exeDir = p.dirname(Platform.resolvedExecutable);
    final searchRoots = <String>[
      exeDir,
      p.join(exeDir, 'bin', 'windows'),
      p.join(exeDir, '..', 'bin', 'windows'),
      p.join(exeDir, '..', '..', '..', '..', 'windows', 'bin', 'windows'),
      Directory.current.path,
      p.join(Directory.current.path, 'bin', 'windows'),
      p.join(Directory.current.path, 'windows', 'bin', 'windows'),
    ];

    for (final root in searchRoots) {
      for (final name in _coreNames) {
        candidates.add(p.normalize(p.join(root, name)));
      }
    }

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    print('[VPN] Core not found. Searched paths:');
    for (final candidate in candidates) {
      print('  - $candidate');
    }

    throw Exception(
      '找不到 xray.exe / v2ray.exe。'
      ' 请把 core 放到程序目录或通过 9.9_CORE_PATH / XRAY_EXE_PATH / V2RAY_EXE_PATH 指定。',
    );
  }

  static Iterable<String> _expandConfiguredPath(String value) sync* {
    final normalized = p.normalize(value);

    final asFile = File(normalized);
    if (asFile.existsSync()) {
      yield asFile.path;
      return;
    }

    final asDirectory = Directory(normalized);
    if (asDirectory.existsSync()) {
      for (final name in _coreNames) {
        yield p.join(asDirectory.path, name);
      }
      return;
    }

    if (!p.isAbsolute(normalized)) {
      final relativeRoot =
          p.normalize(p.join(Directory.current.path, normalized));
      final relativeFile = File(relativeRoot);
      if (relativeFile.existsSync()) {
        yield relativeFile.path;
        return;
      }
      final relativeDirectory = Directory(relativeRoot);
      if (relativeDirectory.existsSync()) {
        for (final name in _coreNames) {
          yield p.join(relativeDirectory.path, name);
        }
      }
    }
  }

  static String _buildProxyServerValue() {
    return 'http=127.0.0.1:$_localHttpPort;'
        'https=127.0.0.1:$_localHttpPort;'
        'socks=127.0.0.1:$_localSocksPort';
  }

  static Future<bool> _runRequiredCommand(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode == 0) return true;

    print(
      '[VPN PROXY] $executable ${arguments.join(' ')} failed: '
      'exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}',
    );
    return false;
  }

  static Future<void> _runBestEffortCommand(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments);
      if (result.exitCode != 0) {
        print(
          '[VPN PROXY] ignored $executable ${arguments.join(' ')} failure: '
          'exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}',
        );
      }
    } catch (e) {
      print('[VPN PROXY] ignored $executable failure: $e');
    }
  }

  static Future<bool> _setSystemProxy(
      [bool enabled = false, String server = '']) async {
    if (!Platform.isWindows) return false;

    try {
      const proxyKey =
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';

      if (enabled) {
        final enableOk = await _runRequiredCommand('reg', [
          'add',
          proxyKey,
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '1',
          '/f',
        ]);
        final serverOk = await _runRequiredCommand('reg', [
          'add',
          proxyKey,
          '/v',
          'ProxyServer',
          '/t',
          'REG_SZ',
          '/d',
          server,
          '/f',
        ]);
        final overrideOk = await _runRequiredCommand('reg', [
          'add',
          proxyKey,
          '/v',
          'ProxyOverride',
          '/t',
          'REG_SZ',
          '/d',
          '<local>;localhost;127.*',
          '/f',
        ]);
        if (!enableOk || !serverOk || !overrideOk) {
          return false;
        }
      } else {
        await _runBestEffortCommand('reg', [
          'delete',
          proxyKey,
          '/v',
          'ProxyServer',
          '/f',
        ]);
        await _runBestEffortCommand('reg', [
          'delete',
          proxyKey,
          '/v',
          'ProxyOverride',
          '/f',
        ]);
        final disableOk = await _runRequiredCommand('reg', [
          'add',
          proxyKey,
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '0',
          '/f',
        ]);
        if (!disableOk) return false;
      }

      final refreshed = await _refreshSystemProxy();
      if (!refreshed) return false;

      final state = await _readSystemProxyState();
      if (state == null) return false;
      if (enabled) {
        final proxyReady = state.enabled && state.server == server;
        if (!proxyReady) {
          print(
            '[VPN PROXY] registry verification failed: '
            'enabled=${state.enabled} server=${state.server}',
          );
        }
        return proxyReady;
      }

      if (state.enabled) {
        print('[VPN PROXY] registry disable verification failed');
        return false;
      }
      return true;
    } catch (e) {
      print('SetProxy Error: $e');
      return false;
    }
  }

  static Future<bool> _refreshSystemProxy() async {
    const script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WinInet {
  [DllImport("wininet.dll", SetLastError=true)]
  public static extern bool InternetSetOption(
    IntPtr hInternet,
    int dwOption,
    IntPtr lpBuffer,
    int dwBufferLength
  );
}
"@;
$changed = [WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0);
$settings = [WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0);
if (-not ($changed -and $settings)) { exit 1 }
''';

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', script],
    );
    if (result.exitCode == 0) return true;

    print(
      '[VPN PROXY] refresh failed: '
      'exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}',
    );
    return false;
  }

  static Future<_SystemProxyState?> _readSystemProxyState() async {
    const script = r'''
$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$item = Get-ItemProperty -Path $key
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[pscustomobject]@{
  ProxyEnable = [int]($item.ProxyEnable)
  ProxyServer = [string]($item.ProxyServer)
  ProxyOverride = [string]($item.ProxyOverride)
} | ConvertTo-Json -Compress
''';

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
      );
      if (result.exitCode != 0) {
        print(
          '[VPN PROXY] read registry failed: '
          'exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}',
        );
        return null;
      }
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return null;
      final decoded = jsonDecode(output);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      final enabled = int.tryParse(map['ProxyEnable']?.toString() ?? '') == 1;
      return _SystemProxyState(
        enabled: enabled,
        server: map['ProxyServer']?.toString() ?? '',
      );
    } catch (e) {
      print('[VPN PROXY] read registry error: $e');
      return null;
    }
  }

  static Future<_ProxyProbeResult> _probeProxyExit() async {
    try {
      final direct = await _fetchPublicIp(useProxy: false);
      final proxied = await _fetchPublicIp(useProxy: true);

      print(
        '[VPN PROBE] direct ip=${direct.ip} '
        'country=${direct.country ?? '-'} city=${direct.city ?? '-'} '
        'isp=${direct.isp ?? '-'}',
      );
      print(
        '[VPN PROBE] proxy  ip=${proxied.ip} '
        'country=${proxied.country ?? '-'} city=${proxied.city ?? '-'} '
        'isp=${proxied.isp ?? '-'}',
      );

      if (direct.ip.isEmpty || proxied.ip.isEmpty) {
        return const _ProxyProbeResult(
          false,
          'Windows 代理出口校验失败：无法获取公网 IP',
        );
      }

      if (direct.ip == proxied.ip) {
        return _ProxyProbeResult(
          false,
          '当前线路出口与本机公网 IP 相同（${proxied.ip}），'
          '浏览器仍会显示裸机 IP，请切换其他线路',
        );
      }

      return const _ProxyProbeResult(true, null);
    } catch (e) {
      print('[VPN PROBE] error: $e');
      return _ProxyProbeResult(
        false,
        'Windows 代理出口校验失败：$e',
      );
    }
  }

  static Future<_PublicIpInfo> _fetchPublicIp({required bool useProxy}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..findProxy = (uri) {
        if (!useProxy) return 'DIRECT';
        return 'PROXY 127.0.0.1:$_localHttpPort';
      };

    try {
      final request = await client
          .getUrl(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,message,query,country,city,isp',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('ip-api status=${response.statusCode} body=$body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw Exception('ip-api 返回格式错误');
      }
      final map = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      final status = map['status']?.toString() ?? '';
      if (status != 'success') {
        throw Exception(map['message']?.toString() ?? 'ip-api failed');
      }
      return _PublicIpInfo(
        ip: map['query']?.toString() ?? '',
        country: map['country']?.toString(),
        city: map['city']?.toString(),
        isp: map['isp']?.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> _managedStateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'v2ray', 'windows_vpn_state.json'));
  }

  static Future<void> _writeManagedState({
    required int pid,
    required String corePath,
    required String configPath,
  }) async {
    final file = await _managedStateFile();
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(
      jsonEncode(<String, dynamic>{
        'pid': pid,
        'core_path': corePath,
        'config_path': configPath,
      }),
      flush: true,
    );
  }

  static Future<_ManagedState?> _readManagedState() async {
    final file = await _managedStateFile();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return _ManagedState(
        pid: int.tryParse(decoded['pid']?.toString() ?? '') ?? 0,
        corePath: decoded['core_path']?.toString() ?? '',
        configPath: decoded['config_path']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _clearManagedState() async {
    final file = await _managedStateFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _killProcessByPid(int pid) async {
    if (pid <= 0) return;
    try {
      await Process.run('taskkill', ['/F', '/PID', '$pid', '/T']);
    } catch (_) {}
  }

  static Future<void> _killManagedProcessesByConfig(String configPath) async {
    final escapedPath = configPath.replaceAll("'", "''");
    final script = '''
\$configPath = '$escapedPath';
Get-CimInstance Win32_Process |
  Where-Object {
    (\$_.Name -eq 'xray.exe' -or \$_.Name -eq 'v2ray.exe') -and
    \$_.CommandLine -like "*\$configPath*"
  } |
  ForEach-Object {
    Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue
  }
''';
    try {
      await Process.run('powershell', ['-NoProfile', '-Command', script]);
    } catch (_) {}
  }

  static void _startProxyGuard(int appPid, int corePid, String configPath) {
    final escapedPath = configPath.replaceAll("'", "''");
    final guardScript = '''
\$appPid = $appPid;
\$corePid = $corePid;
\$configPath = '$escapedPath';
Wait-Process -Id \$appPid -ErrorAction SilentlyContinue;
reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f | Out-Null;
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /f | Out-Null;
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyOverride /f | Out-Null;
\$code = 'using System; using System.Runtime.InteropServices; public static class WinInet { [DllImport("wininet.dll", SetLastError=true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength); }';
Add-Type -TypeDefinition \$code;
[WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null;
[WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null;
Stop-Process -Id \$corePid -Force -ErrorAction SilentlyContinue;
Get-CimInstance Win32_Process |
  Where-Object {
    (\$_.Name -eq 'xray.exe' -or \$_.Name -eq 'v2ray.exe') -and
    \$_.CommandLine -like "*\$configPath*"
  } |
  ForEach-Object {
    Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue
  }
''';

    Process.start(
      'powershell',
      ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', guardScript],
      runInShell: false,
    ).then((_) {
      print('[VPN] Proxy Guard started for app PID $appPid');
    }).catchError((error) {
      print('[VPN] Failed to start Proxy Guard: $error');
    });
  }
}

class _ManagedState {
  const _ManagedState({
    required this.pid,
    required this.corePath,
    required this.configPath,
  });

  final int pid;
  final String corePath;
  final String configPath;
}

class _PublicIpInfo {
  const _PublicIpInfo({
    required this.ip,
    this.country,
    this.city,
    this.isp,
  });

  final String ip;
  final String? country;
  final String? city;
  final String? isp;
}

class _ProxyProbeResult {
  const _ProxyProbeResult(this.success, this.message);

  final bool success;
  final String? message;
}

class _SystemProxyState {
  const _SystemProxyState({
    required this.enabled,
    required this.server,
  });

  final bool enabled;
  final String server;
}
