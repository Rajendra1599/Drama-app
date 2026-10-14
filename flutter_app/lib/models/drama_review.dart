class DramaReview {
  final String id;
  final String userId;
  final String userName;
  final String seriesId;
  final int rating;
  final String reviewText;
  final int createdAt;

  DramaReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.seriesId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
  });

  factory DramaReview.fromJson(Map<String, dynamic> json) {
    return DramaReview(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'StoryUp Fan',
      seriesId: json['seriesId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      reviewText: json['reviewText']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'seriesId': seriesId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt,
    };
  }
}
