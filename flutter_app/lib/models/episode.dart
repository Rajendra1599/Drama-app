class Episode {
  final String id;
  final String seriesId;
  final String seasonId;
  final int episodeNumber;
  final String title;
  final String description;
  final String videoUrl;
  final String hlsUrl;
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

  /// Fast-path streaming URL prioritizing adaptive HLS (.m3u8) chunks
  String get playStreamUrl {
    if (hlsUrl.isNotEmpty && hlsUrl.contains('.m3u8')) {
      return hlsUrl;
    }
    return videoUrl;
  }

  Episode({
    required this.id,
    required this.seriesId,
    this.seasonId = 'season_1',
    required this.episodeNumber,
    required this.title,
    this.description = '',
    required this.videoUrl,
    this.hlsUrl = '',
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
      hlsUrl: json['hlsUrl']?.toString() ?? '',
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
      'hlsUrl': hlsUrl,
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

  Episode copyWith({
    String? id,
    String? seriesId,
    String? seasonId,
    int? episodeNumber,
    String? title,
    String? description,
    String? videoUrl,
    String? hlsUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    double? fileSizeMb,
    String? resolution,
    String? aspectRatio,
    String? status,
    String? monetizationType,
    int? views,
    int? likes,
    int? completionCount,
    int? releaseAt,
    bool? isVipLocked,
    bool? showAd,
    String? adPlacement,
  }) {
    return Episode(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      seasonId: seasonId ?? this.seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      resolution: resolution ?? this.resolution,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      status: status ?? this.status,
      monetizationType: monetizationType ?? this.monetizationType,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      completionCount: completionCount ?? this.completionCount,
      releaseAt: releaseAt ?? this.releaseAt,
      isVipLocked: isVipLocked ?? this.isVipLocked,
      showAd: showAd ?? this.showAd,
      adPlacement: adPlacement ?? this.adPlacement,
    );
  }
}
