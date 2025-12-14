import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../ai_config.dart';

/// 工具调用决策服务
/// 使用副AI模型来判断是否需要调用工具
class ToolDecisionService {
  /// 使用副AI模型判断是否需要调用工具
  static Future<bool> shouldCallTool(String userMessage) async {
    try {
      // 构建提示词，专门用于判断是否需要调用外部工具
      final prompt = '''
${AiAssistantConfig.secondarySystemPrompt}

用户问题: $userMessage
''';

      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.secondaryModelName,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'stream': false,
          'temperature': 0.1, // 使用较低的温度以获得更确定的答案
          'max_tokens': 10, // 限制输出长度
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'].trim().toUpperCase();
        
        // 如果副AI回答YES，则需要调用工具
        return aiResponse == 'YES';
      } else {
        // 如果API调用失败，默认回退到简单关键词匹配
        final docKeywords = ['文件', '文档', 'pdf', 'PDF', 'doc', 'DOC', '处理', '转换', '读取'];
        return docKeywords.any((keyword) => userMessage.contains(keyword));
      }
    } catch (e) {
      // 如果出现异常，默认回退到简单关键词匹配
      final docKeywords = ['文件', '文档', 'pdf', 'PDF', 'doc', 'DOC', '处理', '转换', '读取'];
      return docKeywords.any((keyword) => userMessage.contains(keyword));
    }
  }
}