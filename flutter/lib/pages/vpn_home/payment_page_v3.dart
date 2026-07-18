import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/gallery_saver.dart';
import '../../utils/platform_utils.dart';
import 'components/common_page_top_bar.dart';
import 'components/payment_page_windows_layout.dart';
import 'contact_page.dart';
import 'data/api_config.dart';

class PaymentPageV3 extends StatefulWidget {
  const PaymentPageV3({
    super.key,
    required this.planName,
    required this.totalPrice,
    required this.cycle,
    required this.planId,
    required this.billingCycle,
    required this.token,
  });

  final String planName;
  final double totalPrice;
  final String cycle;
  final int planId;
  final String billingCycle;
  final String? token;

  @override
  State<PaymentPageV3> createState() => _PaymentPageV3State();
}

class _PaymentPageV3State extends State<PaymentPageV3> {
  String _selectedChannel = 'wechat'; // wechat, alipay, qq, usdt
  String _paymentMode = 'auto'; // auto, manual
  String _selectedManualChannel = 'wechat'; // usdt, wechat, alipay, qq
  String _selectedUsdtNetwork = 'bep20'; // trc20, bep20, erc20

  List<_PaymentConfig> _usdtConfigs = [];
  List<_PaymentConfig> _wechatConfigs = [];
  List<_PaymentConfig> _alipayConfigs = [];
  List<_PaymentConfig> _qqConfigs = [];

  bool _loading = true;
  String? _error;
  double _usdtRate = 7.2;
  String? _orderNo;
  bool _creatingPayment = false;
  final Set<String> _savedManualQrUrls = <String>{};

  // 仅用于界面展示；实际支付金额始终由服务端按套餐计算。
  late final double _paymentAmount;
  late double _usdtAmount;

  bool get _loggedIn => widget.token != null && widget.token!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _paymentAmount = widget.totalPrice;
    _usdtAmount = _paymentAmount / _usdtRate; // 初始化 USDT 金额

