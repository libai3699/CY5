import 'dart:async';
import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../pages/vpn_home/models/vpn_node.dart';
import 'windows_vpn_controller.dart';

class VpnNativeChannel {
  const VpnNativeChannel();

  static const MethodChannel _channel = MethodChannel('cy_vpn/native');
  static const EventChannel _statusChannel = EventChannel('cy_vpn/vpn_status');

  static final StreamController<String> _mockStatusController =
      StreamController<String>.broadcast();

  Future<String?> prepareVpn() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('prepareVpn');
  }

  Future<String?> startVpn(VpnNode node) async {
    if (kIsWeb) {
      _mockStatusController.add('connected');
      return null;
    }
    if (!Platform.isAndroid) {
      _mockStatusController.add('connecting');
      final success = await WindowsVpnController.start(node);
      if (!success) {
        _mockStatusController.add('disconnected');
        return '启动失败';
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

  Future<String?> stopVpn() async {
    if (kIsWeb) {
      _mockStatusController.add('disconnected');
      return null;
    }
    if (!Platform.isAndroid) {
      await WindowsVpnController.stop();
      _mockStatusController.add('disconnected');
      return null;
    }
    return _channel.invokeMethod<String>('stopVpn');
  }

  Future<void> openSupportH5() async {
    if (kIsWeb || !Platform.isAndroid) return;
    return _channel.invokeMethod<void>('openSupportH5');
  }

  Stream<String> get statusStream {
    if (kIsWeb || !Platform.isAndroid) {
      return _mockStatusController.stream;
    }
    return _statusChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }
}
