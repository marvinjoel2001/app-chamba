class WorkerPortfolioPhoto {
  const WorkerPortfolioPhoto({
    required this.id,
    required this.url,
    this.caption = '',
  });

  final String id;
  final String url;
  final String caption;

  factory WorkerPortfolioPhoto.fromJson(Map<String, dynamic> json) {
    return WorkerPortfolioPhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String? ?? '',
    );
  }
}
