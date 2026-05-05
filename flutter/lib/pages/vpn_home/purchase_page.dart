import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'components/common_page_top_bar.dart';
import 'contact_page.dart';
import 'data/api_config.dart';
import 'data/device_identity.dart';
import 'payment_page.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key, this.userId, this.username});

  final int? userId;
  final String? username;

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  List<_Plan> _plans = [];
  bool _loading = true;
  String? _error;
  int? _selectedId;
  _BillingCycle _cycle = _BillingCycle.month;
  final _enterTime = DateTime.now();
  String _deviceId = '';
  String _displayId = '';

  _Plan? get _selectedPlan {
    for (final plan in _plans) {
      if (plan.id == _selectedId) return plan;
    }
    return _plans.isEmpty ? null : _plans.first;
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _initDevice();
    _track('enter');
  }

  @override
  void dispose() {
    final stayMs = DateTime.now().difference(_enterTime).inMilliseconds;
    _track('leave', stayMs: stayMs);
    super.dispose();
  }

  Future<void> _initDevice() async {
    try {
      final identity = const DeviceIdentity();
      _deviceId = await identity.getOrCreateDeviceId();
      _displayId = await identity.getDisplayId();
    } catch (_) {}
  }

  Future<void> _track(String event, {int stayMs = 0, String? planName, double? planPrice, String? cycle}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse(kTrackEventUrl)).timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'page': 'purchase',
        'event': event,
        'device_id': _deviceId,
        'display_id': _displayId,
        'plan_name': planName ?? _selectedPlan?.name ?? '',
        'plan_price': planPrice ?? _selectedPlan?.price ?? 0,
        'cycle': cycle ?? _cycle.label,
        'stay_ms': stayMs,
      }));
      final resp = await req.close().timeout(const Duration(seconds: 5));
      await resp.drain<void>();
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(kPlansApiUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败：${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      final list = decoded?['data'];
      if (list is List) {
        final plans = list
            .whereType<Map<String, dynamic>>()
            .map(_Plan.fromJson)
            .toList();
        if (mounted) {
          setState(() {
            _plans = plans;
            _selectedId = plans.isNotEmpty ? plans.first.id : null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: Column(
          children: [
            const CommonPageTopBar(
              title: '购买套餐',
              showRightButton: false,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadPlans,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_plans.isEmpty) {
      return const Center(
        child: Text('暂无可购套餐', style: TextStyle(color: Color(0xFF9F1239))),
      );
    }

    final selected = _selectedPlan;
    final total = selected?.totalFor(_cycle) ?? 0;
    final original = selected?.originalFor(_cycle) ?? 0;
    final discount = selected?.discountFor(_cycle) ?? 1;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            itemCount: _plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plan = _plans[index];
              final isSelected = plan.id == _selectedId;
              return GestureDetector(
                onTap: () => setState(() => _selectedId = plan.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE11D48).withOpacity(0.07)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFFE11D48) : const Color(0xFFCCCCCC),
                            width: 2,
                          ),
                          color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF881337),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${plan.durationDays} 天 · ${plan.trafficText}',
                              style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '¥${plan.price.toStringAsFixed(2)}/月',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF881337),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
              _CycleTabs(
                selected: _cycle,
                onChanged: (cycle) => setState(() => _cycle = cycle),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_cycle.label}总价',
                            style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            discount < 1 ? '${(discount * 10).toStringAsFixed(1)}折优惠' : '月付原价',
                            style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (original > total) ...[
                      Text(
                        '¥${original.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF9F1239),
                          decoration: TextDecoration.lineThrough,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '¥${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF881337), fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedId == null ? null : _onBuy,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('立即购买', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openContact,
                child: const Text('遇到问题？联系客服', style: TextStyle(color: Color(0xFF9F1239), fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onBuy() {
    final selected = _selectedPlan;
    if (selected == null) return;

    final total = selected.totalFor(_cycle);
    // 埋点：点击购买
    _track('click_buy', planName: selected.name, planPrice: selected.price, cycle: _cycle.label);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentPage(
          planName: selected.name,
          totalPrice: total,
          cycle: _cycle.label,
        ),
      ),
    );
  }
}

class _CycleTabs extends StatelessWidget {
  const _CycleTabs({required this.selected, required this.onChanged});

  final _BillingCycle selected;
  final ValueChanged<_BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: _BillingCycle.values.map((cycle) {
          final active = cycle == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(cycle),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE11D48) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cycle.label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF881337),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _BillingCycle {
  month('月付', 1),
  quarter('季付', 3),
  halfYear('半年付', 6),
  year('年付', 12);

  const _BillingCycle(this.label, this.months);

  final String label;
  final int months;
}

class _Plan {
  const _Plan({
    required this.discountHalfYear,
    required this.discountQuarter,
    required this.discountYear,
    required this.durationDays,
    required this.id,
    required this.name,
    required this.price,
    required this.trafficGb,
  });

  final double? discountHalfYear;
  final double? discountQuarter;
  final double? discountYear;
  final int durationDays;
  final int id;
  final String name;
  final double price;
  final int? trafficGb;

  String get trafficText => trafficGb == null ? '不限流量' : '$trafficGb GB';

  double discountFor(_BillingCycle cycle) {
    return switch (cycle) {
      _BillingCycle.month => 1,
      _BillingCycle.quarter => discountQuarter ?? 1,
      _BillingCycle.halfYear => discountHalfYear ?? 1,
      _BillingCycle.year => discountYear ?? 1,
    };
  }

  double originalFor(_BillingCycle cycle) => price * cycle.months;

  double totalFor(_BillingCycle cycle) => originalFor(cycle) * discountFor(cycle);

  factory _Plan.fromJson(Map<String, dynamic> json) {
    return _Plan(
      discountHalfYear: (json['discount_half_year'] as num?)?.toDouble(),
      discountQuarter: (json['discount_quarter'] as num?)?.toDouble(),
      discountYear: (json['discount_year'] as num?)?.toDouble(),
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      trafficGb: json['traffic_gb'] == null ? null : (json['traffic_gb'] as num?)?.toInt(),
    );
  }
}
