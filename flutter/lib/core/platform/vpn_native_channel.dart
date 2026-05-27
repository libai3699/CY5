import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

import '../../pages/vpn_home/models/vpn_node.dart';
import 'windows_vpn_controller.dart';

class VpnNativeChannel {
  const VpnNativeChannel();

  static final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  static FlutterV2ray? _v2ray;
  static bool _initialized = false;

  // 流量追踪：记录上次心跳时的累计字节数，用于计算增量
  static int _lastReportedBytes = 0;
  // 当前累计流量（upload + download），由 onStatusChanged 实时更新
  static int _currentTotalBytes = 0;
  static int? _nativeTrafficBaselineBytes;
  // ✅ 新增：保存 onStatusChanged 中的原始值
  static int _lastNativeTotal = 0;
  // ✅ 新增：标记是否使用 Android TrafficStats API
  static bool _useAndroidTrafficStats = false;
  // ✅ 新增：Android TrafficStats 定时器
  static Timer? _androidTrafficStatsTimer;

  // 客户友好兜底：异常大的本地增量直接忽略，避免多扣。
  static const int _maxLocalTrafficDeltaBytes = 200 * 1024 * 1024;
  static Timer? _androidHealthTimer;
  static DateTime? _lastAndroidStatusAt;
  static int _androidHealthFailCount = 0;

  /// 获取当前还未被消费（提交到挂起队列）的实时流量增量（字节）
  /// 用于前端 UI 进行秒级的乐观更新
  static int get unconsumedBytes {
    final delta = _currentTotalBytes - _lastReportedBytes;
    if (delta <= 0) return 0;
    if (delta > _maxLocalTrafficDeltaBytes) return 0;
    return delta;
  }

  /// 获取并重置自上次调用以来的流量增量（字节）
  /// 每次心跳调用一次，返回本周期内的新增流量
  static int consumeTrafficDelta() {
    final delta = _currentTotalBytes - _lastReportedBytes;
    _lastReportedBytes = _currentTotalBytes;
    if (delta <= 0) return 0;
    if (delta > _maxLocalTrafficDeltaBytes) {
      print('[V2RAY] ignored suspicious traffic delta=$delta bytes');
      return 0;
    }
    return delta;
  }

