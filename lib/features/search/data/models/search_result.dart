class SearchResult {
  final String url;
  final String title;
  final String content;

  SearchResult({
    required this.url,
    required this.title,
    required this.content,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      url: json['url'] ?? '',
      title: json['title'] ?? 'No Title',
      content: json['content'] ?? '',
    );
  }
}
