import 'dart:async';
import '../ai_config.dart';
import 'directory_viewer.dart';
import 'document_table_filler.dart';
import '../services/file_manager.dart';
import '../models/file_info.dart';

/// 工具类型枚举
enum ToolType {
  none,             // 不需要工具
  document,         // 文档处理工具
  directoryView,    // 目录查看工具
  tableFill         // 表格填充工具
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
      case ToolType.directoryView:
        return "目录查看";
      case ToolType.tableFill:
        return "表格填充";
      case ToolType.none:
      default:
        return "";
    }
  }
}

/// 工具调用决策管理器
class ToolManager {
  /// 分析用户消息并决定是否需要调用工具
  /// 基于关键词判断需要调用的工具类型
  static ToolType analyzeMessage(String message) {
    // 检查是否需要查看目录信息
    final directoryKeywords = ['工作区', '文件名', '文件信息', '目录', '文件大小', '查看文件', '文件列表', '几个文件'];
    if (directoryKeywords.any((keyword) => message.contains(keyword))) {
      return ToolType.directoryView;
    }
    
    // 检查是否需要表格填充功能
    final tableFillKeywords = ['自动填表', '总结填表', '填表', '表格填充', '自动填写'];
    if (tableFillKeywords.any((keyword) => message.contains(keyword))) {
      return ToolType.tableFill;
    }
    
    // 检查是否需要文档处理功能
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
      
      case ToolType.directoryView:
        return await _executeDirectoryView();
        
      case ToolType.tableFill:
        return await _executeTableFill();
        
      case ToolType.none:
      default:
        return null;
    }
  }
  
  /// 执行目录查看工具
  static Future<String> _executeDirectoryView() async {
    final fileManager = FileManager();
    
    final StringBuffer result = StringBuffer();
    result.writeln("根据您提供的文件信息，左侧显示了四个分区及其中的文件情况：\n");

    // 获取各分区文件信息
    final sections = ['等待', '读取', '模板', '结果'];
    for (final section in sections) {
      final files = await fileManager.listFiles(section);
      
      if (files.isEmpty) {
        result.writeln("- **${section}区**：当前没有文件。");
      } else {
        result.writeln("- **${section}区**：包含以下文件：");
        for (final file in files) {
          if (!file.isDirectory) {
            final size = _formatFileSize(file.size);
            result.writeln("  - ${file.name} ($size)");
          } else {
            result.writeln("  - ${file.name}/ (目录)");
          }
        }
      }
    }
    
    result.writeln("\n您看到的文件位于\"读取区\"和\"模板区\"。如果您需要处理这些文档，例如查看内容、提取信息或进行分析，请告诉我具体需求。");
    
    return result.toString();
  }
  
  /// 格式化文件大小显示
  static String _formatFileSize(int size) {
    if (size < 1024) {
      return "${size}B";
    } else if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(2)}KB";
    } else {
      return "${(size / (1024 * 1024)).toStringAsFixed(2)}MB";
    }
  }
  
  /// 执行表格填充工具
  static Future<String> _executeTableFill() async {
    try {
      await DocumentTableFiller.fillTablesFromDocuments();
      return "已完成自动填表操作。请查看结果区域以获取生成的文件。";
    } catch (e) {
      return "自动填表操作失败: $e";
    }
  }
}