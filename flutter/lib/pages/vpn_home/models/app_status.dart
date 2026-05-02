class AppStatus {
  const AppStatus({
    required this.planLevel,
    required this.remainingSeconds,
    required this.remainingTimeText,
    required this.trafficRemaining,
  });

  final String planLevel;
  final int remainingSeconds;
  final String remainingTimeText;
  final String trafficRemaining;

  factory AppStatus.fromJson(Map<String, dynamic> json) {
    return AppStatus(
      planLevel: json['plan_level']?.toString() ?? '免费体验',
      remainingSeconds: int.tryParse(json['remaining_seconds']?.toString() ?? '') ?? 0,
      remainingTimeText: json['remaining_time_text']?.toString() ?? '未知',
      trafficRemaining: json['traffic_remaining']?.toString() ?? '1024.00 GB',
    );
  }
}
