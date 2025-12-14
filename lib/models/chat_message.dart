class ChatMessage {
  final String text;
  final bool isUser;
  final bool isToolCall; // 是否是工具调用提示消息

  ChatMessage({required this.text, required this.isUser, this.isToolCall = false});
}