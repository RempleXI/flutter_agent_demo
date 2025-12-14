import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../ai_config.dart';
import '../models/chat_message.dart';

/// 表格分析工具类
/// 用于分析纯文本格式的Excel数据，识别表头和表格方向
class TableAnalyzer {
  /// 分析表格文本内容，识别表头和格式方向
  /// 
  /// 参数:
  /// - tableText: 用户提供的纯文本格式的Excel数据
  /// 
  /// 返回:
  /// - 成功时返回包含表头和格式的JSON字符串
  /// - 失败时返回错误信息
  static Future<String> analyzeTableHeaders(String tableText) async {
    // 构造给副AI的完整提示词
    final prompt = '''
你是一个数据整理助手。请严格按以下要求处理：

输入：用户提供纯文本格式的Excel数据

处理要求：
分析表头：识别表格的表头内容（哪些是列名/行名）
判断方向：判断表格是横向布局（表头在第一行）还是纵向布局（表头在第一列）

识别规则：
表头识别逻辑
横向表头特征：第一行（或前几行）包含描述性字段名，后续行是具体数据
纵向表头特征：第一列（或前几列）包含描述性字段名，后续列是具体数据
表头内容特点：通常是名词或短语（如"姓名"、"年龄"、"部门"），而不是具体数值或日期

方向判断逻辑
1.优先检查第一行：
如果第一行大部分内容是字段描述，且下方行是数据 → "horizontal"
2.如果不是横向，检查第一列：
如果第一列大部分内容是字段描述，且右侧列是数据 → "vertical"
3.特殊情况：
如果两者都符合，选择"horizontal"
如果无法确定，默认"horizontal"

输出格式：
成功识别时：
{
  "table": {
    "columns": ["字段1", "字段2", "字段3", ...],
    "format": "horizontal" // 或 "vertical"
  }
}
识别失败时：
{
  "error": "文本格式错误：未检测到有效表头"
}

以下是用户提供的表格文本内容：
$tableText
''';

    try {
      // 调用副AI服务分析表格
      final aiResponse = await _sendToSecondaryAI(prompt);
      
      if (aiResponse != null) {
        // 尝试解析AI返回的JSON
        try {
          // 验证返回内容是否为有效的JSON
          json.decode(aiResponse);
          return aiResponse;
        } catch (e) {
          // 如果不是有效JSON，返回错误
          return '{"error": "AI返回格式错误: $aiResponse"}';
        }
      } else {
        return '{"error": "AI服务调用失败"}';
      }
    } catch (e) {
      return '{"error": "分析过程中发生错误: $e"}';
    }
  }

  /// 发送消息到副AI API（用于工具调用决策和特定任务处理）
  static Future<String?> _sendToSecondaryAI(String text) async {
    try {
      // 使用硅基流动(SiliconFlow)的副AI API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.secondaryModelName,  // 使用副AI模型
          'messages': [
            {'role': 'user', 'content': text},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        return aiResponse;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}