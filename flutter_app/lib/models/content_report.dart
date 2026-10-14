class ContentReport {
  final String id;
  final String reporterId;
  final String contentType; // EPISODE, COMMENT, REVIEW
  final String contentId;
  final String contentTitle;
  final String reason;
  final String description;
  String status; // PENDING, REVIEWED, DISMISSED, ACTIONED
  final int createdAt;

  ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.reason,
    required this.description,
    this.status = 'PENDING',
    required this.createdAt,
  });

  factory ContentReport.fromJson(Map<String, dynamic> json) {
    return ContentReport(
      id: json['id']?.toString() ?? '',
      reporterId: json['reporterId']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? 'EPISODE',
      contentId: json['contentId']?.toString() ?? '',
      contentTitle: json['contentTitle']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterId': reporterId,
      'contentType': contentType,
      'contentId': contentId,
      'contentTitle': contentTitle,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': createdAt,
    };
  }
}

class CreatorStats {
  final int totalSeries;
  final int totalEpisodes;
  final int totalViews;
  final int totalWatchTimeMinutes;
  final int totalFollowers;
  final int totalLikes;
  final double estimatedEarnings;

  CreatorStats({
    this.totalSeries = 0,
    this.totalEpisodes = 0,
    this.totalViews = 0,
    this.totalWatchTimeMinutes = 0,
    this.totalFollowers = 0,
    this.totalLikes = 0,
    this.estimatedEarnings = 0.0,
  });
}
