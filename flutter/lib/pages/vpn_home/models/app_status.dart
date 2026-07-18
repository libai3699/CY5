class AppStatus {
  const AppStatus({
    required this.hasPlan,
    required this.planLevel,
    required this.remainingSeconds,
    required this.remainingTimeText,
    required this.trafficRemaining,
  });

  final bool hasPlan;
  final String planLevel;
  final int remainingSeconds;
  final String remainingTimeText;
  final String trafficRemaining;

  factory AppStatus.fromJson(Map<String, dynamic> json) {
    final hasPlanRaw = json['has_plan'];
    final hasPlan = hasPlanRaw is bool
        ? hasPlanRaw
        : (int.tryParse(hasPlanRaw?.toString() ?? '') == 1);
    final planLevel = json['plan_level']?.toString() ?? '免费体验';
    return AppStatus(
      hasPlan: hasPlan || planLevel == '付费套餐',
      planLevel: planLevel,
      remainingSeconds:
          int.tryParse(json['remaining_seconds']?.toString() ?? '') ?? 0,
      remainingTimeText:
          json['remaining_time_text']?.toString() ?? '已到期',
      trafficRemaining: json['traffic_remaining']?.toString() ?? '0 GB',
    );
  }
}
