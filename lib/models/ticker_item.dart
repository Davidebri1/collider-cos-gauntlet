import 'model_def.dart';

class TickerMessage {
  final String id;
  final String sender; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  final List<String>? fileAttachments;

  const TickerMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.fileAttachments,
  });
}

class TickerItem {
  final ModelDef modelDef;
  final String relativeTime;
  final String summary;
  final List<TickerMessage> conversation;
  final bool isIsolated;
  final List<String>? mediaUrls;
  final bool isStreaming;

  const TickerItem({
    required this.modelDef,
    required this.relativeTime,
    required this.summary,
    required this.conversation,
    this.isIsolated = false,
    this.mediaUrls,
    this.isStreaming = false,
  });

  TickerItem copyWith({
    ModelDef? modelDef,
    String? relativeTime,
    String? summary,
    List<TickerMessage>? conversation,
    bool? isIsolated,
    List<String>? mediaUrls,
    bool? isStreaming,
  }) {
    return TickerItem(
      modelDef: modelDef ?? this.modelDef,
      relativeTime: relativeTime ?? this.relativeTime,
      summary: summary ?? this.summary,
      conversation: conversation ?? this.conversation,
      isIsolated: isIsolated ?? this.isIsolated,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ConversationHistorySession {
  final String id;
  final String title;
  final String? targetModelId; // If specific to a single model
  final String relativeTime;
  final DateTime timestamp;
  final String summary;
  final List<String> modelIds;
  final List<TickerMessage> messages;

  const ConversationHistorySession({
    required this.id,
    required this.title,
    this.targetModelId,
    required this.relativeTime,
    required this.timestamp,
    required this.summary,
    this.modelIds = const [],
    required this.messages,
  });
}

