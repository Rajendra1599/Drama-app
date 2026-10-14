class WatchHistory {
  final String id;
  final String userId;
  final String seriesId;
  final String seasonId;
  final String episodeId;
  final int progressSeconds;
  final int totalSeconds;
  final bool isCompleted;
  final int lastWatchedAt;

  WatchHistory({
    required this.id,
    required this.userId,
    required this.seriesId,
    this.seasonId = 'season_1',
    required this.episodeId,
    required this.progressSeconds,
    required this.totalSeconds,
    this.isCompleted = false,
    required this.lastWatchedAt,
  });

  factory WatchHistory.fromJson(Map<String, dynamic> json) {
    return WatchHistory(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      seasonId: json['seasonId']?.toString() ?? 'season_1',
      episodeId: json['episodeId']?.toString() ?? '',
      progressSeconds: (json['progressSeconds'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 90,
      isCompleted: json['isCompleted'] == true,
      lastWatchedAt: (json['lastWatchedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'seriesId': seriesId,
      'seasonId': seasonId,
      'episodeId': episodeId,
      'progressSeconds': progressSeconds,
      'totalSeconds': totalSeconds,
      'isCompleted': isCompleted,
      'lastWatchedAt': lastWatchedAt,
    };
  }
}
