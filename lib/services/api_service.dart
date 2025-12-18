import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../services/ai_prompt_config.dart';
import '../services/config_service.dart';

class ApiService {
  // 发送消息到AI API
  static Future<ChatMessage?> sendMessage(
    String text,
    List<ChatMessage> history,
  ) async {
    final configService = ExternalConfigService();
    final modelName = configService.get('chatModelName');
    return await _sendMessageWithModel(text, modelName, history);
  }

  // 发送消息到指定模型的AI API
  static Future<ChatMessage?> _sendMessageWithModel(
    String text,
    String modelName,
    List<ChatMessage> history,
  ) async {
    try {
      final configService = ExternalConfigService();
      final baseUrl = configService.get('siliconFlowBaseUrl');
      final apiKey = configService.get('siliconFlowApiKey');

      // 构建消息历史
      final messages = _buildMessages(history, text);

      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': messages,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        return ChatMessage(text: aiResponse, isUser: false);
      } else {
        return ChatMessage(
          text: 'API请求失败，状态码: ${response.statusCode}',
          isUser: false,
        );
      }
    } catch (e) {
      return ChatMessage(text: '抱歉，发生错误: $e', isUser: false);
    }
  }

  // 构建消息历史
  static List<Map<String, String>> _buildMessages(
    List<ChatMessage> history,
    String currentText,
  ) {
    final messages = <Map<String, String>>[];

    // 添加系统提示
    messages.add({'role': 'system', 'content': AiPromptConfig.systemPrompt});

    // 添加历史消息
    for (final msg in history) {
      // 跳过工具调用消息，因为它们不应该出现在AI的对话历史中
      if (!msg.isToolCall) {
        messages.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }
    }

    // 添加当前用户消息
    messages.add({'role': 'user', 'content': currentText});

    return messages;
  }

  // 发送消息到分析AI API（用于字段提取等分析任务）
  static Future<ChatMessage?> sendAnalysisRequest(String text) async {
    final configService = ExternalConfigService();
    final modelName = configService.get('analysisModelName');
    return await _sendMessageWithModel(text, modelName, []);
  }

  // 发送消息到决策AI API（用于工具调用决策）
  static Future<ChatMessage?> sendDecisionRequest(String text) async {
    final configService = ExternalConfigService();
    final modelName = configService.get('decisionModelName');
    return await _sendMessageWithModel(text, modelName, []);
  }
}
