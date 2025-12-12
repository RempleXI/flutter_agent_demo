import 'dart:convert';
import 'package:http/http.dart' as http;

/// 工具类，包含各种AI可以调用的工具函数
class Tools {
  /// 使用SearXNG免费搜索服务进行网络搜索
  static Future<String?> webSearch(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://cn.bing.com/search?q=$encodedQuery&format=json',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 提取相关结果
        final List<dynamic> results = data['webPages']['value'];
        if (results.isNotEmpty) {
          final StringBuffer sb = StringBuffer();
          final int maxResults = 3; // 限制结果数量
          int count = 0;

          for (var result in results) {
            if (count >= maxResults) break;

            if (result['title'] != null &&
                result['url'] != null &&
                result['content'] != null) {
              sb.writeln('${result['title']}');
              sb.writeln('${result['url']}');
              sb.writeln('${result['content']}');
              sb.writeln(''); // 添加空行分隔
              count++;
            }
          }

          return sb.toString().trim();
        }

        return "未找到相关结果";
      } else {
        return "搜索失败，状态码: ${response.statusCode}";
      }
    } catch (e) {
      return "搜索过程中发生错误: $e";
    }
  }
}