    _loadPaymentConfigs();
    _loadUsdtRate();
  }

  Future<void> _loadUsdtRate() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
      );
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      final cny = double.tryParse(decoded?['rates']?['CNY']?.toString() ?? '');
      if (cny != null && cny > 0 && mounted) {
        setState(() {
          _usdtRate = cny;
          _usdtAmount = _paymentAmount / _usdtRate;
        });
      }
    } catch (_) {
      setState(() => _usdtAmount = _paymentAmount / _usdtRate);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadPaymentConfigs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(kPaymentConfigsApiUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败：${response.statusCode}');
      }

      final decoded = jsonDecode(body);
      final list = decoded?['data'];
      if (list is List) {
        final configs = list
            .whereType<Map<String, dynamic>>()
            .map(_PaymentConfig.fromJson)
            .toList();

        if (mounted) {
          setState(() {
            _usdtConfigs = configs
                .where((c) =>
                    c.type == 'usdt_trc20' ||
                    c.type == 'usdt_bep20' ||
                    c.type == 'usdt_erc20')
                .toList();
            _wechatConfigs = configs.where((c) => c.type == 'wechat').toList();
            _alipayConfigs = configs.where((c) => c.type == 'alipay').toList();
            _qqConfigs = configs.where((c) => c.type == 'qq').toList();

            if (_loggedIn) {
              _selectedChannel = _wechatConfigs.isNotEmpty
                  ? 'wechat'
                  : (_alipayConfigs.isNotEmpty ? 'alipay' : 'qq');
            } else if (_usdtConfigs.isNotEmpty) {
              final network = _usdtConfigs.first.type.replaceFirst('usdt_', '');
              if (network.isNotEmpty) _selectedUsdtNetwork = network;
            }

            if (_wechatConfigs.isNotEmpty) {
              _selectedManualChannel = 'wechat';
            } else if (_alipayConfigs.isNotEmpty) {
              _selectedManualChannel = 'alipay';
            } else if (_qqConfigs.isNotEmpty) {
              _selectedManualChannel = 'qq';
            } else if (_usdtConfigs.isNotEmpty) {
              _selectedManualChannel = 'usdt';
            }

            _paymentMode = _loggedIn ? 'auto' : 'manual';
            _loading = false;
          });
        }
      } else {
        throw Exception('数据格式错误');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _startOnlinePayment() async {
    if (!_loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发起在线支付')),
      );
      return;
    }
    if (_selectedChannel != 'alipay' &&
        _selectedChannel != 'wechat' &&
        _selectedChannel != 'qq') {
      _openContact();
      return;
    }

    setState(() => _creatingPayment = true);
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(kPaymentOrdersApiUrl));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer ${widget.token}');
      request.write(jsonEncode({
        'plan_id': widget.planId,
        'billing_cycle': widget.billingCycle,
        'pay_type': switch (_selectedChannel) {
          'wechat' => 'wxpay',
          'qq' => 'qqpay',
          _ => 'alipay',
        },
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (decoded['code'] as num?)?.toInt() != 0) {
        throw Exception(decoded['message']?.toString() ?? '创建支付订单失败');
      }
      final data = decoded['data'] as Map<String, dynamic>?;
      final payUrl = data?['pay_url']?.toString() ?? '';
      final orderNo = data?['order_no']?.toString() ?? '';
      if (payUrl.isEmpty || orderNo.isEmpty) {
        throw Exception('支付接口返回数据不完整');
      }
      _orderNo = orderNo;
      final opened = await launchUrl(
        Uri.parse(payUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('无法打开支付页面');
      if (mounted) await _showPaymentResultDialog();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u652f\u4ed8\u64cd\u4f5c\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5'),
          ),
        );
      }
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _creatingPayment = false);
    }
  }

  Future<bool> _checkPaymentStatus() async {
    if (_orderNo == null || widget.token == null) return false;
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$kPaymentOrdersApiUrl/${Uri.encodeComponent(_orderNo!)}'),
      );
      request.headers.set('Authorization', 'Bearer ${widget.token}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'];
      return decoded['code'] == 0 &&
          data is Map<String, dynamic> &&
          data['status'] == 'paid';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<({bool ok, String message})> _notifyPaymentConfirmed() async {
    if (!_loggedIn) {
      return (ok: false, message: '请先登录后再确认付款');
    }

    final channel =
        _paymentMode == 'manual' ? _selectedManualChannel : _selectedChannel;
    final client = HttpClient();
    try {
      final request =
          await client.postUrl(Uri.parse(kPaymentConfirmNotifyApiUrl));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer ${widget.token}');
      request.write(jsonEncode({
        'plan_id': widget.planId,
        'billing_cycle': widget.billingCycle,
        'pay_channel': channel,
        'payment_mode': _paymentMode,
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (decoded['code'] as num?)?.toInt() == 0;
      if (ok) {
        return (
          ok: true,
          message: _paymentMode == 'auto'
              ? '已记录确认，正在跳转支付...'
              : '套餐已开通，管理员将核实付款',
        );
      }
      final message = decoded['message']?.toString().trim();
      return (
        ok: false,
        message: message?.isNotEmpty == true ? message! : '开通失败，请稍后重试',
      );
    } catch (_) {
      return (ok: false, message: '网络异常，开通失败，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _finishPaymentActivation(({bool ok, String message}) result) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.ok) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<bool> _showPaymentSecondConfirm({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleAutoPaymentAction() async {
    if (_orderNo != null) {
      await _checkAndShowStatus();
      return;
    }
    final confirmed = await _showPaymentSecondConfirm(
      title: '再次确认',
      content: '确认后将打开浏览器前往第三方支付，请按页面金额完成付款。',
      confirmText: '确认前往支付',
    );
    if (!confirmed || !mounted) return;
    final result = await _notifyPaymentConfirmed();
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    await _startOnlinePayment();
  }

  Future<void> _handleWindowsPaymentAction() async {
    if (_paymentMode == 'manual' || _selectedChannel == 'usdt') {
      await _confirmManualPaymentV4();
      return;
    }
    await _handleAutoPaymentAction();
  }

  _PaymentConfig? _manualConfigForChannel(String channel) {
    switch (channel) {
      case 'wechat':
        return _wechatConfigs.isNotEmpty ? _wechatConfigs.first : null;
      case 'alipay':
        return _alipayConfigs.isNotEmpty ? _alipayConfigs.first : null;
      case 'qq':
        return _qqConfigs.isNotEmpty ? _qqConfigs.first : null;
      case 'usdt':
        return _currentUsdtConfig;
      default:
        return null;
    }
  }

  String? get _windowsPreviewQrUrl {
    final channel =
        _paymentMode == 'manual' ? _selectedManualChannel : _selectedChannel;
    final config = _manualConfigForChannel(channel);
    final qr = config?.qrCode ?? '';
    return qr.isNotEmpty ? qr : null;
  }

  bool _channelHasAutoConfig(String channel) {
    return switch (channel) {
      'alipay' => _alipayConfigs.isNotEmpty,
      'wechat' => _wechatConfigs.isNotEmpty,
      'qq' => _qqConfigs.isNotEmpty,
      _ => false,
    };
  }

  Future<void> _checkAndShowStatus() async {
    final paid = await _checkPaymentStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(paid ? '支付已到账，套餐已自动开通' : '暂未到账，请稍后再检查'),
      ),
    );
  }

  Future<void> _showPaymentResultDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('已打开支付页面'),
        content: Text('订单号：$_orderNo\n完成付款后回到这里检查到账结果。请勿为同一订单重复付款。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('稍后检查'),
          ),
          FilledButton(
            onPressed: () async {
              final paid = await _checkPaymentStatus();
              if (!mounted || !dialogContext.mounted) return;
              if (paid) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('支付已到账，套餐已自动开通')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('暂未到账，请稍后再检查')),
                );
              }
            },
            child: const Text('检查到账'),
          ),
        ],
      ),
    );
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label已复制'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveQrCode(String imageUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('图片下载失败');
      }
      final bytes = await response.expand((chunk) => chunk).toList();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'payment_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('二维码已保存：${file.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              '\u4e8c\u7ef4\u7801\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u5b58\u50a8\u6743\u9650'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _saveQrCodeToGallery(String imageUrl) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('保存二维码到相册'),
            content: const Text(
              '即将把二维码保存到系统相册，部分安卓设备可能需要手动授权相册权限。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('继续保存'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final result = await GallerySaver.saveQrCodeFromUrl(imageUrl);
    if (!mounted) {
      return;
    }
    if (result.success) {
      setState(() => _savedManualQrUrls.add(imageUrl));
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: Duration(seconds: result.success ? 3 : 2),
      ),
    );
  }

  void _openContact() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ContactPage(),
    ));
  }

  _PaymentConfig? get _currentUsdtConfig {
    return _usdtConfigs.firstWhere(
      (c) => c.type == 'usdt_$_selectedUsdtNetwork',
      orElse: () =>
          _usdtConfigs.isNotEmpty ? _usdtConfigs.first : _PaymentConfig.empty(),
    );
  }

  _PaymentConfig? get _selectedPreviewConfig {
    if (_selectedChannel == 'usdt') {
      return _currentUsdtConfig;
    }
    if (_selectedChannel == 'wechat' && _wechatConfigs.isNotEmpty) {
      return _wechatConfigs.first;
    }
    if (_selectedChannel == 'alipay' && _alipayConfigs.isNotEmpty) {
      return _alipayConfigs.first;
    }
    return null;
  }

  String? get _selectedPreviewImageUrl =>
      _selectedChannel == 'usdt' ? _selectedPreviewConfig?.qrCode : null;

  String get _selectedPreviewTitle {
    final config = _selectedPreviewConfig;
    if (config != null && config.label.isNotEmpty) {
      return '${config.label}二维码';
    }
    return '当前收款二维码';
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = PlatformUtils.isWindows
        ? 1320.0
        : (PlatformUtils.getContentMaxWidth() ?? double.infinity);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Column(
              children: [
                const CommonPageTopBar(
                  title: '确认支付',
                  showRightButton: false,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE11D48)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadPaymentConfigs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
              ),
            ),
          ],
        ),
      );
    }

    if (PlatformUtils.isWindows) {
      return _buildWindowsBody();
    }

    return _buildMobilePaymentFlowV4();
  }

  Widget _buildWindowsBody() {
    final previewUrl = _windowsPreviewQrUrl;
    final manualLike = _paymentMode == 'manual' || _selectedChannel == 'usdt';
    return PaymentPageWindowsLayout(
      leftContent: _buildWindowsLeftContentClean(),
      previewTitle: previewUrl != null
          ? (_manualConfigForChannel(
                    _paymentMode == 'manual'
                        ? _selectedManualChannel
                        : _selectedChannel,
                  )?.label ??
                  '收款二维码')
          : _selectedPreviewTitleClean,
      previewImageUrl: previewUrl,
      onActionPressed: _creatingPayment ? null : _handleWindowsPaymentAction,
      actionLabel: _creatingPayment
          ? '正在创建订单...'
          : manualLike
              ? '我已支付完毕'
              : (_orderNo == null ? '确认并前往支付' : '检查订单状态'),
      onlinePayment: !manualLike && previewUrl == null,
    );
  }

  String get _selectedPreviewTitleClean {
    if (_selectedChannel != 'usdt') {
      return switch (_selectedChannel) {
        'wechat' => '\u5fae\u4fe1\u5728\u7ebf\u6536\u94f6\u53f0',
        'qq' => 'QQ \u5728\u7ebf\u6536\u94f6\u53f0',
        _ => '\u652f\u4ed8\u5b9d\u5728\u7ebf\u6536\u94f6\u53f0',
      };
    }
    final config = _selectedPreviewConfig;
    if (config != null && config.label.isNotEmpty) {
      return '${config.label}\u4e8c\u7ef4\u7801';
    }
    return '\u5f53\u524d\u6536\u6b3e\u4e8c\u7ef4\u7801';
  }

  Widget _buildWindowsLeftContentClean() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\u8ba2\u5355\u4fe1\u606f',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('\u5957\u9910', widget.planName),
              _buildInfoRow('\u5468\u671f', widget.cycle),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '\u5e94\u4ed8\u91d1\u989d',
                    style: TextStyle(
                      color: Color(0xFF881337),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\u00A5${_paymentAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_selectedChannel == 'usdt')
                        Text(
                          '~ ${_usdtAmount.toStringAsFixed(2)} USDT',
                          style: TextStyle(
                            color: const Color(0xFF9F1239).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        )
                      else
                        const Text(
                          '\u5b9e\u9645\u91d1\u989d\u4ee5\u6536\u94f6\u53f0\u8ba2\u5355\u4e3a\u51c6',
                          style: TextStyle(
                            color: Color(0xFF9F1239),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            children: [
              const Text(
                '\u9009\u62e9\u652f\u4ed8\u65b9\u5f0f',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildChannelCard(
                      'wechat',
                      '\u5fae\u4fe1\u652f\u4ed8',
                      'assets/images/contact/wechat.png',
                      true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'alipay',
                      '\u652f\u4ed8\u5b9d',
                      'assets/images/contact/alipay.png',
                      true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'qq',
                      'QQ',
                      'assets/images/contact/qq.png',
                      true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'usdt',
                      'USDT',
                      'assets/images/contact/USDT.png',
                      _usdtConfigs.isNotEmpty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 76,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD5DF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildWindowsModeTab('auto', '自动支付'),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _buildWindowsModeTab('manual', '手动支付'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedChannel == 'usdt' && _usdtConfigs.isNotEmpty) ...[
                const Text(
                  '\u9009\u62e9\u7f51\u7edc',
                  style: TextStyle(
                    color: Color(0xFF881337),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNetworkChip('trc20', 'TRC20')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNetworkChip('bep20', 'BEP20')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNetworkChip('erc20', 'ERC20')),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPaymentInfo(),
              ],
              if (_selectedChannel == 'wechat' ||
                  _selectedChannel == 'alipay' ||
                  _selectedChannel == 'qq')
                _paymentMode == 'manual' &&
                        _manualConfigForChannel(_selectedChannel) != null
                    ? _buildWechatAlipayInfo(
                        _manualConfigForChannel(_selectedChannel)!,
                      )
                    : _buildOnlinePaymentInfo(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsLeftContent() {
    return _buildWindowsLeftContentClean();
  }

  Widget _buildWindowsModeTab(String value, String label) {
    final selected = _paymentMode == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _paymentMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE11D48) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF881337),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCard(
      String value, String label, String iconAsset, bool enabled) {
    final isSelected = _selectedChannel == value;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
                _selectedChannel = value;
                if (value != 'usdt') {
                  _selectedManualChannel = value;
                } else {
                  _selectedManualChannel = 'usdt';
                }
                _orderNo = null;
              })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE11D48).withOpacity(0.1)
              : Colors.white.withOpacity(enabled ? 0.85 : 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Image.asset(
                iconAsset,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFE11D48)
                    : enabled
                        ? const Color(0xFF881337)
                        : Colors.grey,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '未配置',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePaymentInfo() {
    final isAlipay = _selectedChannel == 'alipay';
    final isQq = _selectedChannel == 'qq';
    final accent = isAlipay
        ? const Color(0xFF1677FF)
        : isQq
            ? const Color(0xFF12B7F5)
            : const Color(0xFF07C160);
    final channelName = isAlipay
        ? '支付宝'
        : isQq
            ? 'QQ支付'
            : '微信支付';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isAlipay
                      ? Icons.account_balance_wallet_rounded
                      : isQq
                          ? Icons.forum_rounded
                          : Icons.chat_bubble_rounded,
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$channelName 在线支付',
                      style: const TextStyle(
                        color: Color(0xFF3F1723),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '订单金额由服务端计算，无需手动备注',
                      style: TextStyle(
                        color: Color(0xFF8A6872),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '自动开通',
                  style: TextStyle(
                    color: Color(0xFF168A50),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _OnlinePaymentStep(
            number: '1',
            title: '创建安全订单',
            description: '服务端按当前套餐和周期生成订单',
          ),
          const _OnlinePaymentStep(
            number: '2',
            title: '前往收银台付款',
            description: '将在系统浏览器中打开支付页面',
          ),
          const _OnlinePaymentStep(
            number: '3',
            title: '返回应用检查到账',
            description: '支付成功后套餐会自动开通，请勿重复付款',
            last: true,
          ),
          if (!_loggedIn) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '请先登录账号再发起在线支付，套餐将开通到当前账号。',
                style: TextStyle(
                  color: Color(0xFF9A4B13),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_orderNo != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '当前订单：$_orderNo\n如已付款，请点击下方按钮检查到账状态。',
                style: const TextStyle(
                  color: Color(0xFF6F4B57),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkChip(String network, String label) {
    final isSelected = _selectedUsdtNetwork == network;
    final config = _usdtConfigs.firstWhere(
      (c) => c.type == 'usdt_$network',
      orElse: () => _PaymentConfig.empty(),
    );
    final enabled = config.address.isNotEmpty || config.qrCode.isNotEmpty;

    return GestureDetector(
      onTap:
          enabled ? () => setState(() => _selectedUsdtNetwork = network) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE11D48)
              : Colors.white.withOpacity(enabled ? 0.85 : 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE11D48)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF881337),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!enabled)
              Text(
                '未配置',
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.grey,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final config = _currentUsdtConfig;
    if (config == null || (config.address.isEmpty && config.qrCode.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '该网络暂未配置收款信息',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Color(0xFFE11D48), size: 20),
              const SizedBox(width: 8),
              Text(
                config.label,
                style: const TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (config.remark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              config.remark,
              style: TextStyle(
                color: const Color(0xFF9F1239).withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // 鏀舵浜岀淮鐮?
          if (config.qrCode.isNotEmpty) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    config.qrCode,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error_outline, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _saveQrCodeToGallery(config.qrCode),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('保存到相册'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 鏀舵鍦板潃
          if (config.address.isNotEmpty) ...[
            const Text(
              '收款地址',
              style: TextStyle(
                color: Color(0xFF881337),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFE11D48).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      config.address,
                      style: const TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyText(config.address, '地址'),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: const Color(0xFFE11D48),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 杞处閲戦鎻愮ず
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFE11D48).withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    const Text(
                      '转账金额',
                      style: TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_usdtAmount.toStringAsFixed(3)} USDT',
                      style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyText(
                        _usdtAmount.toStringAsFixed(3),
                        '金额',
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: const Color(0xFFE11D48),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '请务必转账此金额，小数部分用于识别您的付款',
                  style: TextStyle(
                    color: const Color(0xFF9F1239).withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '付款时请备注好登录账号，方便到账审核',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // USDT 鍏呭€兼椿鍔ㄦ彁绀?
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('馃巵', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USDT 充值活动',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '充值 10U 送 1U，联系客服领取',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWechatAlipayInfo(_PaymentConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            config.label,
            style: const TextStyle(
              color: Color(0xFF881337),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (config.qrCode.isNotEmpty) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    config.qrCode,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error_outline, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _saveQrCodeToGallery(config.qrCode),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('保存到相册'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (config.address.isNotEmpty) ...[
            const Text(
              '收款地址/账号',
              style: TextStyle(
                color: Color(0xFF881337),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFE11D48).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      config.address,
                      style: const TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyText(config.address, '地址'),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: const Color(0xFFE11D48),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '转账金额',
                      style: TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '楼${_paymentAmount.toStringAsFixed(3)}',
                          style: const TextStyle(
                            color: Color(0xFFE11D48),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyText(
                            _paymentAmount.toStringAsFixed(3),
                            '金额',
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          color: const Color(0xFFE11D48),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '请务必转账此金额，小数部分用于识别您的付款',
                  style: TextStyle(
                    color: const Color(0xFF9F1239).withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '付款时请备注好登录账号，方便到账审核',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _autoModeAvailable => _loggedIn;

  bool get _manualModeAvailable => _selectedManualConfig != null;

  _PaymentConfig? get _selectedManualConfig {
    if (_selectedManualChannel == 'usdt') {
      return _currentUsdtConfig;
    }
    if (_selectedManualChannel == 'wechat' && _wechatConfigs.isNotEmpty) {
      return _wechatConfigs.first;
    }
    if (_selectedManualChannel == 'alipay' && _alipayConfigs.isNotEmpty) {
      return _alipayConfigs.first;
    }
    if (_selectedManualChannel == 'qq' && _qqConfigs.isNotEmpty) {
      return _qqConfigs.first;
    }
    return null;
  }

  Widget _buildMobilePaymentFlow() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final headerHeight = constraints.maxHeight * 0.52;
        return Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _buildMobileHeaderCard(),
            ),
            const SizedBox(height: 10),
            _buildModeSegment(),
            const SizedBox(height: 8),
            Expanded(child: _buildModeBody()),
          ],
        );
      },
    );
  }

  Widget _buildMobileHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5B7C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单信息',
            style: TextStyle(
              color: Color(0xFF881337),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow('套餐', widget.planName),
          _buildInfoRow('周期', widget.cycle),
          const SizedBox(height: 12),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '支付金额',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${_paymentAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '≈ ${_usdtAmount.toStringAsFixed(2)} USDT',
                    style: TextStyle(
                      color: const Color(0xFF9F1239).withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegment() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5B7C5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                if (!_autoModeAvailable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('自动识别支付需要登录且有微信/支付宝配置')),
                  );
                  return;
                }
                setState(() => _paymentMode = 'auto');
              },
              style: TextButton.styleFrom(
                backgroundColor: _paymentMode == 'auto'
                    ? const Color(0xFFF9A8D4)
                    : Colors.transparent,
                foregroundColor: _paymentMode == 'auto'
                    ? const Color(0xFF881337)
                    : const Color(0xFF9F1239),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              child: const Text('自动识别'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _paymentMode = 'manual'),
              style: TextButton.styleFrom(
                backgroundColor: _paymentMode == 'manual'
                    ? const Color(0xFFF9A8D4)
                    : Colors.transparent,
                foregroundColor: _paymentMode == 'manual'
                    ? const Color(0xFF881337)
                    : const Color(0xFF9F1239),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.horizontal(right: Radius.circular(12)),
                ),
              ),
              child: const Text('手动支付'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBody() {
    return IndexedStack(
      index: _paymentMode == 'auto' ? 0 : 1,
      children: [
        _buildAutoModeBody(),
        _buildManualModeBody(),
      ],
    );
  }

  Widget _buildAutoModeBody() {
    if (!_loggedIn) {
      return _buildAutoLoginTip();
    }
    if (!_autoModeAvailable) {
      return _buildAutoUnavailableTip();
    }
    final selectedHasConfig = _channelHasAutoConfig(_selectedChannel);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      children: [
        const Text(
          '选择自动渠道',
          style: TextStyle(
            color: Color(0xFF881337),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModePayOption(
                keyValue: 'wechat',
                title: '微信支付',
                asset: 'assets/images/contact/wechat.png',
                enabled: _wechatConfigs.isNotEmpty,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModePayOption(
                keyValue: 'alipay',
                title: '支付宝',
                asset: 'assets/images/contact/alipay.png',
                enabled: _alipayConfigs.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF5B7C5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '操作说明',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _buildOnlinePaymentInfo(),
              const SizedBox(height: 12),
              if (!selectedHasConfig)
                const Text(
                  '当前通道未返回可用配置，请切换其他通道',
                  style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _creatingPayment ? null : _startOnlinePayment,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _creatingPayment
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('发起支付'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _checkAndShowStatus,
                      child: const Text('已支付？'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualModeBody() {
    final usdtNetworks = _usdtConfigs
        .map((item) => item.type.replaceFirst('usdt_', ''))
        .toSet()
        .toList()
      ..sort();
    final manualConfig = _selectedManualConfig;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      children: [
        const Text(
          '手动支付',
          style: TextStyle(
            color: Color(0xFF881337),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildManualChannelCard(
              keyValue: 'wechat',
              title: '微信',
              assetPath: 'assets/images/contact/wechat.png',
              enabled: _wechatConfigs.isNotEmpty,
            ),
            _buildManualChannelCard(
              keyValue: 'alipay',
              title: '支付宝',
              assetPath: 'assets/images/contact/alipay.png',
              enabled: _alipayConfigs.isNotEmpty,
            ),
            _buildManualChannelCard(
              keyValue: 'qq',
              title: 'QQ',
              assetPath: 'assets/images/contact/qq.png',
              enabled: _qqConfigs.isNotEmpty,
            ),
            _buildManualChannelCard(
              keyValue: 'usdt',
              title: 'USDT',
              assetPath: 'assets/images/contact/USDT.png',
              enabled: _usdtConfigs.isNotEmpty,
            ),
          ],
        ),
        if (_selectedManualChannel == 'usdt' && usdtNetworks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'USDT 网络',
            style: TextStyle(
              color: Color(0xFF881337),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final network in usdtNetworks)
                ChoiceChip(
                  label: Text(network.toUpperCase()),
                  selected: _selectedUsdtNetwork == network,
                  onSelected: (_) => setState(() {
                    _selectedUsdtNetwork = network;
                    _selectedManualChannel = 'usdt';
                  }),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFF9A8D4),
                  labelStyle: TextStyle(
                    color: _selectedUsdtNetwork == network
                        ? const Color(0xFF881337)
                        : const Color(0xFF9F1239),
                  ),
                  side: BorderSide(
                    color: _selectedUsdtNetwork == network
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFE7A4B5),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (!_manualModeAvailable)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE7A4B5)),
            ),
            child: const Text(
              '当前选项未配置收款信息，请先联系管理员配置支付数据',
              style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
            ),
          )
        else if (_selectedManualChannel == 'usdt')
          _buildPaymentInfo()
        else if (manualConfig != null)
          _buildWechatAlipayInfo(manualConfig),
      ],
    );
  }

  Widget _buildManualChannelCard({
    required String keyValue,
    required String title,
    required String assetPath,
    required bool enabled,
  }) {
    final isSelected = _selectedManualChannel == keyValue;
    return GestureDetector(
      onTap: () {
        if (!enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 通道未配置')),
          );
          return;
        }
        setState(() => _selectedManualChannel = keyValue);
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF9A8D4).withOpacity(0.8)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFE11D48) : const Color(0xFFF5B7C5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Column(
            children: [
              Image.asset(
                assetPath,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF881337)
                      : const Color(0xFF9F1239),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModePayOption({
    required String keyValue,
    required String title,
    required String asset,
    required bool enabled,
  }) {
    final isSelected = _selectedChannel == keyValue;
    return GestureDetector(
      onTap: () {
        if (!enabled) {
          return;
        }
        setState(() {
          _selectedChannel = keyValue;
          _paymentMode = 'auto';
        });
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF9A8D4) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE11D48)
                  : const Color(0xFFF5B7C5),
            ),
          ),
          child: Row(
            children: [
              Image.asset(asset, width: 34, height: 34),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF881337)
                      : const Color(0xFF9F1239),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoLoginTip() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE7A4B5)),
          ),
          child: const Text(
            '当前未登录：自动支付需登录并有可用配置。请先登录后切到自动支付，或直接使用手动支付。',
            style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoUnavailableTip() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE7A4B5)),
          ),
          child: const Text(
            '当前账号未返回微信/支付宝自动通道，无法自动识别，请切到手动支付。',
            style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePaymentFlowV2() {
    return Column(
      children: [
        _buildMobileReceiptV2(),
        Transform.translate(
          offset: const Offset(0, -22),
          child: _buildPaymentModeSwitchV3(),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -12),
            child: IndexedStack(
              index: _paymentMode == 'auto' ? 0 : 1,
              children: [
                _buildAutoPaymentV3(),
                _buildManualPaymentV3(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileReceiptV2() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF310916), Color(0xFF881337), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x339F1239),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '订单确认',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: Color(0xFFFFD5DF)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        widget.cycle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFD5DF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '应付金额',
                style: TextStyle(
                  color: Color(0xFFFFD5DF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '¥${_paymentAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '≈ ${_usdtAmount.toStringAsFixed(2)} USDT',
                style: const TextStyle(
                  color: Color(0xFFFFD5DF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeSwitchV2() {
    return Container(
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F881337),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPaymentModeButtonV2(
              value: 'auto',
              icon: Icons.auto_awesome_rounded,
              label: '自动识别',
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildPaymentModeButtonV2(
              value: 'manual',
              icon: Icons.qr_code_2_rounded,
              label: '手动支付',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeButtonV2({
    required String value,
    required IconData icon,
    required String label,
  }) {
    final selected = _paymentMode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _paymentMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF881337) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF9F1239),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6F4B57),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoPaymentV2() {
    if (!_loggedIn) {
      return _buildAutoEmptyV2(
        icon: Icons.lock_outline_rounded,
        title: '登录后可自动识别',
        description: '自动支付会绑定当前账号，并在到账后立即开通套餐。',
      );
    }
    if (!_autoModeAvailable) {
      return _buildAutoEmptyV2(
        icon: Icons.route_outlined,
        title: '自动通道暂不可用',
        description: '当前没有可用的微信或支付宝接口，请使用手动支付。',
      );
    }

    final selectedHasConfig = _channelHasAutoConfig(_selectedChannel);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        const Row(
          children: [
            Text(
              '选择支付方式',
              style: TextStyle(
                color: Color(0xFF3F1723),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Spacer(),
            Icon(Icons.verified_user_rounded,
                size: 15, color: Color(0xFF16A05D)),
            SizedBox(width: 4),
            Text(
              '服务端自动核验',
              style: TextStyle(color: Color(0xFF168A50), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAutoChannelV2(
                value: 'wechat',
                label: '微信支付',
                asset: 'assets/images/contact/wechat.png',
                enabled: _wechatConfigs.isNotEmpty,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAutoChannelV2(
                value: 'alipay',
                label: '支付宝',
                asset: 'assets/images/contact/alipay.png',
                enabled: _alipayConfigs.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5DF)),
          ),
          child: Column(
            children: [
              _buildPaymentFlowLineV2(
                icon: Icons.receipt_long_rounded,
                title: '创建订单',
                description: '金额由服务端计算，避免人工核对',
              ),
              _buildPaymentFlowLineV2(
                icon: Icons.open_in_new_rounded,
                title: '前往付款',
                description: '自动打开对应支付应用或收银台',
              ),
              _buildPaymentFlowLineV2(
                icon: Icons.bolt_rounded,
                title: '自动开通',
                description: '到账后自动开通当前账号套餐',
                last: true,
              ),
              const SizedBox(height: 16),
              if (!selectedHasConfig)
                const Text(
                  '当前通道不可用，请切换其他支付方式',
                  style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _creatingPayment
                        ? null
                        : _orderNo == null
                            ? _startOnlinePayment
                            : _checkAndShowStatus,
                    icon: _creatingPayment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_orderNo == null
                            ? Icons.arrow_forward_rounded
                            : Icons.refresh_rounded),
                    label: Text(
                      _orderNo == null ? '确认并前往支付' : '检查订单到账状态',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (_orderNo != null) ...[
                const SizedBox(height: 8),
                Text(
                  '订单号：$_orderNo',
                  style:
                      const TextStyle(color: Color(0xFF8A6872), fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentFlowLineV2({
    required IconData icon,
    required String title,
    required String description,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFE11D48)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF3F1723),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style:
                      const TextStyle(color: Color(0xFF8A6872), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoChannelV2({
    required String value,
    required String label,
    required String asset,
    required bool enabled,
  }) {
    final selected = _selectedChannel == value;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
                _selectedChannel = value;
                _orderNo = null;
              })
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFE4EA) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? const Color(0xFFE11D48) : const Color(0xFFFFD5DF),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Image.asset(asset),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF881337)
                        : const Color(0xFF6F4B57),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFFE11D48)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualPaymentV2() {
    final networks = _usdtConfigs
        .map((item) => item.type.replaceFirst('usdt_', ''))
        .toSet()
        .toList()
      ..sort();
    final manualConfig = _selectedManualConfig;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        const Row(
          children: [
            Text(
              '选择收款渠道',
              style: TextStyle(
                color: Color(0xFF3F1723),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Spacer(),
            Text(
              '扫码或保存二维码',
              style: TextStyle(color: Color(0xFF8A6872), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildManualChannelV2(
                value: 'wechat',
                label: '微信',
                asset: 'assets/images/contact/wechat.png',
                enabled: _wechatConfigs.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildManualChannelV2(
                value: 'alipay',
                label: '支付宝',
                asset: 'assets/images/contact/alipay.png',
                enabled: _alipayConfigs.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildManualChannelV2(
                value: 'qq',
                label: 'QQ',
                asset: 'assets/images/contact/qq.png',
                enabled: _qqConfigs.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildManualChannelV2(
                value: 'usdt',
                label: 'USDT',
                asset: 'assets/images/contact/USDT.png',
                enabled: _usdtConfigs.isNotEmpty,
              ),
            ),
          ],
        ),
        if (_selectedManualChannel == 'usdt' && networks.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            '选择 USDT 网络',
            style: TextStyle(
              color: Color(0xFF3F1723),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final network in networks)
                ChoiceChip(
                  label: Text(network.toUpperCase()),
                  selected: _selectedUsdtNetwork == network,
                  onSelected: (_) => setState(() {
                    _selectedUsdtNetwork = network;
                    _selectedManualChannel = 'usdt';
                  }),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFFFE4EA),
                  side: BorderSide(
                    color: _selectedUsdtNetwork == network
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFFFD5DF),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (!_manualModeAvailable)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD5DF)),
            ),
            child: const Text(
              '当前渠道还没有配置收款信息，请切换其他方式。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
            ),
          )
        else if (_selectedManualChannel == 'usdt')
          _buildPaymentInfo()
        else if (manualConfig != null)
          _buildWechatAlipayInfo(manualConfig),
      ],
    );
  }

  Widget _buildManualChannelV2({
    required String value,
    required String label,
    required String asset,
    required bool enabled,
  }) {
    final selected = _selectedManualChannel == value;
    return GestureDetector(
      onTap: () {
        if (!enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label 通道未配置')),
          );
          return;
        }
        setState(() => _selectedManualChannel = value);
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFE4EA) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFFE11D48) : const Color(0xFFFFD5DF),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Image.asset(asset, width: 30, height: 30, fit: BoxFit.contain),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF881337)
                      : const Color(0xFF6F4B57),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoEmptyV2({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5DF)),
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4EA),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFE11D48), size: 27),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3F1723),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8A6872),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _paymentMode = 'manual'),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('切换到手动支付'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentModeSwitchV3() {
    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD5DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5B7C5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F881337),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(child: _buildModeTabV3('auto', '\u81ea\u52a8\u652f\u4ed8')),
          Expanded(
              child: _buildModeTabV3('manual', '\u624b\u52a8\u652f\u4ed8')),
        ],
      ),
    );
  }

  Widget _buildModeTabV3(String value, String label) {
    final selected = _paymentMode == value;
    return InkWell(
      onTap: () => setState(() => _paymentMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        color: selected ? const Color(0xFF881337) : const Color(0xFFFFD5DF),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF881337),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildAutoPaymentV3() {
    if (!_loggedIn) {
      return _buildAutoEmptyV2(
        icon: Icons.lock_outline_rounded,
        title: '\u767b\u5f55\u540e\u53ef\u81ea\u52a8\u652f\u4ed8',
        description:
            '\u652f\u4ed8\u8ba2\u5355\u5c06\u7ed1\u5b9a\u5f53\u524d\u8d26\u53f7\uff0c\u5230\u8d26\u540e\u81ea\u52a8\u5f00\u901a\u5957\u9910\u3002',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        _buildChannelHeaderV3(
            '\u9009\u62e9\u81ea\u52a8\u652f\u4ed8\u65b9\u5f0f',
            '\u6d4f\u89c8\u5668\u6536\u94f6\u53f0'),
        const SizedBox(height: 12),
        _buildFourChannelsV3(automatic: true),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5DF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\u652f\u4ed8\u6d41\u7a0b',
                style: TextStyle(
                  color: Color(0xFF3F1723),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _buildAutoStepV3('1', '\u521b\u5efa\u5b89\u5168\u8ba2\u5355',
                  '\u670d\u52a1\u7aef\u8ba1\u7b97\u5957\u9910\u91d1\u989d\u5e76\u751f\u6210\u8ba2\u5355'),
              _buildAutoStepV3(
                  '2',
                  '\u6253\u5f00\u6d4f\u89c8\u5668\u6536\u94f6\u53f0',
                  '\u81ea\u52a8\u8df3\u8f6c\u5230\u652f\u4ed8\u5b9d\u3001\u5fae\u4fe1\u6216QQ\u652f\u4ed8'),
              _buildAutoStepV3(
                  '3',
                  '\u56de\u8c03\u786e\u8ba4\u540e\u5230\u8d26',
                  '\u7f51\u5173\u901a\u77e5\u670d\u52a1\u7aef\u540e\u81ea\u52a8\u5f00\u901a\u5957\u9910',
                  last: true),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _creatingPayment
                      ? null
                      : _orderNo == null
                          ? _startOnlinePayment
                          : _checkAndShowStatus,
                  icon: _creatingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.open_in_browser_rounded),
                  label: Text(
                    _orderNo == null
                        ? '\u786e\u8ba4\u5e76\u524d\u5f80\u652f\u4ed8'
                        : '\u68c0\u67e5\u8ba2\u5355\u5230\u8d26\u72b6\u6001',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualPaymentV3() {
    final manualConfig = _selectedManualConfig;
    final networks = _usdtConfigs
        .map((item) => item.type.replaceFirst('usdt_', ''))
        .toSet()
        .toList()
      ..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        _buildChannelHeaderV3(
            '\u9009\u62e9\u624b\u52a8\u6536\u6b3e\u65b9\u5f0f',
            '\u626b\u7801\u6216\u4fdd\u5b58\u4e8c\u7ef4\u7801'),
        const SizedBox(height: 12),
        _buildFourChannelsV3(automatic: false),
        if (_selectedManualChannel == 'usdt' && networks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final network in networks)
                ChoiceChip(
                  label: Text(network.toUpperCase()),
                  selected: _selectedUsdtNetwork == network,
                  onSelected: (_) =>
                      setState(() => _selectedUsdtNetwork = network),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFFFD5DF),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (!_manualModeAvailable)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD5DF)),
            ),
            child: const Text(
              '\u5f53\u524d\u6e20\u9053\u8fd8\u6ca1\u6709\u914d\u7f6e\u6536\u6b3e\u4fe1\u606f',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9F1239)),
            ),
          )
        else if (_selectedManualChannel == 'usdt')
          _buildPaymentInfo()
        else if (manualConfig != null)
          _buildWechatAlipayInfo(manualConfig),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _manualModeAvailable ? _confirmManualPaymentV3 : null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              '\u6211\u5df2\u652f\u4ed8\u5b8c\u6bd5',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelHeaderV3(String title, String hint) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3F1723),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(hint,
            style: const TextStyle(color: Color(0xFF8A6872), fontSize: 11)),
      ],
    );
  }

  Widget _buildFourChannelsV3({required bool automatic}) {
    return Row(
      children: [
        Expanded(
            child: _buildChannelItemV3('wechat', '\u5fae\u4fe1',
                'assets/images/contact/wechat.png', automatic)),
        const SizedBox(width: 7),
        Expanded(
            child: _buildChannelItemV3('alipay', '\u652f\u4ed8\u5b9d',
                'assets/images/contact/alipay.png', automatic)),
        const SizedBox(width: 7),
        Expanded(
            child: _buildChannelItemV3(
                'qq', 'QQ', 'assets/images/contact/qq.png', automatic)),
        const SizedBox(width: 7),
        Expanded(
            child: _buildChannelItemV3(
                'usdt', 'USDT', 'assets/images/contact/USDT.png', automatic)),
      ],
    );
  }

  Widget _buildChannelItemV3(
    String value,
    String label,
    String asset,
    bool automatic,
  ) {
    final selected =
        automatic ? _selectedChannel == value : _selectedManualChannel == value;
    final enabled = switch (value) {
      'alipay' => automatic || _alipayConfigs.isNotEmpty,
      'wechat' => automatic || _wechatConfigs.isNotEmpty,
      'qq' => automatic || _qqConfigs.isNotEmpty,
      _ => _usdtConfigs.isNotEmpty,
    };
    return GestureDetector(
      onTap: () {
        if (!enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label \u901a\u9053\u672a\u914d\u7f6e')),
          );
          return;
        }
        if (automatic && value == 'usdt') {
          setState(() {
            _paymentMode = 'manual';
            _selectedManualChannel = 'usdt';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'USDT \u9700\u8981\u4f7f\u7528\u94fe\u4e0a\u8f6c\u8d26\u6d41\u7a0b')),
          );
          return;
        }
        setState(() {
          if (automatic) {
            _selectedChannel = value;
            _orderNo = null;
          } else {
            _selectedManualChannel = value;
          }
        });
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFD5DF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFFE11D48) : const Color(0xFFF5B7C5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Image.asset(asset, width: 30, height: 30, fit: BoxFit.contain),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF881337)
                      : const Color(0xFF6F4B57),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoStepV3(
    String number,
    String title,
    String description, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFFFD5DF),
            child: Text(number,
                style: const TextStyle(
                    color: Color(0xFF881337), fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF3F1723),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text(description,
                    style: const TextStyle(
                        color: Color(0xFF8A6872), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmManualPaymentV3() async {
    final config = _selectedManualConfig;
    final qrUrl = config?.qrCode ?? '';
    final saved = qrUrl.isNotEmpty && _savedManualQrUrls.contains(qrUrl);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(saved
            ? '\u5df2\u68c0\u6d4b\u5230\u4e8c\u7ef4\u7801\u4fdd\u5b58\u8bb0\u5f55'
            : '\u672a\u68c0\u6d4b\u5230\u4e8c\u7ef4\u7801\u4fdd\u5b58\u8bb0\u5f55'),
        content: Text(saved
            ? '\u8bf7\u786e\u4fdd\u5df2\u5b8c\u6210\u5b9e\u9645\u8f6c\u8d26\u3002\u624b\u52a8\u6536\u6b3e\u9700\u8981\u53ef\u9a8c\u8bc1\u7684\u5230\u8d26\u7ed3\u679c\uff0c\u4e0d\u80fd\u4ec5\u51ed\u4e0b\u8f7d\u56fe\u7247\u5f00\u901a\u5957\u9910\u3002'
            : '\u8bf7\u5148\u4fdd\u5b58\u5f53\u524d\u6536\u6b3e\u4e8c\u7ef4\u7801\u5e76\u5b8c\u6210\u4ed8\u6b3e\uff0c\u6216\u8054\u7cfb\u5ba2\u670d\u6838\u5b9e\u3002'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openContact();
            },
            child: const Text('\u8054\u7cfb\u5ba2\u670d\u6838\u5b9e'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentFlowV4() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                _buildMobileReceiptV4(),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: _buildPaymentModeSwitchV4(),
                ),
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _paymentMode == 'auto'
                        ? _buildAutoContentV4()
                        : _buildManualContentV4(),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildPaymentBottomActionV4(),
      ],
    );
  }

  Widget _buildMobileReceiptV4() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF310916), Color(0xFF881337), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u8ba2\u5355\u786e\u8ba4',
                    style: TextStyle(
                        color: Color(0xFFFFD5DF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 11),
                Text(widget.planName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(widget.cycle,
                    style: const TextStyle(
                        color: Color(0xFFFFD5DF), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('\u5e94\u4ed8\u91d1\u989d',
                  style: TextStyle(color: Color(0xFFFFD5DF), fontSize: 11)),
              const SizedBox(height: 3),
              Text('¥${_paymentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeSwitchV4() {
    return Container(
      width: double.infinity,
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F881337),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildModeTabV4(
              'auto',
              '\u81ea\u52a8\u652f\u4ed8',
              '\u81ea\u52a8\u5230\u8d26',
              Icons.bolt_rounded,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildModeTabV4(
              'manual',
              '\u624b\u52a8\u652f\u4ed8',
              '\u626b\u7801\u8f6c\u8d26',
              Icons.qr_code_2_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabV4(
    String value,
    String label,
    String description,
    IconData icon,
  ) {
    final selected = _paymentMode == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _paymentMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : const Color(0xFFFFF8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : const Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFF3F1723),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFFFD5DF)
                            : const Color(0xFF9F6A78),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoContentV4() {
    if (!_loggedIn) {
      return _buildInlineNoticeV4(Icons.lock_outline_rounded,
          '\u8bf7\u5148\u767b\u5f55\u8d26\u53f7\u518d\u4f7f\u7528\u81ea\u52a8\u652f\u4ed8');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChannelHeaderV3('\u9009\u62e9\u652f\u4ed8\u65b9\u5f0f', ''),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildChannelItemV3('wechat', '\u5fae\u4fe1',
                    'assets/images/contact/wechat.png', true)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildChannelItemV3('alipay', '\u652f\u4ed8\u5b9d',
                    'assets/images/contact/alipay.png', true)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildChannelItemV3(
                    'qq', 'QQ', 'assets/images/contact/qq.png', true)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5DF)),
          ),
          child: Column(
            children: [
              _buildAutoStepV3('1', '\u521b\u5efa\u652f\u4ed8\u8ba2\u5355',
                  '\u670d\u52a1\u7aef\u786e\u8ba4\u5957\u9910\u548c\u91d1\u989d'),
              _buildAutoStepV3(
                  '2',
                  '\u6253\u5f00\u6d4f\u89c8\u5668\u6536\u94f6\u53f0',
                  '\u6309\u9009\u62e9\u7684\u6e20\u9053\u5b8c\u6210\u4ed8\u6b3e'),
              _buildAutoStepV3(
                  '3',
                  '\u652f\u4ed8\u56de\u8c03\u81ea\u52a8\u5f00\u901a',
                  '\u5230\u8d26\u540e\u5957\u9910\u81ea\u52a8\u66f4\u65b0',
                  last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualContentV4() {
    final config = _selectedManualConfig;
    final networks = _usdtConfigs
        .map((item) => item.type.replaceFirst('usdt_', ''))
        .toSet()
        .toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChannelHeaderV3('\u9009\u62e9\u6536\u6b3e\u65b9\u5f0f',
            '\u626b\u7801\u6216\u4fdd\u5b58\u4e8c\u7ef4\u7801'),
        const SizedBox(height: 12),
        _buildFourChannelsV3(automatic: false),
        if (_selectedManualChannel == 'usdt' && networks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final network in networks)
                ChoiceChip(
                  label: Text(network.toUpperCase()),
                  selected: _selectedUsdtNetwork == network,
                  onSelected: (_) =>
                      setState(() => _selectedUsdtNetwork = network),
                  selectedColor: const Color(0xFFFFD5DF),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (!_manualModeAvailable)
          _buildInlineNoticeV4(Icons.info_outline_rounded,
              '\u5f53\u524d\u6e20\u9053\u672a\u914d\u7f6e\u6536\u6b3e\u4fe1\u606f')
        else if (config != null)
          _buildManualQrCardV4(config),
      ],
    );
  }

  Widget _buildManualQrCardV4(_PaymentConfig config) {
    final isUsdt = _selectedManualChannel == 'usdt';
    final amount = isUsdt
        ? '${_usdtAmount.toStringAsFixed(3)} USDT'
        : '¥${_paymentAmount.toStringAsFixed(2)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD5DF)),
      ),
      child: Column(
        children: [
          Text(config.label,
              style: const TextStyle(
                  color: Color(0xFF3F1723),
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          if (config.qrCode.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(config.qrCode,
                  width: 210,
                  height: 210,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      width: 210,
                      height: 210,
                      child: Icon(Icons.broken_image_outlined, size: 50))),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _saveQrCodeToGallery(config.qrCode),
              icon: const Icon(Icons.download_rounded),
              label: const Text('\u4fdd\u5b58\u4e8c\u7ef4\u7801'),
            ),
          ],
          if (config.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: Text(config.address,
                        style: const TextStyle(
                            color: Color(0xFF6F4B57), fontSize: 12))),
                IconButton(
                  onPressed: () =>
                      _copyText(config.address, '\u6536\u6b3e\u5730\u5740'),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Text('\u8f6c\u8d26\u91d1\u989d',
                  style: TextStyle(color: Color(0xFF6F4B57), fontSize: 13)),
              const Spacer(),
              Text(amount,
                  style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          if (isUsdt) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD5DF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFE11D48),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u5145\u503c\u5956\u52b1',
                          style: TextStyle(
                            color: Color(0xFF881337),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '\u6bcf\u5145\u503c 10 USDT \u8d60\u9001 1 USDT\uff0c\u53ef\u7d2f\u8ba1',
                          style: TextStyle(
                            color: Color(0xFF6F4B57),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\u4f8b\u5982\uff1a\u5145\u503c 20 USDT\uff0c\u5b9e\u9645\u5230\u8d26 22 USDT',
                          style: TextStyle(
                            color: Color(0xFF9F6A78),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineNoticeV4(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD5DF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE11D48)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: Color(0xFF6F4B57), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPaymentBottomActionV4() {
    final automatic = _paymentMode == 'auto';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A881337), blurRadius: 18, offset: Offset(0, -5)),
        ],
      ),
      child: SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: automatic
              ? (!_loggedIn || _creatingPayment
                  ? null
                  : _orderNo == null
                      ? _handleAutoPaymentAction
                      : _checkAndShowStatus)
              : (_manualModeAvailable ? _confirmManualPaymentV4 : null),
          icon: _creatingPayment && automatic
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Icon(automatic
                  ? Icons.open_in_browser_rounded
                  : Icons.check_circle_outline_rounded),
          label: Text(
            automatic
                ? (_orderNo == null
                    ? '确认并前往支付'
                    : '检查订单到账状态')
                : '我已支付完毕',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmManualPaymentV4() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('再次确认'),
            content: const Text(
                '确认后将立即开通套餐时长与流量，管理员会核实您的付款情况。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认已支付'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final result = await _notifyPaymentConfirmed();
    await _finishPaymentActivation(result);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF881337),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePaymentStep extends StatelessWidget {
  const _OnlinePaymentStep({
    required this.number,
    required this.title,
    required this.description,
    this.last = false,
  });

  final String number;
  final String title;
  final String description;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFFF2D8DF),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF4A202C),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF92727B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentConfig {
  const _PaymentConfig({
    required this.id,
    required this.type,
    required this.label,
    required this.address,
    required this.qrCode,
    required this.remark,
  });

  final int id;
  final String type;
  final String label;
  final String address;
  final String qrCode;
  final String remark;

  factory _PaymentConfig.fromJson(Map<String, dynamic> json) {
    return _PaymentConfig(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }

  factory _PaymentConfig.empty() {
    return const _PaymentConfig(
      id: 0,
      type: '',
      label: '',
      address: '',
      qrCode: '',
      remark: '',
    );
  }
}
