class Episode {
  final String id;
  final String seriesId;
  final String seasonId;
  final int episodeNumber;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final int durationSeconds;
  final double fileSizeMb;
  final String resolution;
  final String aspectRatio;
  final String status;
  final String monetizationType;
  final int views;
  final int likes;
  final int completionCount;
  final int releaseAt;
  final bool isVipLocked;
  final bool showAd;
  final String adPlacement;

  Episode({
    required this.id,
    required this.seriesId,
    this.seasonId = 'season_1',
    required this.episodeNumber,
    required this.title,
    this.description = '',
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.durationSeconds = 90,
    this.fileSizeMb = 25.0,
    this.resolution = '720x1280',
    this.aspectRatio = '9:16',
    this.status = 'PUBLISHED',
    this.monetizationType = 'FREE',
    this.views = 0,
    this.likes = 0,
    this.completionCount = 0,
    this.releaseAt = 0,
    this.isVipLocked = true,
    this.showAd = true,
    this.adPlacement = 'BEFORE_EPISODE',
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    final epNum = (json['episodeNumber'] as num?)?.toInt() ?? 1;
    return Episode(
      id: json['id']?.toString() ?? 'ep_$epNum',
      seriesId: json['seriesId']?.toString() ?? '',
      seasonId: json['seasonId']?.toString() ?? 'season_1',
      episodeNumber: epNum,
      title: json['title']?.toString() ?? 'Episode $epNum',
      description: json['description']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 90,
      fileSizeMb: (json['fileSizeMb'] as num?)?.toDouble() ?? 25.0,
      resolution: json['resolution']?.toString() ?? '720x1280',
      aspectRatio: json['aspectRatio']?.toString() ?? '9:16',
      status: json['status']?.toString() ?? 'PUBLISHED',
      monetizationType: json['monetizationType']?.toString() ?? (epNum <= 5 ? 'FREE' : 'PREMIUM'),
      views: (json['views'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      completionCount: (json['completionCount'] as num?)?.toInt() ?? 0,
      releaseAt: (json['releaseAt'] as num?)?.toInt() ?? 0,
      isVipLocked: json['isVipLocked'] == true || (json['isFree'] == false) || epNum > 5,
      showAd: json['showAd'] != false,
      adPlacement: json['adPlacement']?.toString() ?? 'BEFORE_EPISODE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'seasonId': seasonId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'fileSizeMb': fileSizeMb,
      'resolution': resolution,
      'aspectRatio': aspectRatio,
      'status': status,
      'monetizationType': monetizationType,
      'views': views,
      'likes': likes,
      'completionCount': completionCount,
      'releaseAt': releaseAt,
      'isVipLocked': isVipLocked,
      'showAd': showAd,
      'adPlacement': adPlacement,
    };
  }
}
