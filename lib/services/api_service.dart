import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../ai_config.dart';
import '../models/chat_message.dart';

class ApiService {
  // 发送消息到AI API
  static Future<ChatMessage?> sendMessage(String text) async {
    return await _sendMessageWithModel(text, ApiConfig.chatModelName);
  }
  
  // 发送消息到指定模型的AI API
  static Future<ChatMessage?> _sendMessageWithModel(String text, String modelName) async {
    try {
      // 构建包含系统提示的完整消息
      final fullPrompt = '${AiAssistantConfig.systemPrompt}\n\n用户问题: $text';
      
      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {'role': 'user', 'content': fullPrompt},
          ],
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
  
  // 发送消息到分析AI API（用于字段提取等分析任务）
  static Future<ChatMessage?> sendAnalysisRequest(String text) async {
    // 修改此处：每次调用都创建新的独立对话
    try {
      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.analysisModelName,
          'messages': [
            {'role': 'user', 'content': text},
          ],
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
}