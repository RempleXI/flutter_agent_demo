import 'dart:async';
import '../ai_config.dart';

/// 工具类型枚举
enum ToolType {
  none,         // 不需要工具
  document      // 文档处理工具
}

/// 工具调用结果类
class ToolResult {
  final ToolType toolType;
  final String? result;
  
  ToolResult({required this.toolType, this.result});
  
  String get toolName {
    switch (toolType) {
      case ToolType.document:
        return "文档处理";
      case ToolType.none:
      default:
        return "";
    }
  }
}

/// 工具调用决策管理器
class ToolManager {
  /// 分析用户消息并决定是否需要调用工具
  /// 现在主要基于关键词判断是否需要文档处理功能
  static ToolType analyzeMessage(String message) {
    final docKeywords = ['文件', '文档', 'pdf', 'PDF', 'doc', 'DOC', '处理', '转换', '读取'];
    
    if (docKeywords.any((keyword) => message.contains(keyword))) {
      return ToolType.document;
    }
    
    return ToolType.none;
  }

  /// 根据工具类型执行相应的工具
  static Future<String?> executeTool(ToolType toolType, String query) async {
    switch (toolType) {
      case ToolType.document:
        // 这里应该调用实际的文档处理逻辑
        return "已处理文档相关内容";
      case ToolType.none:
      default:
        return null;
    }
  }
}