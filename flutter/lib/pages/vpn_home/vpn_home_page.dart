import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/vpn_native_channel.dart';
import 'auth_page.dart';
import 'components/app_drawer.dart';
import 'components/app_top_bar.dart';
import 'components/node_picker_sheet.dart';
import 'components/notice_bar.dart';
import 'components/quote_card.dart';
import 'components/vpn_control_panel.dart';
import 'contact_page.dart';
import 'data/auth_service.dart';
import 'data/api_config.dart';
import 'data/device_identity.dart';
import 'data/remote_app_loader.dart';
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

  List<VpnNode> _nodes = const [];
  VpnNode? _selectedNode;
  String _deviceId = '';
  AuthSession? _session;
  AppStatus _appStatus = const AppStatus(
    planLevel: '免费体验',
    remainingSeconds: 0,
    remainingTimeText: '已到期',
    trafficRemaining: '0 GB',
  );
  Map<String, String> _appConfig = const {};
  VpnStatus _status = VpnStatus.disconnected;
  String? _message;
  bool _isLoadingNodes = true;
  bool _isRefreshingLines = false;
  Timer? _appStatusRefreshTimer;
  Timer? _heartbeatTimer;
  Timer? _remainingTimer;
  StreamSubscription<String>? _statusSubscription;

  bool get _isConnected => _status == VpnStatus.connected;
  bool get _isConnecting => _status == VpnStatus.connecting;
  bool get _hasActivePlan =>
      _appStatus.planLevel != '免费体验' && _appStatus.remainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _initDeviceAndAuth();
    _loadAppData();
    _loadNodes();
    _listenVpnStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _appStatusRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _remainingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDeviceAndAuth() async {
    try {
      final session = await _authService.loadSession();
      final displayId = await _deviceIdentity.register();
      if (!mounted) return;
      setState(() {
        _deviceId = displayId.isNotEmpty ? displayId : '获取中';
        _session = session;
      });
      if (session != null) _applySessionStatus(session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '设备上报失败：$error';
      });
    }
  }

  void _listenVpnStatus() {
    _statusSubscription = _vpnChannel.statusStream.listen(
      (event) {
        if (!mounted) return;

        if (event.startsWith('error:')) {
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
            setState(() {
              _status = VpnStatus.connected;
              _message = '${_selectedNode?.name ?? "VPN"} 已连接';
            });
            _syncHeartbeatTimer();
            break;
          case 'disconnected':
            setState(() {
              _status = VpnStatus.disconnected;
              _message = null;
            });
            _heartbeatTimer?.cancel();
            break;
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = VpnStatus.disconnected;
          _message = '状态监听异常：$error';
        });
      },
    );
  }

  Future<void> _loadAppData() async {
    try {
      final token = _session?.token;
      final status = token == null || token.isEmpty
          ? await _appLoader.loadStatus()
          : await _appLoader.loadUserStatus(token);
      print('[LOAD_APP_DATA] status ok: ${status.remainingTimeText} / ${status.trafficRemaining}');
      if (!mounted) return;
      setState(() { _appStatus = status; });
      _syncRemainingTimer(status.remainingSeconds);
      _syncStatusRefreshTimer();
    } catch (error) {
      print('[LOAD_APP_DATA] error: $error');
      if (!mounted) return;
      setState(() { _message = 'App 配置加载失败：$error'; });
    }
    try {
      final config = await _appLoader.loadConfig();
      if (!mounted) return;
      setState(() { _appConfig = config; });
    } catch (e) {
      print('[LOAD_CONFIG] error: $e');
    }
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
          _disconnect();
          _openPurchasePage();
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
    _sendHeartbeat(seconds: 1);
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _sendHeartbeat(seconds: 60);
    });
  }

  Future<void> _sendHeartbeat({required int seconds}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty || !_isConnected) return;
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(kUserHeartbeatApiUrl));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode({'seconds': seconds}));
      final response = await request.close();
      await response.drain<void>();
      await _loadAppData();
      if (_appStatus.remainingSeconds <= 0 && !_hasActivePlan) {
        await _disconnect();
      }
    } catch (_) {
      // 心跳失败不打断本次连接，下次继续上报。
    } finally {
      client.close(force: true);
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
    if (hours < 24) return restMinutes > 0 ? '$hours小时 $restMinutes分钟' : '$hours小时';
    final days = hours ~/ 24;
    final restHours = hours % 24;
    return restHours > 0 ? '$days天 $restHours小时' : '$days天';
  }

  Future<void> _loadNodes() async {
    setState(() {
      _isLoadingNodes = true;
      _message = null;
    });

    try {
      await _loadAppData();
      final nodes = await _lineLoader.load();
      setState(() {
        _nodes = nodes;
        _selectedNode = nodes.isNotEmpty ? nodes.first : null;
        _isLoadingNodes = false;
      });
    } catch (error) {
      setState(() {
        _nodes = const [];
        _selectedNode = null;
        _isLoadingNodes = false;
        _message = error.toString();
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
      if (!_sameNodes(_nodes, nextNodes)) {
        final currentId = _selectedNode?.id;
        VpnNode? nextSelected;
        for (final node in nextNodes) {
          if (node.id == currentId) {
            nextSelected = node;
            break;
          }
        }
        setState(() {
          _nodes = nextNodes;
          _selectedNode = nextSelected ?? (nextNodes.isNotEmpty ? nextNodes.first : null);
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
      if (a.id != b.id || a.name != b.name || a.address != b.address || a.rawUri != b.rawUri) {
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

    if ((session.trialExpired || _appStatus.remainingSeconds <= 0) && !_hasActivePlan) {
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
    } on PlatformException catch (error) {
      setState(() {
        _status = VpnStatus.disconnected;
        _message = error.message ?? 'VPN stop failed';
      });
    }
  }

  void _openContactPage() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const ContactPage(),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
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
    await _disconnect();
    await _authService.logout(token);
    if (!mounted) return;
    setState(() {
      _session = null;
      _appStatus = const AppStatus(
        planLevel: '免费体验',
        remainingSeconds: 0,
        remainingTimeText: '未登录',
        trafficRemaining: '0 GB',
      );
      _message = '已退出当前设备';
    });
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

  void _openPurchasePage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PurchasePage()),
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

  @override
  Widget build(BuildContext context) {
    print('[BUILD] remainingTimeText=${_appStatus.remainingTimeText} traffic=${_appStatus.trafficRemaining}');
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        deviceId: _deviceId.isEmpty ? '读取中' : _deviceId,
        isRefreshingLines: _isRefreshingLines,
        onLoginPressed: _openAuthPage,
        onDevicesPressed: _openLoginDevicesPage,
        onLogoutPressed: _logoutCurrentDevice,
        onNoticesPressed: _openNoticesPage,
        onPurchasePressed: _openPurchasePage,
        onRefreshLines: _refreshLinesFromDrawer,
        planLevel: _appStatus.planLevel,
        remainingTimeText: _appStatus.remainingTimeText,
        trafficRemaining: _appStatus.trafficRemaining,
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
              NoticeBar(token: _session?.token),
              const QuoteCard(),
              Expanded(
                child: VpnControlPanel(
                  status: _status,
                  node: _selectedNode,
                  message: _message,
                  remainingTimeText: _appStatus.remainingTimeText,
                  trafficRemaining: _appStatus.trafficRemaining,
                  isLoadingNodes: _isLoadingNodes,
                  isBusy: _isConnecting,
                  hasNodes: _nodes.isNotEmpty,
                  onReloadNodes: _loadNodes,
                  onPowerPressed: _isConnected ? _disconnect : _connect,
                  onNodePressed: _openNodePicker,
                ),
              ),
              if (_session != null && _appStatus.remainingSeconds <= 0 && !_hasActivePlan)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openPurchasePage,
                      icon: const Icon(Icons.shopping_bag_rounded),
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
