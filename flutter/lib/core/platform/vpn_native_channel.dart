import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../pages/vpn_home/models/vpn_node.dart';
import 'windows_vpn_controller.dart';

class VpnNativeChannel {
  const VpnNativeChannel();

  static const MethodChannel _channel = MethodChannel('cy_vpn/native');
  static const EventChannel _statusChannel = EventChannel('cy_vpn/vpn_status');

  // 用于在 Windows 上模拟状态的控制器
  static final StreamController<String> _mockStatusController = StreamController<String>.broadcast();

  /// Request VPN permission.
  Future<String?> prepareVpn() async {
    if (!Platform.isAndroid) return null; // Windows 不需要权限申请
    return _channel.invokeMethod<String>('prepareVpn');
  }

  /// Send start command to the VPN service.
  Future<String?> startVpn(VpnNode node) async {
    if (!Platform.isAndroid) {
      // Windows 模拟/真实连接流程
      _mockStatusController.add('connecting');
      
      final success = await WindowsVpnController.start(node);
      if (!success) {
        _mockStatusController.add('disconnected');
        return '启动 Windows 代理失败，请检查 bin/windows/v2ray.exe 是否存在';
      }

      _mockStatusController.add('connected');
      return null;
    }
    return _channel.invokeMethod<String>('startVpn', {
      'nodeId': node.id,
      'name': node.name,
      'protocol': node.protocol,
      'address': node.address,
      'rawUri': node.rawUri,
    });
  }

  /// Send stop command to the VPN service.
  Future<String?> stopVpn() async {
    if (!Platform.isAndroid) {
      await WindowsVpnController.stop();
      _mockStatusController.add('disconnected');
      return null;
    }
    return _channel.invokeMethod<String>('stopVpn');
  }

  Future<void> openSupportH5() async {
    if (!Platform.isAndroid) return;
    return _channel.invokeMethod<void>('openSupportH5');
  }

  /// Stream of VPN status events.
  Stream<String> get statusStream {
    if (!Platform.isAndroid) {
      return _mockStatusController.stream;
    }
    return _statusChannel.receiveBroadcastStream().map((event) => event.toString());
  }
}
