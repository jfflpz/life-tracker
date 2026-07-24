class MonthlySummary {
  final int version;
  final int year;
  final int month;
  final SummaryStats summary;
  final List<ActiveDay> activeDays;

  MonthlySummary({
    required this.version,
    required this.year,
    required this.month,
    required this.summary,
    required this.activeDays,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      version: json['version'] as int? ?? 1,
      year: json['year'] as int,
      month: json['month'] as int,
      summary: SummaryStats.fromJson(json['summary'] as Map<String, dynamic>),
      activeDays: (json['active_days'] as List<dynamic>?)
              ?.map((e) => ActiveDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SummaryStats {
  final int activeDaysCount;
  final int totalPoints;
  final double totalDistanceM;
  final double averageDailyDistanceM;
  final int movingTimeSec;
  final int stationaryTimeSec;

  SummaryStats({
    required this.activeDaysCount,
    required this.totalPoints,
    required this.totalDistanceM,
    required this.averageDailyDistanceM,
    required this.movingTimeSec,
    required this.stationaryTimeSec,
  });

  factory SummaryStats.fromJson(Map<String, dynamic> json) {
    return SummaryStats(
      activeDaysCount: json['active_days_count'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      totalDistanceM: (json['total_distance_m'] as num?)?.toDouble() ?? 0.0,
      averageDailyDistanceM: (json['average_daily_distance_m'] as num?)?.toDouble() ?? 0.0,
      movingTimeSec: json['moving_time_sec'] as int? ?? 0,
      stationaryTimeSec: json['stationary_time_sec'] as int? ?? 0,
    );
  }
}

class ActiveDay {
  final String date; // YYYY-MM-DD
  final int dayOfWeek; // 1=Mon, 7=Sun
  final int pointCount;
  final double distanceM;
  final bool hasRoute;
  final bool hasTimeline;
  final int movingTimeSec;
  final int stationaryTimeSec;

  ActiveDay({
    required this.date,
    required this.dayOfWeek,
    required this.pointCount,
    required this.distanceM,
    required this.hasRoute,
    required this.hasTimeline,
    required this.movingTimeSec,
    required this.stationaryTimeSec,
  });

  factory ActiveDay.fromJson(Map<String, dynamic> json) {
    return ActiveDay(
      date: json['date'] as String,
      dayOfWeek: json['day_of_week'] as int? ?? 1,
      pointCount: json['point_count'] as int? ?? 0,
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
      hasRoute: json['has_route'] as bool? ?? false,
      hasTimeline: json['has_timeline'] as bool? ?? false,
      movingTimeSec: json['moving_time_sec'] as int? ?? 0,
      stationaryTimeSec: json['stationary_time_sec'] as int? ?? 0,
    );
  }
}
