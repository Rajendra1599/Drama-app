import 'episode.dart';

class DramaSeries {
  final String id;
  final String title;
  final String slug;
  final String synopsis;
  final String posterUrl;
  final String coverImageUrl;
  final String genres;
  final String tags;
  final String language;
  final String creatorId;
  final String creatorName;
  final String status;
  final String publishingType;
  final String monetizationType;
  final double rating;
  final int ratingCount;
  final int totalViews;
  final int totalLikes;
  final int followersCount;
  final int totalEpisodes;
  final int freeEpisodesCount;
  final bool isFeatured;
  final int releaseDateEpoch;
  final int trendingScore;
  final int popularScore;
  final String castMembers;
  final String ageRating;
  final Episode? firstEpisode;

  DramaSeries({
    required this.id,
    required this.title,
    this.slug = '',
    this.synopsis = '',
    required this.posterUrl,
    this.coverImageUrl = '',
    this.genres = 'Drama',
    this.tags = '',
    this.language = 'Hindi',
    this.creatorId = 'creator_storyup',
    this.creatorName = 'StoryUp Originals',
    this.status = 'ONGOING',
    this.publishingType = 'PREMIUM',
    this.monetizationType = 'PREMIUM',
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.followersCount = 0,
    this.totalEpisodes = 0,
    this.freeEpisodesCount = 5,
    this.isFeatured = false,
    this.releaseDateEpoch = 0,
    this.trendingScore = 0,
    this.popularScore = 0,
    this.castMembers = '',
    this.ageRating = '13+',
    this.firstEpisode,
  });

  DramaSeries copyWith({
    String? id,
    String? title,
    String? slug,
    String? synopsis,
    String? posterUrl,
    String? coverImageUrl,
    String? genres,
    String? tags,
    String? language,
    String? creatorId,
    String? creatorName,
    String? status,
    String? publishingType,
    String? monetizationType,
    double? rating,
    int? ratingCount,
    int? totalViews,
    int? totalLikes,
    int? followersCount,
    int? totalEpisodes,
    int? freeEpisodesCount,
    bool? isFeatured,
    int? releaseDateEpoch,
    int? trendingScore,
    int? popularScore,
    String? castMembers,
    String? ageRating,
  }) {
    return DramaSeries(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      synopsis: synopsis ?? this.synopsis,
      posterUrl: posterUrl ?? this.posterUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      status: status ?? this.status,
      publishingType: publishingType ?? this.publishingType,
      monetizationType: monetizationType ?? this.monetizationType,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      followersCount: followersCount ?? this.followersCount,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      freeEpisodesCount: freeEpisodesCount ?? this.freeEpisodesCount,
      isFeatured: isFeatured ?? this.isFeatured,
      releaseDateEpoch: releaseDateEpoch ?? this.releaseDateEpoch,
      trendingScore: trendingScore ?? this.trendingScore,
      popularScore: popularScore ?? this.popularScore,
      castMembers: castMembers ?? this.castMembers,
      ageRating: ageRating ?? this.ageRating,
    );
  }

  factory DramaSeries.fromJson(Map<String, dynamic> json) {
    return DramaSeries(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Series',
      slug: json['slug']?.toString() ?? '',
      synopsis: json['synopsis']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      coverImageUrl: json['coverImageUrl']?.toString() ?? '',
      genres: json['genres'] is List
          ? (json['genres'] as List).join(', ')
          : (json['genres']?.toString() ?? 'Drama'),
      tags: json['tags']?.toString() ?? '',
      language: json['language']?.toString() ?? 'Hindi',
      creatorId: json['creatorId']?.toString() ?? 'creator_storyup',
      creatorName: json['creatorName']?.toString() ?? 'StoryUp Originals',
      status: json['status']?.toString() ?? 'ONGOING',
      publishingType: json['publishingType']?.toString() ?? 'PREMIUM',
      monetizationType: json['monetizationType']?.toString() ?? 'PREMIUM',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      totalViews: (json['views'] as num?)?.toInt() ?? (json['totalViews'] as num?)?.toInt() ?? 0,
      totalLikes: (json['totalLikes'] as num?)?.toInt() ?? (json['likes'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
      freeEpisodesCount: (json['freeEpisodesCount'] as num?)?.toInt() ?? 5,
      isFeatured: json['isFeatured'] == true,
      releaseDateEpoch: (json['releaseDateEpoch'] as num?)?.toInt() ?? 0,
      trendingScore: (json['trendingScore'] as num?)?.toInt() ?? 0,
      popularScore: (json['popularScore'] as num?)?.toInt() ?? 0,
      castMembers: json['castMembers']?.toString() ?? '',
      ageRating: json['ageRating']?.toString() ?? '13+',
      firstEpisode: json['firstEpisode'] != null ? Episode.fromJson(json['firstEpisode']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'synopsis': synopsis,
      'posterUrl': posterUrl,
      'coverImageUrl': coverImageUrl,
      'genres': genres,
      'tags': tags,
      'language': language,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': status,
      'publishingType': publishingType,
      'monetizationType': monetizationType,
      'rating': rating,
      'ratingCount': ratingCount,
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'followersCount': followersCount,
      'totalEpisodes': totalEpisodes,
      'freeEpisodesCount': freeEpisodesCount,
      'isFeatured': isFeatured,
      'releaseDateEpoch': releaseDateEpoch,
      'trendingScore': trendingScore,
      'popularScore': popularScore,
      'castMembers': castMembers,
      'ageRating': ageRating,
    };
  }
}
