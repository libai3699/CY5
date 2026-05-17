import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/vpn_native_channel.dart';
import 'auth_page.dart';
import 'chatgpt_page.dart';
import 'components/app_drawer.dart';
import 'components/app_top_bar.dart';
import 'components/node_picker_sheet.dart';
import 'components/notice_bar.dart';
import 'components/quote_card.dart';
import 'components/vpn_control_panel.dart';
import 'contact_page.dart';
import 'data/auth_service.dart';
import 'data/api_config.dart';
import 'data/contact_service.dart';
import 'data/device_identity.dart';
import 'data/node_speed_tester.dart';
import 'data/remote_app_loader.dart'
    show RemoteAppLoader, TokenExpiredException;
import 'data/remote_vpn_line_loader.dart';
import 'login_devices_page.dart';
import 'models/app_status.dart';
import 'models/vpn_node.dart';
import 'models/vpn_status.dart';
import 'notices_page.dart';
import 'purchase_page.dart';

class VpnHomePage extends StatefulWidget {
  const VpnHomePage({super.key});

  @override
  State<VpnHomePage> createState() => _VpnHomePageState();
}

class _VpnHomePageState extends State<VpnHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final VpnNativeChannel _vpnChannel = const VpnNativeChannel();
  final RemoteVpnLineLoader _lineLoader = const RemoteVpnLineLoader();
  final RemoteAppLoader _appLoader = const RemoteAppLoader();
  final DeviceIdentity _deviceIdentity = const DeviceIdentity();
  final AuthService _authService = const AuthService();
  final NodeSpeedTester _speedTester = const NodeSpeedTester();

  List<VpnNode> _nodes = const [];
  VpnNode? _selectedNode;
  String _deviceId = '';
  AuthSession? _session;
  int _quoteKey = 0; // 每次下拉刷新递增，强制 QuoteCard 重建
  AppStatus _appStatus = const AppStatus(
    planLevel: '免费体验',
    remainingSeconds: 0,
    remainingTimeText: '未登录',
    trafficRemaining: '0 GB',
  );
  Map<String, String> _appConfig = const {};
  VpnStatus _status = VpnStatus.disconnected;
  String? _message;
  bool _isLoadingNodes = true;
  bool _isRefreshingLines = false;
  Timer? _appStatusRefreshTimer;
  Timer? _heartbeatTimer;
  Timer? _uiRefreshTimer;
  Timer? _remainingTimer;
  StreamSubscription<String>? _statusSubscription;
  int _heartbeatFailCount = 0; // 心跳失败计数
  int _pendingTrafficBytes = 0; // 未成功上报的累计流量
  int _pendingSeconds = 0; // 未成功上报的累计时长

  bool _isHeartbeatInFlight = false;

  bool get _isConnected => _status == VpnStatus.connected;
  bool get _isConnecting => _status == VpnStatus.connecting;
  bool get _keepVpnConnected => true;
  bool get _hasActivePlan =>
      _appStatus.planLevel != '免费体验' && _appStatus.remainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _listenVpnStatus();
    _bootstrap();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _appStatusRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _remainingTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final session = await _authService.loadSession();
      if (mounted && session != null) {
        setState(() {
          _session = session;
        });
      }
    } catch (_) {}
    unawaited(_loadAppData());
    unawaited(_loadNodes());
    unawaited(_registerDevice());
    // 后台预加载联系方式，写入缓存，ContactPage 打开时直接读缓存
    unawaited(ContactService.instance.prefetch());
  }

  Future<void> _registerDevice() async {
    try {
      final displayId = await _deviceIdentity.register();
      if (!mounted) return;
      setState(() {
        _deviceId = displayId.isNotEmpty ? displayId : '获取中';
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _deviceId = '获取中';
        });
    }
  }

  Future<void> _initDeviceAndAuth() async {
    // 保留兼容，实际由 _bootstrap 替代
  }

  void _listenVpnStatus() {
    _statusSubscription = _vpnChannel.statusStream.listen(
      (event) {
        if (!mounted) return;

        if (event.startsWith('error:')) {
          if (_isConnected) {
            setState(() {
              _message = event.substring(6);
            });
            return;
          }
          setState(() {
            _status = VpnStatus.disconnected;
            _message = event.substring(6);
          });
          return;
        }

        switch (event) {
          case 'connecting':
            setState(() {
              _status = VpnStatus.connecting;
              _message = '正在连接...';
            });
            break;
          case 'connected':
            if (_status != VpnStatus.connected) {
              setState(() {
                _status = VpnStatus.connected;
                _message = '${_selectedNode?.name ?? "VPN"} 已连接';
              });
              _syncHeartbeatTimer();
            }
            break;
          case 'disconnected':
            setState(() {
              _status = VpnStatus.disconnected;
              _message = null;
            });
            _heartbeatTimer?.cancel();
            _uiRefreshTimer?.cancel();
            break;
        }
      },
      onError: (error) {
        if (!mounted) return;
        if (_isConnected) {
          setState(() {
            _message = '状态监听异常，当前连接保持中';
          });
          return;
        }
        setState(() {
          _status = VpnStatus.disconnected;
          _message = '状态监听异常：$error';
        });
      },
    );
  }

  Future<void> _loadAppData() async {
    final token = _session?.token;
    print('[AUTH] _loadAppData start token=${_maskToken(token)}');
    try {
      final status = token == null || token.isEmpty
          ? await _appLoader.loadStatus()
          : await _appLoader.loadUserStatus(token);
      if (!mounted) return;
      setState(() {
        _appStatus = status;
      });
      _syncRemainingTimer(status.remainingSeconds);
      _syncStatusRefreshTimer();
    } on TokenExpiredException catch (e) {
      print(
          '[AUTH] _loadAppData token expired token=${_maskToken(token)} error=$e');
      if (_isConnected) {
        print('[AUTH] token expired ignored while vpn is connected');
        return;
      }
      await _handleTokenExpired(expectedToken: token);
      return;
    } catch (_) {}
    try {
      final config = await _appLoader.loadConfig();
      if (!mounted) return;
      setState(() {
        _appConfig = config;
      });
    } catch (_) {}
  }

  /// Token 过期：清空本地 session，断开 VPN，提示用户重新登录
  Future<void> _handleTokenExpired({String? expectedToken}) async {
    final currentToken = _session?.token;
    print(
      '[AUTH] _handleTokenExpired expected=${_maskToken(expectedToken)} current=${_maskToken(currentToken)}',
    );
    if (expectedToken != null &&
        expectedToken.isNotEmpty &&
        currentToken != expectedToken) {
      print('[AUTH] token expired ignored, session already switched');
      return;
    }

    if (expectedToken != null && expectedToken.isNotEmpty) {
      try {
        final persistedSession = await _authService.loadSession();
        final persistedToken = persistedSession?.token;
        print(
          '[AUTH] persisted session token=${_maskToken(persistedToken)} expected=${_maskToken(expectedToken)}',
        );
        if (persistedToken != null &&
            persistedToken.isNotEmpty &&
            persistedToken != expectedToken) {
          print(
              '[AUTH] token expired ignored, persisted session already switched');
          return;
        }
      } catch (e) {
        print('[AUTH] token expired persisted session check failed: $e');
      }
    }

    if (_isConnected) {
      print('[AUTH] token expired but vpn is connected, keep session and vpn');
      if (mounted) {
        setState(() {
          _message = '登录状态异常，当前连接保持中';
        });
      }
      return;
    }

    print('[AUTH] token expired, clearing session');
    await _authService.clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
      _appStatus = const AppStatus(
        planLevel: '免费体验',
        remainingSeconds: 0,
        remainingTimeText: '未登录',
        trafficRemaining: '0 GB',
      );
      _message = null;
    });
    // 加载公开状态（不带 token）
    try {
      final status = await _appLoader.loadStatus();
      if (!mounted) return;
      setState(() {
        _appStatus = status;
      });
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('登录已过期，请重新登录'),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '去登录',
          textColor: Colors.white,
          onPressed: _openAuthPage,
        ),
      ),
    );
  }

  void _syncRemainingTimer(int seconds) {
    _remainingTimer?.cancel();
    if (seconds <= 0) return; // 0 或负数不启动倒计时
    _remainingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _appStatus.remainingSeconds - 1;
      setState(() {
        _appStatus = AppStatus(
          planLevel: _appStatus.planLevel,
          remainingSeconds: next < 0 ? 0 : next,
          remainingTimeText: _formatRemainingTime(next),
          trafficRemaining: _appStatus.trafficRemaining,
        );
      });
      if (next <= 0) {
        _remainingTimer?.cancel();
        if (_isConnected && !_hasActivePlan) {
          setState(() {
            _message = '试用已结束，当前连接保持中';
          });
        }
      }
    });
  }

  void _syncStatusRefreshTimer() {
    _appStatusRefreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadAppData();
    });
  }

  void _syncHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _heartbeatFailCount = 0; // 重置失败计数
    _isHeartbeatInFlight = false;
    _pendingTrafficBytes = 0;
    _pendingSeconds = 0;
    print('[HEARTBEAT] disabled while vpn is connected');
    /*
    _sendHeartbeat(seconds: 1);
    // 改为30秒心跳间隔，避免VPN在心跳前断开
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _sendHeartbeat(seconds: 30);
    });
    */

    // 启动秒级UI刷新，用于前端乐观更新流量显示
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isConnected) {
        setState(() {}); // 触发 _displayTrafficRemaining 重新计算
      }
    });
  }

  Future<void> _sendHeartbeat({required int seconds}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty || !_isConnected) return;

    // 获取本次心跳周期内的流量增量并累加到 pending
    final trafficDelta = VpnNativeChannel.consumeTrafficDelta();
    _pendingTrafficBytes += trafficDelta;
    _pendingSeconds += seconds;

    print(
        '[HEARTBEAT] delta=${_formatBytes(trafficDelta)} pending=${_formatBytes(_pendingTrafficBytes)} secs=$_pendingSeconds');

    if (_isHeartbeatInFlight) {
      print('[HEARTBEAT] skip send, previous request still in flight');
      return;
    }
    _isHeartbeatInFlight = true;

    // 服务端对单次 seconds 有 65 秒上限，只截断秒数，流量不截断
    final secondsToSend = _pendingSeconds > 60 ? 60 : _pendingSeconds;
    final bytesToSend = _pendingTrafficBytes;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      print(
          '[HEARTBEAT] send start bytes=${_formatBytes(bytesToSend)} secs=$secondsToSend');
      final request = await client
          .postUrl(Uri.parse(kUserHeartbeatApiUrl))
          .timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode({
        'seconds': secondsToSend,
        'traffic_bytes': bytesToSend,
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        print('[HEARTBEAT] 401 body: $body token=${_maskToken(token)}');
        _heartbeatFailCount++;
        return;
      }

      bool serverConfirmed = false;
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          serverConfirmed = decoded['code'] == 0 || decoded['code'] == 200;
          data = decoded['data'] as Map<String, dynamic>?;
        }
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          serverConfirmed) {
        // 服务端确认，扣除已上报部分
        _pendingTrafficBytes = (_pendingTrafficBytes - bytesToSend)
            .clamp(0, double.maxFinite.toInt());
        _pendingSeconds = (_pendingSeconds - secondsToSend)
            .clamp(0, double.maxFinite.toInt());
        _heartbeatFailCount = 0;
        print(
            '[HEARTBEAT] ✅ confirmed, remaining pending=${_formatBytes(_pendingTrafficBytes)}');
      } else {
        _heartbeatFailCount++;
        print('[HEARTBEAT] ❌ server rejected (count=$_heartbeatFailCount)');
      }

      // 更新 UI 状态
      if (data != null && mounted) {
        final trafficRemaining = data['traffic_remaining']?.toString();
        final remainingSeconds =
            int.tryParse(data['remaining_seconds']?.toString() ?? '');
        final remainingTimeText = data['remaining_time_text']?.toString();
        final trafficExhausted = data['traffic_exhausted'] == true;

        setState(() {
          _appStatus = AppStatus(
            planLevel: _appStatus.planLevel,
            remainingSeconds: remainingSeconds ?? _appStatus.remainingSeconds,
            remainingTimeText:
                remainingTimeText ?? _appStatus.remainingTimeText,
            trafficRemaining: trafficRemaining ?? _appStatus.trafficRemaining,
          );
        });

        if (_keepVpnConnected && trafficExhausted && _isConnected) {
          print('[HEARTBEAT] traffic exhausted, keep vpn connected');
          if (mounted) setState(() => _message = '流量已用完，当前连接保持中');
          return;
        }

        if (!_keepVpnConnected && trafficExhausted && _isConnected) {
          print('[HEARTBEAT] ⚠️ traffic exhausted, disconnecting');
          await _disconnect();
          if (mounted) setState(() => _message = '流量已用完，请购买套餐');
          _openPurchasePage();
          return;
        }
      }

      if (!_hasActivePlan && _appStatus.remainingSeconds <= 0 && _isConnected) {
        print('[HEARTBEAT] remaining time exhausted, keep vpn connected');
        if (mounted) {
          setState(() {
            _message = '试用已结束，当前连接保持中';
          });
        }
      }
    } catch (e) {
      _heartbeatFailCount++;
      print('[HEARTBEAT] ❌ exception (count=$_heartbeatFailCount): $e');
      // 心跳失败不断开 VPN，pending 数据保留下次重试
    } finally {
      client.close(force: true);
      _isHeartbeatInFlight = false;
      print('[HEARTBEAT] send end');
    }
  }

  void _applySessionStatus(AuthSession session) {
    // 不用本地 session 的旧数据覆盖状态，等 _loadAppData 从服务器拉取最新数据
    _syncRemainingTimer(0);
  }

  String _formatRemainingTime(int seconds) {
    if (seconds < 0) return '不限时长'; // 套餐用户后端返回 -1
    if (seconds <= 0) return '已到期';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    if (hours < 24)
      return restMinutes > 0 ? '$hours小时 $restMinutes分钟' : '$hours小时';
    final days = hours ~/ 24;
    final restHours = hours % 24;
    return restHours > 0 ? '$days天 $restHours小时' : '$days天';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(3)} GB';
  }

  Future<void> _loadNodes() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNodes = true;
      _message = null;
    });
    try {
      final nodes = await _lineLoader.load();

      // 测速并排序
      print('[LOAD_NODES] 开始测速 ${nodes.length} 个节点');
      final sortedNodes = await _speedTester.testAndSortNodes(nodes);

      if (!mounted) return;
      setState(() {
        _nodes = sortedNodes;
        _selectedNode = sortedNodes.isNotEmpty ? sortedNodes.first : null;
        _isLoadingNodes = false;
      });
    } catch (error) {
      print('[LOAD_NODES] error: $error');
      if (!mounted) return;
      setState(() {
        _isLoadingNodes = false;
        if (_nodes.isEmpty) {
          _nodes = const [];
          _selectedNode = null;
        }
        _message = '线路加载失败，请点击重试';
      });
    }
  }

  Future<void> _refreshLinesFromDrawer() async {
    if (_isRefreshingLines) return;
    setState(() {
      _isRefreshingLines = true;
      _message = null;
    });

    try {
      final nextNodes = await _lineLoader.load();
      final sortedNodes = await _speedTester.testAndSortNodes(nextNodes);
      if (!_sameNodes(_nodes, sortedNodes)) {
        final currentId = _selectedNode?.id;
        VpnNode? nextSelected;
        for (final node in sortedNodes) {
          if (node.id == currentId) {
            nextSelected = node;
            break;
          }
        }
        setState(() {
          _nodes = sortedNodes;
          _selectedNode = nextSelected ??
              (sortedNodes.isNotEmpty ? sortedNodes.first : null);
          _message = '线路已刷新';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshingLines = false;
      });
    }
  }

  bool _sameNodes(List<VpnNode> current, List<VpnNode> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.name != b.name ||
          a.address != b.address ||
          a.rawUri != b.rawUri) {
        return false;
      }
    }
    return true;
  }

  Future<void> _connect() async {
    var session = _session;
    if (session == null) {
      session = await Navigator.of(context).push<AuthSession>(
        MaterialPageRoute<AuthSession>(
          builder: (_) => AuthPage(config: _appConfig),
        ),
      );
      if (session == null || !mounted) return;
      setState(() {
        _session = session;
      });
      _applySessionStatus(session);
      await _loadAppData();
    }

    if (!_keepVpnConnected &&
        (session.trialExpired || _appStatus.remainingSeconds <= 0) &&
        !_hasActivePlan) {
      setState(() {
        _message = '试用已结束，请购买套餐后连接';
      });
      _openPurchasePage();
      return;
    }

    final selectedNode = _selectedNode;
    if (selectedNode == null) {
      setState(() {
        _message = '请先加载并选择线路';
      });
      return;
    }

    setState(() {
      _status = VpnStatus.connecting;
      _message = '正在请求 VPN 权限...';
    });

    try {
      final prepareResult = await _vpnChannel.prepareVpn();
      if (prepareResult != null) {
        setState(() {
          _status = VpnStatus.disconnected;
          _message = prepareResult;
        });
        return;
      }

      setState(() {
        _message = '正在连接 ${selectedNode.name}...';
      });

      final result = await _vpnChannel.startVpn(selectedNode);
      if (result != null) {
        setState(() {
          _message = result;
        });
      }
    } on PlatformException catch (error) {
      setState(() {
        _status = VpnStatus.disconnected;
        _message = error.message ?? 'VPN start failed';
      });
    } on MissingPluginException {
      setState(() {
        _status = VpnStatus.disconnected;
        _message = '原生 VPN 通道未加载，请停止应用后重新运行安装';
      });
    }
  }

  Future<void> _disconnect() async {
    _heartbeatTimer?.cancel();
    setState(() {
      _status = VpnStatus.connecting;
      _message = '正在断开...';
    });

    try {
      await _vpnChannel.stopVpn();
    } catch (error) {
      print('[DISCONNECT] error: $error');
    } finally {
      // 无论如何都强制设置为断开状态
      if (mounted) {
        setState(() {
          _status = VpnStatus.disconnected;
          _message = null;
        });
      }
    }
  }

  void _openContactPage() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const ContactPage(),
        transitionsBuilder: (_, animation, __, child) {
          final tween =
              Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  Future<void> _openSupportH5() async {
    _openContactPage();
  }

  void _openSettingsMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _openAuthPage() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    final session = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute<AuthSession>(
        builder: (_) => AuthPage(config: _appConfig),
      ),
    );
    print(
        '[AUTH] _openAuthPage returned session=${_maskToken(session?.token)}');
    if (session == null || !mounted) return;
    setState(() {
      _session = session;
    });
    _applySessionStatus(session);
    await _loadAppData();
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return '<none>';
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }

  Future<void> _logoutCurrentDevice() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) return;

    // 先断开 VPN
    if (!_keepVpnConnected && (_isConnected || _isConnecting)) {
      await _disconnect();
    } else if (_isConnected || _isConnecting) {
      print('[AUTH] logout requested while vpn is connected, keep vpn running');
    }

    // 取消定时器
    _appStatusRefreshTimer?.cancel();
    _appStatusRefreshTimer = null;
    _heartbeatTimer?.cancel();
    _remainingTimer?.cancel();

    // 通知后端退出，并清除本地 session
    await _authService.logout(token);

    if (!mounted) return;

    // 清空未上报流量缓存
    _pendingTrafficBytes = 0;
    _pendingSeconds = 0;

    // 关闭 Drawer
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    setState(() {
      _session = null;
      _appStatus = const AppStatus(
        planLevel: '免费体验',
        remainingSeconds: 0,
        remainingTimeText: '未登录',
        trafficRemaining: '0 GB',
      );
      _message = null;
    });

    // 重新拉取公开状态
    try {
      final status = await _appLoader.loadStatus();
      if (!mounted) return;
      setState(() {
        _appStatus = status;
      });
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已退出登录'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openLoginDevicesPage() {
    final token = _session?.token;
    if (token == null || token.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LoginDevicesPage(token: token)),
    );
  }

  void _openNoticesPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NoticesPage()),
    );
  }

  void _openChatGptPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatGptPage()),
    );
  }

  void _openPurchasePage() {
    // 检查是否已登录
    if (_session == null || _session!.token.isEmpty) {
      // 未登录，先跳转到登录页面
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AuthPage(
            onLoginSuccess: (session) {
              // 登录成功后，更新session并打开购买页面
              setState(() {
                _session = session;
              });
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PurchasePage(
                    username: session.username,
                    token: session.token,
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // 已登录，直接打开购买页面
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PurchasePage(
          username: _session!.username,
          token: _session!.token,
        ),
      ),
    );
  }

  void _openNodePicker() {
    if (_nodes.isEmpty || _selectedNode == null) {
      setState(() {
        _message = '暂无可选线路';
      });
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
      ),
      builder: (context) => NodePickerSheet(
        nodes: _nodes,
        selectedNode: _selectedNode!,
        onSelected: (node) {
          setState(() {
            _selectedNode = node;
            _message = null;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _calculateOptimisticTraffic(String backendText, int pendingBytes) {
    if (pendingBytes <= 0) return backendText;
    if (backendText == '不限流量' || backendText == '无限流量') return backendText;

    try {
      final parts = backendText.trim().split(' ');
      if (parts.length >= 2) {
        final val = double.tryParse(parts[0]);
        if (val == null) return backendText;

        final unit = parts[1].toUpperCase();

        double bytes = 0;
        if (unit == 'GB') {
          bytes = val * 1024 * 1024 * 1024;
        } else if (unit == 'MB') {
          bytes = val * 1024 * 1024;
        } else if (unit == 'KB') {
          bytes = val * 1024;
        } else {
          return backendText;
        }

        double newBytes = bytes - pendingBytes;
        if (newBytes < 0) newBytes = 0;

        if (newBytes < 1024 * 1024 * 1024) {
          return '${(newBytes / 1024 / 1024).toStringAsFixed(2)} MB';
        } else {
          return '${(newBytes / 1024 / 1024 / 1024).toStringAsFixed(3)} GB';
        }
      }
    } catch (e) {
      // fallback
    }
    return backendText;
  }

  String get _displayTrafficRemaining {
    try {
      final text = _appStatus.trafficRemaining.trim();
      final isFreeTrial = _appStatus.planLevel == '免费体验';
      if (isFreeTrial && (text == '0G' || text == '0GB' || text == '0 GB')) {
        return '无限流量';
      }
      // 乐观更新：减去已出账但还没发给服务端的流量
      final totalPending =
          _pendingTrafficBytes + VpnNativeChannel.unconsumedBytes;
      return _calculateOptimisticTraffic(text, totalPending);
    } catch (_) {
      return _appStatus.trafficRemaining;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        deviceId: _deviceId.isEmpty ? '读取中' : _deviceId,
        isRefreshingLines: _isRefreshingLines,
        onChatGptPressed: _openChatGptPage,
        onLoginPressed: _openAuthPage,
        onDevicesPressed: _openLoginDevicesPage,
        onLogoutPressed: _logoutCurrentDevice,
        onNoticesPressed: _openNoticesPage,
        onPurchasePressed: _openPurchasePage,
        onRefreshLines: _refreshLinesFromDrawer,
        planLevel: _appStatus.planLevel,
        remainingTimeText: _appStatus.remainingTimeText,
        trafficRemaining: _displayTrafficRemaining,
        username: _session?.username,
      ),
      endDrawer: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: const ContactPage(),
      ),
      drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.2,
      drawerEnableOpenDragGesture: true,
      endDrawerEnableOpenDragGesture: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF1F2),
              Color(0xFFFFD6DF),
              Color(0xFFFFEEF5),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onMenuPressed: _openSettingsMenu,
                onSupportPressed: _openSupportH5,
              ),
              NoticeBar(
                token: _session?.token,
                onStatusUpdate: (msg) {
                  _loadAppData();
                  if (!mounted) return;
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_giftcard_rounded,
                                color: Color(0xFFE11D48), size: 30),
                          ),
                          const SizedBox(height: 16),
                          const Text('套餐已更新',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF881337))),
                          const SizedBox(height: 8),
                          Text(msg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF9F1239))),
                          const SizedBox(height: 20),
                        ],
                      ),
                      actions: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48)),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('好的'),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
              QuoteCard(key: ValueKey(_quoteKey)),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFE11D48),
                  onRefresh: _isConnected
                      ? () async {}
                      : () async {
                          setState(() => _quoteKey++);
                          await _loadAppData();
                          await _loadNodes();
                        },
                  child: VpnControlPanel(
                    status: _status,
                    node: _selectedNode,
                    message: _message,
                    remainingTimeText: _appStatus.remainingTimeText,
                    trafficRemaining: _displayTrafficRemaining,
                    isLoadingNodes: _isLoadingNodes,
                    isBusy: _isConnecting,
                    hasNodes: _nodes.isNotEmpty,
                    onReloadNodes: _loadNodes,
                    onPowerPressed: _isConnected ? _disconnect : _connect,
                    onNodePressed: _openNodePicker,
                  ),
                ),
              ),
              if (_session != null &&
                  _appStatus.remainingSeconds <= 0 &&
                  !_hasActivePlan)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shadowColor: const Color(0xFFE11D48).withOpacity(0.4),
                        elevation: 6,
                      ),
                      onPressed: _openPurchasePage,
                      icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                      label: const Text('试用已结束，去购买套餐'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
