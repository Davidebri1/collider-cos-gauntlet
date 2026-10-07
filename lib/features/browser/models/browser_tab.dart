class BrowserTab {
  final String id;
  final String title;
  final String url;
  final bool isModelAssigned;
  final String? modelId;
  final String? modelName;
  final String? thumbnailUrl;
  final bool isUserControlling;

  BrowserTab({
    required this.id,
    required this.title,
    required this.url,
    this.isModelAssigned = false,
    this.modelId,
    this.modelName,
    this.thumbnailUrl,
    this.isUserControlling = false,
  });

  BrowserTab copyWith({
    String? title,
    String? url,
    bool? isUserControlling,
    String? thumbnailUrl,
  }) {
    return BrowserTab(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      isModelAssigned: isModelAssigned,
      modelId: modelId,
      modelName: modelName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isUserControlling: isUserControlling ?? this.isUserControlling,
    );
  }
}