  static Future<void> resetTrafficBaseline() async {
    _lastReportedBytes = 0;
    _currentTotalBytes = 0;
    _nativeTrafficBaselineBytes = await _readNativeTrafficBytes();
    
    // ✅ 如果使用 Android TrafficStats，也重置其基线
    if (Platform.isAndroid && _useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        await channel.invokeMethod<void>('resetTrafficBaseline');
        print('[V2RAY] Android TrafficStats baseline reset');
      } catch (e) {
        print('[V2RAY] failed to reset Android TrafficStats baseline: $e');
      }
    }
  }

  static Future<int> pollTrafficDelta() async {
    final nativeBytes = await _readNativeTrafficBytes();
    
    // ✅ 详细日志
    print('[V2RAY] pollTrafficDelta: nativeBytes=$nativeBytes, baseline=$_nativeTrafficBaselineBytes, current=$_currentTotalBytes, lastReported=$_lastReportedBytes, useAndroidStats=$_useAndroidTrafficStats');
    
    if (nativeBytes > 0) {
      _nativeTrafficBaselineBytes ??= nativeBytes;
      final nativeTotal = nativeBytes - _nativeTrafficBaselineBytes!;
      final normalizedTotal = nativeTotal > 0 ? nativeTotal : 0;
      
      // ✅ 只有当新值大于当前值时才更新，避免覆盖 onStatusChanged 的值
      if (normalizedTotal > _currentTotalBytes) {
        _currentTotalBytes = normalizedTotal;
      }
    }
    final delta = consumeTrafficDelta();
    
    // ✅ 详细日志
    print('[V2RAY] pollTrafficDelta result: delta=$delta, current=$_currentTotalBytes');
    
    if (delta > 0) {
      print(
        '[V2RAY] traffic sample platform=${Platform.operatingSystem} '
        'total=$_currentTotalBytes delta=$delta',
      );
    }
    return delta;
  }

  static Future<int> _readNativeTrafficBytes() async {
    if (kIsWeb) return _currentTotalBytes;
    if (Platform.isWindows) return WindowsVpnController.totalTrafficBytes;
    
    // ✅ Android: 如果使用 TrafficStats API，从原生获取
    if (Platform.isAndroid && _useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        final bytes = await channel.invokeMethod<int>('getTrafficBytes');
        return bytes ?? 0;
      } catch (e) {
        print('[V2RAY] failed to get Android TrafficStats: $e');
        return 0;
      }
    }
    
    // ✅ Android: 返回 VPN 底层的原始值（flutter_v2ray）
    return _lastNativeTotal;
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        // ✅ 保存 VPN 底层的原始流量值
        final nativeTotal = status.upload + status.download;
        _lastNativeTotal = nativeTotal;
        
        // ✅ 检测 flutter_v2ray 是否提供流量数据
        // 如果连接后5秒内流量仍为0，切换到 Android TrafficStats API
        if (Platform.isAndroid && !_useAndroidTrafficStats) {
          _checkAndSwitchToTrafficStats(nativeTotal);
        }
        
        // ✅ 详细日志（每次都打印，方便调试）
        if (nativeTotal > 0 || _nativeTrafficBaselineBytes == null) {
          print('[V2RAY] onStatusChanged: upload=${status.upload}, download=${status.download}, total=$nativeTotal, baseline=$_nativeTrafficBaselineBytes, current=$_currentTotalBytes');
        }
        
        // ✅ 修复：减去基线后再赋值，避免累积历史流量
        if (nativeTotal >= 0 && !_useAndroidTrafficStats) {
          // 如果还没有基线，设置基线为当前值
          if (_nativeTrafficBaselineBytes == null) {
            _nativeTrafficBaselineBytes = nativeTotal;
            _currentTotalBytes = 0;
            print('[V2RAY] traffic baseline set: $_nativeTrafficBaselineBytes bytes');
          } else {
            // 减去基线，得到本次连接的实际流量
            final normalizedTotal = nativeTotal - _nativeTrafficBaselineBytes!;
            
            // 只有当新值大于当前值时才更新（避免回退）
            if (normalizedTotal > _currentTotalBytes) {
              final delta = normalizedTotal - _currentTotalBytes;
              _currentTotalBytes = normalizedTotal;
              
              // ✅ 移除1MB限制，所有变化都打印
              if (delta > 0) {
                print(
                  '[V2RAY] traffic update: '
                  'native=${(nativeTotal / 1024 / 1024).toStringAsFixed(2)}MB, '
                  'baseline=${(_nativeTrafficBaselineBytes! / 1024 / 1024).toStringAsFixed(2)}MB, '
                  'current=${(_currentTotalBytes / 1024 / 1024).toStringAsFixed(2)}MB, '
                  'delta=${(delta / 1024 / 1024).toStringAsFixed(2)}MB',
                );
              }
            }
          }
        }

        final s = status.state.toLowerCase().trim();
        if (Platform.isAndroid) {
          _lastAndroidStatusAt = DateTime.now();
        }
        print('[V2RAY] status changed: "${status.state}" → normalized: "$s"');

        // ── 明确断开状态 ──────────────────────────────────────────────────
        // 只有真正的终止状态才触发 disconnected，避免过渡状态误判
        if (s == 'stopped' ||
            s == 'disconnected' ||
            s == 'none' ||
            s == 'idle' ||
            s == 'error' ||
            s == 'failed') {
          _lastReportedBytes = 0;
          _currentTotalBytes = 0;
          _nativeTrafficBaselineBytes = null;
          _lastNativeTotal = 0; // ✅ 重置原始值
          _stopAndroidHealthCheck();
          _stopAndroidTrafficStats(); // ✅ 停止 TrafficStats
          _statusController.add('disconnected');
        } else if (s == 'connecting' || s == 'reconnecting') {
          // 重连中不视为断开，保持 connecting 状态
          _statusController.add('connecting');
        } else if (s == 'connected' || s == 'running') {
          _statusController.add('connected');
        } else if (s.contains('connect') && !s.contains('disconnect')) {
          // 包含 connect 但不包含 disconnect 的未知状态，视为连接中
          _statusController.add('connecting');
        } else if (s.contains('stop') ||
            s.contains('disconnect') ||
            s.contains('fail')) {
          // 包含明确断开关键词才断开
          _lastReportedBytes = 0;
          _currentTotalBytes = 0;
          _nativeTrafficBaselineBytes = null;
          _lastNativeTotal = 0; // ✅ 重置原始值
          _stopAndroidHealthCheck();
          _stopAndroidTrafficStats(); // ✅ 停止 TrafficStats
          _statusController.add('disconnected');
        } else {
          // 其他未知状态：打印日志但不改变当前状态，避免误断
          print(
              '[V2RAY] unknown status ignored (keeping current state): "${status.state}"');
        }
      },
    );
    await _v2ray!.initializeV2Ray();
    _initialized = true;
  }
  
  // ✅ 新增：检测并切换到 Android TrafficStats API
  static Timer? _trafficStatsCheckTimer;
  static void _checkAndSwitchToTrafficStats(int nativeTotal) {
    // 如果已经切换，不再检测
    if (_useAndroidTrafficStats) return;
    
    // 启动定时器，5秒后检测
    _trafficStatsCheckTimer ??= Timer(const Duration(seconds: 5), () async {
      if (_lastNativeTotal == 0 && _currentTotalBytes == 0) {
        print('[V2RAY] flutter_v2ray not providing traffic data, switching to Android TrafficStats API');
        _useAndroidTrafficStats = true;
        await _startAndroidTrafficStats();
      }
      _trafficStatsCheckTimer = null;
    });
  }
  
  // ✅ 新增：启动 Android TrafficStats API
  static Future<void> _startAndroidTrafficStats() async {
    if (!Platform.isAndroid) return;
    
    try {
      const channel = MethodChannel('9.9/native');
      await channel.invokeMethod<void>('startTrafficTracking');
      print('[V2RAY] Android TrafficStats tracking started');
      
      // 每2秒轮询一次流量
      _androidTrafficStatsTimer?.cancel();
      _androidTrafficStatsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final bytes = await channel.invokeMethod<int>('getTrafficBytes');
          if (bytes != null && bytes > 0) {
            _currentTotalBytes = bytes;
          }
        } catch (e) {
          print('[V2RAY] failed to poll Android TrafficStats: $e');
        }
      });
    } catch (e) {
      print('[V2RAY] failed to start Android TrafficStats: $e');
    }
  }
  
  // ✅ 新增：停止 Android TrafficStats API
  static Future<void> _stopAndroidTrafficStats() async {
    if (!Platform.isAndroid) return;
    
    _androidTrafficStatsTimer?.cancel();
    _androidTrafficStatsTimer = null;
    _trafficStatsCheckTimer?.cancel();
    _trafficStatsCheckTimer = null;
    
    if (_useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        await channel.invokeMethod<void>('stopTrafficTracking');
        print('[V2RAY] Android TrafficStats tracking stopped');
      } catch (e) {
        print('[V2RAY] failed to stop Android TrafficStats: $e');
      }
      _useAndroidTrafficStats = false;
    }
  }

  Future<String?> prepareVpn() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('9.9/native');
    final notificationError =
        await channel.invokeMethod<String>('ensureNotificationPermission');
    if (notificationError != null && notificationError.isNotEmpty) {
      return notificationError;
    }
    await _ensureInitialized();
    final granted = await _v2ray!.requestPermission();
    if (!granted) return 'VPN 权限被拒绝';
    return null;
  }

  Future<String?> startVpn(VpnNode node) async {
    if (kIsWeb) {
      _statusController.add('connected');
      return null;
    }
    if (!Platform.isAndroid) {
      _statusController.add('connecting');
      WindowsVpnController.onProcessExit = () {
        _statusController.add('disconnected');
      };
      try {
        final originalConfig = FlutterV2ray.parseFromURL(node.rawUri.trim())
            .getFullConfiguration();
        final config = _injectDnsAndSniffing(originalConfig);
        final success =
            await WindowsVpnController.start(node, configJson: config);
        if (!success) {
          _statusController.add('disconnected');
          return WindowsVpnController.consumeLastErrorMessage() ?? '启动失败';
        }
        _statusController.add('connected');
        // Windows 连接成功后启动秒级流量同步，把 WindowsVpnController 的累计值
        // 映射到 _currentTotalBytes，让 consumeTrafficDelta() 能正常工作
        _startWindowsTrafficSync();
        return null;
      } catch (e) {
        _statusController.add('disconnected');
        return '连接失败: $e';
      }
    }

    await _ensureInitialized();
    try {
      final rawUri = node.rawUri.trim();
      print(
        '[V2RAY] startVpn rawUri: ${rawUri.substring(0, rawUri.length.clamp(0, 80))}',
      );
      final parser = FlutterV2ray.parseFromURL(rawUri);
      final originalConfig = parser.getFullConfiguration();
      final optimizedConfig = _injectDnsAndSniffing(originalConfig);
      _statusController.add('connecting');
      await _v2ray!.startV2Ray(
        remark: node.name,
        config: optimizedConfig,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
      print('[V2RAY] startV2Ray called');
      _startAndroidHealthCheck();
      
      // ✅ 启动流量检测定时器
      _trafficStatsCheckTimer?.cancel();
      _trafficStatsCheckTimer = Timer(const Duration(seconds: 5), () async {
        if (_lastNativeTotal == 0 && _currentTotalBytes == 0) {
          print('[V2RAY] flutter_v2ray not providing traffic data, switching to Android TrafficStats API');
          _useAndroidTrafficStats = true;
          await _startAndroidTrafficStats();
        }
        _trafficStatsCheckTimer = null;
      });
      
      return null;
    } catch (e) {
      print('[V2RAY] startVpn error: $e');
      _stopAndroidHealthCheck();
      _statusController.add('disconnected');
      
      // ✅ 检查是否是 "process is bad" 错误
      final errorMsg = e.toString();
      if (errorMsg.contains('process is bad')) {
        return '系统服务异常，请重启APP后重试';
      }
      
      return '连接失败: $e';
    }
  }

  Future<String?> stopVpn() async {
    if (kIsWeb) {
      _statusController.add('disconnected');
      return null;
    }
    if (!Platform.isAndroid) {
      _stopWindowsTrafficSync();
      await WindowsVpnController.stop();
      _statusController.add('disconnected');
      return null;
    }
    await _ensureInitialized();
    _stopAndroidHealthCheck();
    // 先发 disconnected，防止 stopV2Ray 触发的回调覆盖状态
    _statusController.add('disconnected');
    try {
      await _v2ray!.stopV2Ray();
      print('[V2RAY] stopV2Ray called');
    } catch (e) {
      print('[V2RAY] stopV2Ray error: $e');
    }
    return null;
  }

  Future<void> openSupportH5() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const channel = MethodChannel('9.9/native');
    return channel.invokeMethod<void>('openSupportH5');
  }

  Stream<String> get statusStream => _statusController.stream;

  // ── Windows 流量同步 ──────────────────────────────────────────────────────
  // 每秒把 WindowsVpnController.totalTrafficBytes 同步到 _currentTotalBytes，
  // 这样 consumeTrafficDelta() 和 unconsumedBytes 在 Windows 上也能正常工作。
  static Timer? _windowsTrafficSyncTimer;

  static void _startWindowsTrafficSync() {
    _windowsTrafficSyncTimer?.cancel();
    _windowsTrafficSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final total = WindowsVpnController.totalTrafficBytes;
      final baseline = _nativeTrafficBaselineBytes;
      final normalizedTotal = baseline == null ? total : total - baseline;
      if (normalizedTotal > _currentTotalBytes) {
        _currentTotalBytes = normalizedTotal;
      }
    });
  }

  static void _stopWindowsTrafficSync() {
    _windowsTrafficSyncTimer?.cancel();
    _windowsTrafficSyncTimer = null;
    _lastReportedBytes = 0;
    _currentTotalBytes = 0;
    _nativeTrafficBaselineBytes = null;
    _lastNativeTotal = 0; // ✅ 重置原始值
    _useAndroidTrafficStats = false; // ✅ 重置标记
  }

  static void _startAndroidHealthCheck() {
    _androidHealthTimer?.cancel();
    _androidHealthFailCount = 0;
    _lastAndroidStatusAt = DateTime.now();
    _androidHealthTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _checkAndroidHealth();
    });
  }

  static void _stopAndroidHealthCheck() {
    _androidHealthTimer?.cancel();
    _androidHealthTimer = null;
    _androidHealthFailCount = 0;
    _lastAndroidStatusAt = null;
  }

  static Future<void> _checkAndroidHealth() async {
    if (!Platform.isAndroid || _v2ray == null) return;

    final lastStatusAt = _lastAndroidStatusAt;
    final statusStale = lastStatusAt == null ||
        DateTime.now().difference(lastStatusAt) > const Duration(seconds: 14);

    if (!statusStale) {
      _androidHealthFailCount = 0;
      return;
    }

    try {
      final delay = await _v2ray!
          .getConnectedServerDelay(url: 'https://www.gstatic.com/generate_204')
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);
      if (delay >= 0) {
        _androidHealthFailCount = 0;
        _lastAndroidStatusAt = DateTime.now();
        return;
      }
      _androidHealthFailCount++;
      print('[V2RAY] health check failed count=$_androidHealthFailCount');
    } catch (e) {
      _androidHealthFailCount++;
      print('[V2RAY] health check error count=$_androidHealthFailCount: $e');
    }

    if (_androidHealthFailCount >= 2) {
      print('[V2RAY] health check marked disconnected');
      _lastReportedBytes = 0;
      _currentTotalBytes = 0;
      _nativeTrafficBaselineBytes = null;
      _lastNativeTotal = 0;
      _stopAndroidHealthCheck();
      _stopAndroidTrafficStats();
      _statusController.add('disconnected');
    }
  }

  /// 注入 DNS 和 sniffing 配置，加速连接后的首次网页访问
  static String _injectDnsAndSniffing(String configJson) {
    try {
      final config = jsonDecode(configJson) as Map<String, dynamic>;

      // 注入 DNS 配置：使用多组公共 DNS 并行查询
      config['dns'] = {
        'servers': [
          {
            'address': '8.8.8.8',
            'port': 53,
          },
          {
            'address': '1.1.1.1',
            'port': 53,
          },
          'localhost',
        ],
        'queryStrategy': 'UseIPv4',
      };

      // 为所有 inbound 启用 sniffing（域名嗅探）
      final inbounds = config['inbounds'];
      if (inbounds is List) {
        for (final inbound in inbounds) {
          if (inbound is Map<String, dynamic>) {
            inbound['sniffing'] = {
              'enabled': true,
              'destOverride': ['http', 'tls'],
              'routeOnly': false,
            };
          }
        }
      }

      // 确保 routing 中有基础规则，避免 DNS 查询被阻断
      if (config['routing'] == null) {
        config['routing'] = {
          'domainStrategy': 'IPIfNonMatch',
          'rules': <Map<String, dynamic>>[],
        };
      } else if (config['routing'] is Map<String, dynamic>) {
        final routing = config['routing'] as Map<String, dynamic>;
        routing['domainStrategy'] ??= 'IPIfNonMatch';
      }

      final result = jsonEncode(config);
      print('[V2RAY] DNS & sniffing injected into config');
      return result;
    } catch (e) {
      print('[V2RAY] failed to inject DNS/sniffing: $e, using original config');
      return configJson;
    }
  }
}
