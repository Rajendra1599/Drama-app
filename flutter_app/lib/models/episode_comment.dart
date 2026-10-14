class EpisodeComment {
  final String id;
  final String userId;
  final String userName;
  final String episodeId;
  final String seriesId;
  final String text;
  int likes;
  bool isLikedByUser;
  final int createdAt;

  EpisodeComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.episodeId,
    required this.seriesId,
    required this.text,
    this.likes = 0,
    this.isLikedByUser = false,
    required this.createdAt,
  });

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    return EpisodeComment(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'User',
      episodeId: json['episodeId']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      isLikedByUser: json['isLikedByUser'] == true,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'episodeId': episodeId,
      'seriesId': seriesId,
      'text': text,
      'likes': likes,
      'isLikedByUser': isLikedByUser,
      'createdAt': createdAt,
    };
  }
}
