import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/vpn_native_channel.dart';
import '../../flavor_config.dart';
import 'auth_page.dart';
import 'chatgpt_page.dart';
import 'components/app_drawer.dart';
import 'components/app_top_bar.dart';
import 'components/node_picker_sheet.dart';
import 'components/notice_bar.dart';
import 'components/quote_card.dart';
import 'components/vpn_control_panel.dart';
import 'contact_page.dart';
import 'data/api_config.dart';
import 'data/auth_service.dart';
import 'data/contact_service.dart';
import 'data/device_identity.dart';
import 'data/node_speed_tester.dart';
import 'data/remote_app_loader.dart'
    show RemoteAppLoader, TokenExpiredException;
import 'data/remote_vpn_line_loader.dart';
import 'data/usage_reporter.dart';
import 'invite_reward_page.dart';
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
  static const String _updateWebsiteUrl = 'https://jsq.wangwei.tech';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final VpnNativeChannel _vpnChannel = const VpnNativeChannel();
  final RemoteVpnLineLoader _lineLoader = const RemoteVpnLineLoader();
  final RemoteAppLoader _appLoader = const RemoteAppLoader();
  final DeviceIdentity _deviceIdentity = const DeviceIdentity();
  final AuthService _authService = const AuthService();
  final UsageReporter _usageReporter = const UsageReporter();
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
  Timer? _localUsageTimer;
  Timer? _remainingTimer;
  StreamSubscription<String>? _statusSubscription;
  int _pendingTrafficBytes = 0; // 未成功上报的累计流量

  bool _hasCheckedAppVersion = false;
  bool _isUpdateDialogVisible = false;
  bool _hasLoadedAppData = false;
  // 记录当前 _appStatus 对应的登录 token，用于判断状态是否已是「当前会话」的最新数据。
  // 登录刚返回、真实用户状态还没拉回时，它与新 session 的 token 不一致，
  // 避免「去购买」按钮在空窗期闪现。游客态记为空串。
  String? _appStatusToken;
  bool _connectInFlight = false;
  int _loadNodesGeneration = 0;
  DateTime? _lastConnectTipAt;
  DateTime? _connectedAt;

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
    _uiRefreshTimer?.cancel();
    _localUsageTimer?.cancel();
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
        unawaited(_flushCachedUsage(session.token));
      }
    } catch (_) {}
    unawaited(_loadAppData());
    unawaited(_loadNodes());
    unawaited(_registerDevice());
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
              _connectedAt = DateTime.now();
              setState(() {
                _status = VpnStatus.connected;
                _message = '${_selectedNode?.name ?? "VPN"} 已连接';
              });
              unawaited(_usageReporter.markConnected());
              _syncHeartbeatTimer();
            }
            break;
          case 'disconnected':
            final wasConnected = _status == VpnStatus.connected;
            final wasConnecting = _status == VpnStatus.connecting;
            _connectedAt = null;
            setState(() {
              _status = VpnStatus.disconnected;
              if (wasConnected) {
                _message = null;
              } else if (wasConnecting && _message != null && _message!.contains('正在连接')) {
                _message = '连接失败，请重试';
              }
            });
            if (wasConnected) {
              _heartbeatTimer?.cancel();
              _uiRefreshTimer?.cancel();
              _localUsageTimer?.cancel();
              unawaited(_collectAndFlushUsage());
            }
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
    try {
      final status = token == null || token.isEmpty
          ? await _appLoader.loadStatus()
          : await _appLoader.loadUserStatus(token);
      if (!mounted) return;
      setState(() {
        _appStatus = status;
        _hasLoadedAppData = true;
        _appStatusToken = token ?? '';
      });
      _syncRemainingTimer(status.remainingSeconds);
      _syncStatusRefreshTimer();
    } on TokenExpiredException {
      if (_isConnected) {
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
      unawaited(_checkAppVersion(config));
    } catch (_) {}
  }

  /// Token 过期：清空本地 session，断开 VPN，提示用户重新登录
  Future<void> _checkAppVersion(Map<String, String> config) async {
    if (!mounted || _hasCheckedAppVersion) return;

    final latestVersion = config[_remoteVersionConfigKey]?.trim() ?? '';
    if (latestVersion.isEmpty) return;

    _hasCheckedAppVersion = true;
    if (latestVersion == kAppVersion) return;

    final downloadUrl = config[_downloadUrlConfigKey]?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showUpdateDialog(latestVersion, downloadUrl));
    });
  }

  String get _remoteVersionConfigKey =>
      FlavorConfig.isAcc ? 'app_acc_version' : 'app_vpn_version';

  String get _downloadUrlConfigKey {
    if (!kIsWeb && Platform.isWindows) {
      return FlavorConfig.isAcc ? 'download_acc_exe' : 'download_vpn_exe';
    }
    return FlavorConfig.isAcc ? 'download_acc_apk' : 'download_vpn_apk';
  }

  Future<void> _showUpdateDialog(
    String latestVersion,
    String downloadUrl,
  ) async {
    if (!mounted || _isUpdateDialogVisible) return;
    _isUpdateDialogVisible = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '发现新版本',
        barrierColor: Colors.black.withOpacity(0.55),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogContext, _, __) {
          return _UpdateDialog(
            latestVersion: latestVersion,
            currentVersion: kAppVersion,
            appName: FlavorConfig.appName,
            onUpdate: () async {
              Navigator.of(dialogContext).pop();
              await _openUpdateLink(latestVersion);
            },
            onLater: () => Navigator.of(dialogContext).pop(),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: Transform.scale(
              scale: 0.92 + 0.08 * curved.value,
              child: child,
            ),
          );
        },
      );
    } finally {
      _isUpdateDialogVisible = false;
    }
  }

  Future<void> _openUpdateLink(String latestVersion) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        const channel = MethodChannel('9.9/native');
        await channel.invokeMethod<void>(
          'openExternalUrl',
          <String, String>{'url': _updateWebsiteUrl},
        );
        return;
      }

      if (!kIsWeb && Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', _updateWebsiteUrl]);
      } else if (!kIsWeb && Platform.isMacOS) {
        await Process.run('open', [_updateWebsiteUrl]);
      } else if (!kIsWeb && Platform.isLinux) {
        await Process.run('xdg-open', [_updateWebsiteUrl]);
      } else {
        throw UnsupportedError('当前平台暂不支持自动打开官网');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开官网失败：$error。请手动访问 $_updateWebsiteUrl'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleTokenExpired({String? expectedToken}) async {
    final currentToken = _session?.token;
    if (expectedToken != null &&
        expectedToken.isNotEmpty &&
        currentToken != expectedToken) {
      return;
    }

    if (expectedToken != null && expectedToken.isNotEmpty) {
      try {
        final persistedSession = await _authService.loadSession();
        final persistedToken = persistedSession?.token;
        if (persistedToken != null &&
            persistedToken.isNotEmpty &&
            persistedToken != expectedToken) {
          return;
        }
      } catch (_) {}
    }

    if (_isConnected) {
      if (mounted) {
        setState(() {
          _message = '登录状态异常，当前连接保持中';
        });
      }
      return;
    }

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
      if (mounted && !_isConnected) _loadAppData();
    });
  }

  void _syncHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _localUsageTimer?.cancel();
    _pendingTrafficBytes = 0;
    unawaited(VpnNativeChannel.resetTrafficBaseline());

    // 每30秒采集本地流量增量
    _localUsageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_collectLocalUsage());
    });

    // 每60秒发送心跳，上报流量到服务器并刷新状态
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_sendHeartbeat());
    });

    // 每5秒刷新UI，显示最新流量余额
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isConnected) {
        setState(() {}); // 触发 _displayTrafficRemaining 重新计算
      }
    });
  }

  /// 发送心跳，上报流量到服务器并刷新用户状态
  Future<void> _sendHeartbeat() async {
    if (!_isConnected) return;
    final token = _session?.token;
    if (token == null || token.isEmpty) return;

    try {
      // ✅ 只调用一次 collectHeartbeatTraffic，避免重复统计
      // 不再调用 _collectLocalUsage()，因为 collectHeartbeatTraffic 内部会调用 pollTrafficDelta
      await _usageReporter.collectHeartbeatTraffic(); // 收集流量但保持会话活跃
      await _usageReporter.flush(token); // 上报到服务器并清空缓存
      
      // ✅ 上报成功后，重置所有计数器
      if (mounted) {
        setState(() {
          _pendingTrafficBytes = 0;
        });
      }
      
      // ✅ 重置VPN底层的流量基线，避免重复统计
      await VpnNativeChannel.resetTrafficBaseline();
      
      // 刷新用户状态，获取最新余额
      try {
        final status = await _appLoader.loadUserStatus(token);
        if (mounted && _isConnected) {
          setState(() {
            _appStatus = status;
          });
        }
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _collectLocalUsage() async {
    if (!_isConnected) return;
    final delta = await VpnNativeChannel.pollTrafficDelta();
    if (delta <= 0) return;
    unawaited(_usageReporter.addPendingTraffic(delta));
    if (!mounted || !_isConnected) return;
    setState(() {
      _pendingTrafficBytes += delta;
    });
  }

  Future<void> _flushCachedUsage(String? token) async {
    await _usageReporter.collectAbandonedSession();
    await _usageReporter.flush(token);
    // ✅ 上报后重置VPN底层的流量基线
    await VpnNativeChannel.resetTrafficBaseline();
  }

  Future<void> _collectAndFlushUsage() async {
    // ✅ 只调用一次 collectCurrentSession，避免重复统计
    await _usageReporter.collectCurrentSession();
    await _usageReporter.flush(_session?.token).timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
    // ✅ 断开后重置所有计数器
    await VpnNativeChannel.resetTrafficBaseline();
    if (mounted) {
      setState(() {
        _pendingTrafficBytes = 0;
      });
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

  Future<void> _loadNodes() async {
    if (!mounted) return;
    final generation = ++_loadNodesGeneration;
    setState(() {
      _isLoadingNodes = true;
      if (_message == '线路测速中，请稍候...' ||
          _message == '请先加载并选择线路') {
        _message = null;
      }
    });
    try {
      final nodes = await _lineLoader.load();
      final sortedNodes = await _speedTester.testAndSortNodes(nodes);

      if (!mounted || generation != _loadNodesGeneration) {
        return;
      }
      setState(() {
        _nodes = sortedNodes;
        _selectedNode = sortedNodes.isNotEmpty ? sortedNodes.first : null;
        _isLoadingNodes = false;
        if (_message == '线路测速中，请稍候...' ||
            _message == '请先加载并选择线路') {
          _message = null;
        }
      });
    } catch (_) {
      if (!mounted || generation != _loadNodesGeneration) return;
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

  Future<void> _refreshHome() async {
    if (_isConnected) return;
    setState(() => _quoteKey++);
    try {
      await _loadAppData().timeout(const Duration(seconds: 3));
    } catch (_) {}
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

  void _showConnectBlockedTip(String tip) {
    if (!mounted) return;
    setState(() {
      _message = tip;
    });

    final now = DateTime.now();
    if (_lastConnectTipAt != null &&
        now.difference(_lastConnectTipAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastConnectTipAt = now;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tip),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _connect() async {
    if (_connectInFlight || _isConnecting || _isConnected) {
      return;
    }
    if (_isLoadingNodes) {
      _showConnectBlockedTip('线路测速中，请稍候...');
      return;
    }

    _connectInFlight = true;
    try {
      var session = _session;
      if (session == null) {
        session = await Navigator.of(context).push<AuthSession>(
          MaterialPageRoute<AuthSession>(
            builder: (_) => AuthPage(config: _appConfig),
          ),
        );
        if (session == null || !mounted) {
          return;
        }
        setState(() {
          _session = session;
        });
        _applySessionStatus(session);
        await _loadAppData();
      }

      if (!mounted) return;

      if (!_keepVpnConnected &&
          (session.trialExpired || _appStatus.remainingSeconds <= 0) &&
          !_hasActivePlan) {
        setState(() {
          _message = '试用已结束，请购买套餐后连接';
        });
        _openPurchasePage();
        return;
      }

      if (_isLoadingNodes) {
        _showConnectBlockedTip('线路测速中，请稍候...');
        return;
      }

      final selectedNode = _selectedNode;
      if (selectedNode == null) {
        _showConnectBlockedTip('请先加载并选择线路');
        return;
      }

      setState(() {
        _status = VpnStatus.connecting;
        _message = '正在请求 VPN 权限...';
      });

      try {
        await _flushCachedUsage(session.token).timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
        final prepareResult = await _vpnChannel.prepareVpn();
        if (prepareResult != null) {
          if (!mounted) return;
          setState(() {
            _status = VpnStatus.disconnected;
            _message = prepareResult;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _message = '正在连接 ${selectedNode.name}...';
        });

        final result = await _vpnChannel.startVpn(selectedNode);
        if (!mounted) return;
        if (result != null) {
          setState(() {
            _status = VpnStatus.disconnected;
            _message = result;
          });
        }
      } on PlatformException catch (error) {
        if (!mounted) return;
        setState(() {
          _status = VpnStatus.disconnected;
          _message = error.message ?? 'VPN start failed';
        });
      } on MissingPluginException {
        if (!mounted) return;
        setState(() {
          _status = VpnStatus.disconnected;
          _message = '原生 VPN 通道未加载，请停止应用后重新运行安装';
        });
      }
    } finally {
      _connectInFlight = false;
    }
  }

  Future<void> _disconnect() async {
    final connectedAt = _connectedAt;
    if (connectedAt != null &&
        DateTime.now().difference(connectedAt) < const Duration(seconds: 2)) {
      return;
    }

    _heartbeatTimer?.cancel();
    _localUsageTimer?.cancel();
    await _collectLocalUsage();
    await _usageReporter.collectCurrentSession();
    setState(() {
      _message = '正在断开...';
    });

    try {
      await _vpnChannel.stopVpn();
    } catch (_) {
    } finally {
      await _usageReporter.flush(_session?.token).timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );
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
    if (session == null || !mounted) return;
    setState(() {
      _session = session;
    });
    _applySessionStatus(session);
    await _loadAppData();
  }

  Future<void> _logoutCurrentDevice() async {
    final token = _session?.token;
    if (token == null || token.isEmpty) return;

    // 先断开 VPN
    if (!_keepVpnConnected && (_isConnected || _isConnecting)) {
      await _disconnect();
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

  void _openInviteRewardPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InviteRewardPage(inviteCode: _session?.inviteCode ?? ''),
      ),
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
    if (_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先断开连接再切换线路'),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
          return '${(newBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
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
      
      // 简化逻辑：直接显示后端返回的值
      // 因为现在有心跳定时器（每60秒），后端数据会及时更新
      // 只对未上报的流量（最多60秒内的）进行乐观更新
      if (!_isConnected) return text;
      
      // 只显示当前未消费的流量增量（秒级更新）
      final unconsumedBytes = VpnNativeChannel.unconsumedBytes;
      if (unconsumedBytes <= 0) return text;
      
      // 乐观更新：减去实时流量增量（不包括已累积的 _pendingTrafficBytes）
      return _calculateOptimisticTraffic(text, unconsumedBytes);
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
        inviteCode: _session?.inviteCode ?? '',
        isRefreshingLines: _isRefreshingLines,
        onChatGptPressed: _openChatGptPage,
        onLoginPressed: _openAuthPage,
        onDevicesPressed: _openLoginDevicesPage,
        onInvitePressed: _openInviteRewardPage,
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
                  if (!_isConnected) _loadAppData();
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
                  onRefresh: _refreshHome,
                  child: VpnControlPanel(
                    status: _status,
                    node: _selectedNode,
                    message: _message,
                    remainingTimeText: _appStatus.remainingTimeText,
                    trafficRemaining: _displayTrafficRemaining,
                    isLoadingNodes: _isLoadingNodes,
                    isLoadingStatus: !_hasLoadedAppData,
                    isBusy: _isConnecting || _isLoadingNodes,
                    hasNodes: _nodes.isNotEmpty,
                    onReloadNodes: _loadNodes,
                    onPowerPressed: _isConnected ? _disconnect : _connect,
                    onNodePressed: _openNodePicker,
                  ),
                ),
              ),
              if (_hasLoadedAppData &&
                  _session != null &&
                  _appStatusToken == _session!.token &&
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

/// 科技风「发现新版本」弹框：深色玻璃拟态 + 霓虹光晕 + 呼吸动效。
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.latestVersion,
    required this.currentVersion,
    required this.appName,
    required this.onUpdate,
    required this.onLater,
  });

  final String latestVersion;
  final String currentVersion;
  final String appName;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  static const Color _accent = Color(0xFFFB7185); // 玫红霓虹（rose-400）
  static const Color _accent2 = Color(0xFFE11D48); // 主题玫红（rose-600）
  static const Color _panelTop = Color(0xFF2A0E1A); // 深玫红黑
  static const Color _panelBottom = Color(0xFF120207);

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, child) {
                final t = _glow.value;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_panelTop, _panelBottom],
                    ),
                    border: Border.all(
                      color: _accent.withOpacity(0.30 + 0.25 * t),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.18 + 0.16 * t),
                        blurRadius: 34,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: _accent2.withOpacity(0.12 + 0.12 * t),
                        blurRadius: 50,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Material(
                type: MaterialType.transparency,
                child: _buildBody(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -30,
          child: _blurDot(_accent.withOpacity(0.35), 120),
        ),
        Positioned(
          bottom: -50,
          left: -40,
          child: _blurDot(_accent2.withOpacity(0.30), 140),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIcon(),
              const SizedBox(height: 18),
              const Text(
                '发现新版本',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.appName} 有新版本可用，升级以获得更稳定流畅的体验。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.62),
                ),
              ),
              const SizedBox(height: 22),
              _buildVersionRow(),
              const SizedBox(height: 24),
              _buildUpdateButton(),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onLater,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  '稍后再说',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accent, _accent2],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.5),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.rocket_launch_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildVersionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _versionChip('当前', 'v${widget.currentVersion}',
              Colors.white.withOpacity(0.5), false),
          Icon(
            Icons.arrow_forward_rounded,
            color: _accent.withOpacity(0.9),
            size: 22,
          ),
          _versionChip('最新', 'v${widget.latestVersion}', _accent, true),
        ],
      ),
    );
  }

  Widget _versionChip(String label, String value, Color color, bool glow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            shadows: glow
                ? [Shadow(color: color.withOpacity(0.7), blurRadius: 12)]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [_accent, _accent2],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onUpdate,
          child: const SizedBox(
            height: 52,
            child: Center(
              child: Text(
                '立即更新',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blurDot(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}
