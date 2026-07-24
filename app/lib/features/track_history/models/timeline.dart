class TimelineMetadata {
  final int version;
  final String date;
  final DateTime generatedAt;
  final int pointCount;

  TimelineMetadata({
    required this.version,
    required this.date,
    required this.generatedAt,
    required this.pointCount,
  });

  factory TimelineMetadata.fromJson(Map<String, dynamic> json) {
    return TimelineMetadata(
      version: json['version'] as int? ?? 1,
      date: json['date'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      pointCount: json['point_count'] as int,
    );
  }
}

class TimelineSummary {
  final double totalDistanceM;
  final int movingTimeSec;
  final int stationaryTimeSec;

  TimelineSummary({
    required this.totalDistanceM,
    required this.movingTimeSec,
    required this.stationaryTimeSec,
  });

  factory TimelineSummary.fromJson(Map<String, dynamic> json) {
    return TimelineSummary(
      totalDistanceM: (json['total_distance_m'] as num).toDouble(),
      movingTimeSec: json['moving_time_sec'] as int,
      stationaryTimeSec: json['stationary_time_sec'] as int,
    );
  }
}

class TimelineEvent {
  final String id;
  final String type; // 'stop' or 'moving'
  final DateTime startTime;
  final DateTime endTime;
  final int durationSec;

  // Stop-specific
  final String? locationName;
  final String? pinId;
  final double? lat;
  final double? lon;

  // Moving-specific
  final double? distanceM;
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;

  TimelineEvent({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.durationSec,
    this.locationName,
    this.pinId,
    this.lat,
    this.lon,
    this.distanceM,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      durationSec: json['duration_sec'] as int,
      locationName: json['location_name'] as String?,
      pinId: json['pin_id'] as String?,
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lon: json['lon'] != null ? (json['lon'] as num).toDouble() : null,
      distanceM: json['distance_m'] != null ? (json['distance_m'] as num).toDouble() : null,
      startLat: json['start_lat'] != null ? (json['start_lat'] as num).toDouble() : null,
      startLon: json['start_lon'] != null ? (json['start_lon'] as num).toDouble() : null,
      endLat: json['end_lat'] != null ? (json['end_lat'] as num).toDouble() : null,
      endLon: json['end_lon'] != null ? (json['end_lon'] as num).toDouble() : null,
    );
  }

  bool get isStop => type == 'stop';
  bool get isMoving => type == 'moving';
}

class TimelineResponse {
  final TimelineMetadata metadata;
  final TimelineSummary summary;
  final List<TimelineEvent> events;

  TimelineResponse({
    required this.metadata,
    required this.summary,
    required this.events,
  });

  factory TimelineResponse.fromJson(Map<String, dynamic> json) {
    var eventsList = json['events'] as List;
    List<TimelineEvent> parsedEvents = eventsList
        .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    return TimelineResponse(
      metadata: TimelineMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      summary: TimelineSummary.fromJson(json['summary'] as Map<String, dynamic>),
      events: parsedEvents,
    );
  }
}
