import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/platform_utils.dart';
import 'components/common_page_top_bar.dart';
import 'contact_page.dart';
import 'data/api_config.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.planName,
    required this.totalPrice,
    required this.cycle,
  });

  final String planName;
  final double totalPrice;
  final String cycle;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<_PaymentMethod> _methods = [];
  bool _loading = true;
  String? _error;
  int? _selectedId;
  double _usdtRate = 6.9; // 默认汇率，加载后替换

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
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
        setState(() => _usdtRate = cny);
      }
    } catch (_) {
      // 静默失败，用默认 7.2
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadPaymentMethods() async {
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
        final methods = list
            .whereType<Map<String, dynamic>>()
            .map(_PaymentMethod.fromJson)
            .toList();
        if (mounted) {
          setState(() {
            _methods = methods;
            _selectedId = methods.isNotEmpty ? methods.first.id : null;
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

  void _openContact() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ContactPage(),
    ));
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('地址已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQRCode(String label, String qrCodeUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF881337),
                ),
              ),
              const SizedBox(height: 16),
              Image.network(
                qrCodeUrl,
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 250,
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(Icons.error_outline, size: 48),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPay() {
    final selected = _methods.firstWhere(
      (m) => m.id == _selectedId,
      orElse: () => _methods.first,
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('支付提示'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套餐：${widget.planName}'),
            Text('周期：${widget.cycle}'),
            Text('金额：¥${widget.totalPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Text('支付方式：${selected.label}'),
            const SizedBox(height: 12),
            const Text(
              '请完成支付后联系客服确认订单',
              style: TextStyle(color: Color(0xFFE11D48), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openContact();
            },
            child: const Text('联系客服'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: PlatformUtils.getContentMaxWidth() ?? double.infinity,
            ),
            child: Column(
              children: [
                const CommonPageTopBar(
                  title: '选择支付方式',
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
              onPressed: _loadPaymentMethods,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (_methods.isEmpty) {
      return const Center(
        child: Text(
          '暂无可用支付方式',
          style: TextStyle(color: Color(0xFF9F1239)),
        ),
      );
    }

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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '¥${widget.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFE11D48),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '≈ ${(widget.totalPrice / _usdtRate).toStringAsFixed(2)} USDT',
                            style: TextStyle(
                              color: const Color(0xFF9F1239).withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '实时汇率 1 USDT = ¥${_usdtRate.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: const Color(0xFF9F1239).withOpacity(0.45),
                          fontSize: 11,
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
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            itemCount: _methods.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // 最后一项是提示区块
              if (index == _methods.length) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE11D48).withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_rounded,
                              size: 15,
                              color: const Color(0xFFE11D48).withOpacity(0.8)),
                          const SizedBox(width: 6),
                          const Text(
                            '温馨提示',
                            style: TextStyle(
                              color: Color(0xFF881337),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildTip('🎁', '充值 10U 送 1U，活动长期有效'),
                      _buildTip('⚡', '推荐使用 BEP20 链转账，手续费最低'),
                      _buildTip('🔒', '转账前请核对地址，区块链转账不可撤销'),
                      _buildTip('📋', '完成支付后截图发给客服，人工审核后秒开通'),
                      _buildTip('💬', '如有疑问请联系客服，7×24 小时在线'),
                    ],
                  ),
                );
              }
              final method = _methods[index];
              final isSelected = method.id == _selectedId;
              return GestureDetector(
                onTap: () => setState(() => _selectedId = method.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE11D48).withOpacity(0.07)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE11D48)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFFCCCCCC),
                                width: 2,
                              ),
                              color: isSelected
                                  ? const Color(0xFFE11D48)
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              method.label,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF881337),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (method.address.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                method.address,
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyAddress(method.address),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              color: const Color(0xFFE11D48),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                      if (method.qrCode.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _showQRCode(method.label, method.qrCode),
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('查看二维码'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE11D48),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      if (method.remark.isNotEmpty && method.address.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          method.remark,
                          style: TextStyle(
                            color: const Color(0xFF9F1239).withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedId == null ? null : _onPay,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '确认支付',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openContact,
                child: const Text(
                  '遇到问题？联系客服',
                  style: TextStyle(color: Color(0xFF9F1239), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF9F1239).withOpacity(0.85),
                fontSize: 12,
                height: 1.5,
              ),
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

class _PaymentMethod {
  const _PaymentMethod({
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

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) {
    return _PaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }
}
