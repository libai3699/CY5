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
  String _selectedChannel = 'usdt'; // usdt, wechat, alipay
  String _selectedUsdtNetwork = 'bep20'; // trc20, bep20, erc20

  List<_PaymentConfig> _usdtConfigs = [];
  List<_PaymentConfig> _wechatConfigs = [];
  List<_PaymentConfig> _alipayConfigs = [];

  bool _loading = true;
  String? _error;
  double _usdtRate = 7.2;
  String? _orderNo;
  bool _creatingPayment = false;

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
    if (_selectedChannel != 'alipay' && _selectedChannel != 'wechat') {
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
        'pay_type': _selectedChannel == 'wechat' ? 'wxpay' : 'alipay',
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
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
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('保存失败：$error'),
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
            title: const Text('保存到相册'),
            content: const Text('二维码将保存到系统相册。首次保存时，旧版 Android 可能会请求存储权限。'),
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

  String? get _selectedPreviewImageUrl => _selectedPreviewConfig?.qrCode;

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

    return Column(
      children: [
        // 订单信息卡片
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
                '订单信息',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('套餐', widget.planName),
              _buildInfoRow('周期', widget.cycle),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '应付金额',
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
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '≈ ${_usdtAmount.toStringAsFixed(2)} USDT',
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '金额含随机小数，用于识别您的付款',
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.5),
                          fontSize: 10,
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
                ],
              ),
            ],
          ),
        ),

        // 支付方式选择
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            children: [
              const Text(
                '选择支付方式',
                style: TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // 三个支付方式横向排列
              Row(
                children: [
                  Expanded(
                    child: _buildChannelCard(
                      'usdt',
                      'USDT',
                      'assets/images/contact/USDT.png',
                      _usdtConfigs.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'wechat',
                      '微信支付',
                      'assets/images/contact/wechat.png',
                      _wechatConfigs.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'alipay',
                      '支付宝',
                      'assets/images/contact/alipay.png',
                      _alipayConfigs.isNotEmpty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // USDT 网络选择和收款信息
              if (_selectedChannel == 'usdt' && _usdtConfigs.isNotEmpty) ...[
                const Text(
                  '选择网络',
                  style: TextStyle(
                    color: Color(0xFF881337),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildNetworkChip('trc20', 'TRC20'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNetworkChip('bep20', 'BEP20'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNetworkChip('erc20', 'ERC20'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPaymentInfo(),
              ],

              // 微信/支付宝收款信息
              if (_selectedChannel == 'wechat' && _wechatConfigs.isNotEmpty)
                _buildWechatAlipayInfo(_wechatConfigs.first),

              if (_selectedChannel == 'alipay' && _alipayConfigs.isNotEmpty)
                _buildWechatAlipayInfo(_alipayConfigs.first),
            ],
          ),
        ),

        // 底部按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _creatingPayment
                      ? null
                      : (_selectedChannel == 'usdt'
                          ? _openContact
                          : _orderNo == null
                              ? _startOnlinePayment
                              : _checkAndShowStatus),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _creatingPayment
                        ? '正在创建订单...'
                        : _selectedChannel == 'usdt'
                            ? '完成支付后联系客服'
                            : _orderNo == null
                                ? '前往在线支付'
                                : '检查订单状态',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsBody() {
    return PaymentPageWindowsLayout(
      leftContent: _buildWindowsLeftContentClean(),
      previewTitle: _selectedPreviewTitleClean,
      previewImageUrl: _selectedPreviewImageUrl,
      onActionPressed: _creatingPayment
          ? null
          : (_selectedChannel == 'usdt'
              ? _openContact
              : _orderNo == null
                  ? _startOnlinePayment
                  : _checkAndShowStatus),
      actionLabel: _creatingPayment
          ? '正在创建订单...'
          : _selectedChannel == 'usdt'
              ? '完成支付后联系客服'
              : _orderNo == null
                  ? '前往在线支付'
                  : '检查订单状态',
      onlinePayment: _selectedChannel != 'usdt',
    );
  }

  String get _selectedPreviewTitleClean {
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
                      Text(
                        '~ ${_usdtAmount.toStringAsFixed(2)} USDT',
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '\u91d1\u989d\u542b\u968f\u673a\u5c0f\u6570\uff0c\u7528\u4e8e\u8bc6\u522b\u60a8\u7684\u4ed8\u6b3e',
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '\u4ed8\u6b3e\u65f6\u8bf7\u5907\u6ce8\u597d\u767b\u5f55\u8d26\u53f7\uff0c\u65b9\u4fbf\u5230\u8d26\u5ba1\u6838',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
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
                      'usdt',
                      'USDT',
                      'assets/images/contact/USDT.png',
                      _usdtConfigs.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'wechat',
                      '\u5fae\u4fe1\u652f\u4ed8',
                      'assets/images/contact/wechat.png',
                      _wechatConfigs.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChannelCard(
                      'alipay',
                      '\u652f\u4ed8\u5b9d',
                      'assets/images/contact/alipay.png',
                      _alipayConfigs.isNotEmpty,
                    ),
                  ),
                ],
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
              if (_selectedChannel == 'wechat' && _wechatConfigs.isNotEmpty)
                _buildWechatAlipayInfo(_wechatConfigs.first),
              if (_selectedChannel == 'alipay' && _alipayConfigs.isNotEmpty)
                _buildWechatAlipayInfo(_alipayConfigs.first),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsLeftContent() {
    return _buildWindowsLeftContentClean();
  }

  Widget _buildChannelCard(
      String value, String label, String iconAsset, bool enabled) {
    final isSelected = _selectedChannel == value;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedChannel = value) : null,
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

          // 收款二维码
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

          // 收款地址
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

          // 转账金额提示
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
          // USDT 充值活动提示
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
                const Text('🎁', style: TextStyle(fontSize: 22)),
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
                          '¥${_paymentAmount.toStringAsFixed(3)}',
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
