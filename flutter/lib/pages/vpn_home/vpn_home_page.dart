import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/vpn_native_channel.dart';
import 'components/app_drawer.dart';
import 'components/app_top_bar.dart';
import 'components/node_picker_sheet.dart';
import 'components/notice_bar.dart';
import 'components/vpn_control_panel.dart';
import 'data/vpn_subscription_loader.dart';
import 'data/vpn_nodes.dart';
import 'models/vpn_node.dart';
import 'models/vpn_status.dart';

class VpnHomePage extends StatefulWidget {
  const VpnHomePage({super.key});

  @override
  State<VpnHomePage> createState() => _VpnHomePageState();
}

class _VpnHomePageState extends State<VpnHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final VpnNativeChannel _vpnChannel = const VpnNativeChannel();
  final VpnSubscriptionLoader _subscriptionLoader = const VpnSubscriptionLoader();

  List<VpnNode> _nodes = const [];
  VpnNode? _selectedNode;
  VpnStatus _status = VpnStatus.disconnected;
  String? _message;
  bool _isLoadingNodes = true;

  StreamSubscription<String>? _statusSubscription;

  bool get _isConnected => _status == VpnStatus.connected;
  bool get _isConnecting => _status == VpnStatus.connecting;

  @override
  void initState() {
    super.initState();
    _loadNodes();
    _listenVpnStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
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
            break;
          case 'disconnected':
            setState(() {
              _status = VpnStatus.disconnected;
              _message = null;
            });
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

  Future<void> _loadNodes() async {
    setState(() {
      _isLoadingNodes = true;
      _message = null;
    });

    try {
      final nodes = await _subscriptionLoader.load(vpnSubscriptionUrl);

      setState(() {
        _nodes = nodes;
        _selectedNode = nodes.first;
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

  Future<void> _connect() async {
    final selectedNode = _selectedNode;
    if (selectedNode == null) {
      setState(() {
        _message = '请先加载并选择线路';
      });
      return;
    }

    // Set connecting state immediately for UI feedback
    setState(() {
      _status = VpnStatus.connecting;
      _message = '正在请求 VPN 权限...';
    });

    try {
      // Step 1: Request VPN permission (will wait for user response)
      final prepareResult = await _vpnChannel.prepareVpn();
      if (prepareResult != null) {
        // User denied or permission error
        setState(() {
          _status = VpnStatus.disconnected;
          _message = prepareResult;
        });
        return;
      }

      // Step 2: Permission granted, start VPN
      setState(() {
        _message = '正在连接 ${selectedNode.name}...';
      });

      final result = await _vpnChannel.startVpn(selectedNode);

      if (result != null) {
        setState(() {
          _message = result;
        });
      }
      // Don't set status here - we'll get it from the EventChannel
      // The native side will send "connecting" -> "connected" or "error"
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
    setState(() {
      _status = VpnStatus.connecting;
      _message = '正在断开...';
    });

    try {
      await _vpnChannel.stopVpn();
      // Status will come from EventChannel
    } on PlatformException catch (error) {
      setState(() {
        _status = VpnStatus.disconnected;
        _message = error.message ?? 'VPN stop failed';
      });
    }
  }

  Future<void> _openSupportH5() async {
    await _vpnChannel.openSupportH5();
  }

  void _openSettingsMenu() {
    _scaffoldKey.currentState?.openDrawer();
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.2, // 增大侧滑触发区域
      drawerEnableOpenDragGesture: true,
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
              const NoticeBar(subscriptionUrl: vpnSubscriptionUrl),
              Expanded(
                child: VpnControlPanel(
                  status: _status,
                  node: _selectedNode,
                  message: _message,
                  isLoadingNodes: _isLoadingNodes,
                  isBusy: _isConnecting,
                  hasNodes: _nodes.isNotEmpty,
                  onReloadNodes: _loadNodes,
                  onPowerPressed: _isConnected ? _disconnect : _connect,
                  onNodePressed: _openNodePicker,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
