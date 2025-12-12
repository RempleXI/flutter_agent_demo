import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_message.dart';

class ApiService {
  // 发送消息到AI API
  static Future<ChatMessage?> sendMessage(String text) async {
    try {
      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.modelName,
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