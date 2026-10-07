class FavoriteRoute {
  final int? id;
  final String start;
  final String destination;
  final String mode;
  final String distance;
  final String duration;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final DateTime createdAt;

  FavoriteRoute({
    this.id,
    required this.start,
    required this.destination,
    required this.mode,
    required this.distance,
    required this.duration,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start': start,
      'destination': destination,
      'mode': mode,
      'distance': distance,
      'duration': duration,
      'start_lat': startLat,
      'start_lng': startLng,
      'end_lat': endLat,
      'end_lng': endLng,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FavoriteRoute.fromMap(Map<String, dynamic> map) {
    return FavoriteRoute(
      id: map['id'] as int?,
      start: map['start'] as String,
      destination: map['destination'] as String,
      mode: map['mode'] as String,
      distance: map['distance'] as String,
      duration: map['duration'] as String,
      startLat: (map['start_lat'] as num).toDouble(),
      startLng: (map['start_lng'] as num).toDouble(),
      endLat: (map['end_lat'] as num).toDouble(),
      endLng: (map['end_lng'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
