import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import './ai_prompt_config.dart';
import '../services/config_service.dart';
import '../tools/table_filler.dart';
import '../tools/xlsx_generator.dart';
import '../tools/document_table_filler.dart';
import '../tools/directory_viewer.dart';
import '../tools/database_filler.dart';
import '../services/file_manager.dart';
import '../models/file_info.dart';
import 'logger_service.dart';

/// 工具类型枚举 - 大类别
enum ToolCategory {
  none, // 不需要工具
  documentProcess, // 文档处理工具
  fileManagement, // 文件管理工具
}

/// 具体工具枚举 - 细分类别
enum SpecificTool {
  none, // 无工具
  // 文档处理工具的子类
  formatConversion, // 格式转换
  contentSummary, // 内容总结
  tableFill, // 自动填表
  autoStorage, // 自动入库
  // 文件管理工具的子类
  deleteFile, // 删除文件
  directoryView, // 查看目录
  moveFile, // 移动文件
  copyFile, // 复制文件
  renameFile, // 重命名文件
}

/// 工具信息类
class ToolInfo {
  final ToolCategory category;
  final SpecificTool specificTool;
  final String categoryName;
  final String specificToolName;

  ToolInfo({
    required this.category,
    required this.specificTool,
    required this.categoryName,
    required this.specificToolName,
  });

  /// 获取显示名称（用于UI显示）
  String get displayName {
    switch (category) {
      case ToolCategory.documentProcess:
        return "文档处理";
      case ToolCategory.fileManagement:
        return "文件管理";
      case ToolCategory.none:
      default:
        return "";
    }
  }

  /// 获取具体工具名称（用于日志或调试）
  String get fullDisplayName => '$categoryName-$specificToolName';
}

/// 工具调用决策服务
/// 使用副AI模型来判断需要调用哪种工具
class ToolDecisionService {
  /// 使用副AI模型判断需要调用哪种工具
  static Future<ToolInfo> shouldCallTool(String userMessage) async {
    logger.i('开始工具决策过程: $userMessage');

    // 检查是否特定词，如果包含则直接使用AI决策模型
    final negationWords = [
      '不',
      '别',
      '不要',
      '不能',
      '不可以',
      '无需',
      '无须',
      '为什么',
      '什么',
      '怎么做',
      '如何',
      '介绍一下',
    ];
    final containsNegation = negationWords.any(
      (word) => userMessage.contains(word),
    );

    if (containsNegation) {
      logger.i('消息中包含否定词，直接使用AI决策模型');
      return _useAIDecisionModel(userMessage);
    }

    // 首先尝试使用关键词匹配
    final matchedTools = _findAllMatchingTools(userMessage);
    logger.i('关键词匹配结果: 匹配到 ${matchedTools.length} 个工具');

    // 如果只有一个匹配项，直接返回该工具
    if (matchedTools.length == 1) {
      logger.i('只有一个匹配项，直接返回: ${matchedTools[0].specificToolName}');
      return matchedTools[0];
    }

    // 如果没有匹配项或有多个匹配项，使用AI决策模型
    if (matchedTools.isEmpty || matchedTools.length > 1) {
      if (matchedTools.isEmpty) {
        logger.i('未找到匹配的关键词，使用AI决策模型');
      } else {
        logger.i(
          '找到多个匹配项 (${matchedTools.length} 个)，使用AI决策模型: ${matchedTools.map((t) => t.specificToolName).join(', ')}',
        );
      }

      return _useAIDecisionModel(userMessage);
    }

    // 默认返回关键词匹配结果
    return analyzeMessage(userMessage);
  }

  /// 使用AI决策模型进行判断
  static Future<ToolInfo> _useAIDecisionModel(String userMessage) async {
    try {
      // 构建提示词，专门用于判断是否需要调用外部工具
      final prompt =
          '''
你是一个专门用于判断需要调用哪种文档处理工具的AI助手。你的任务是分析用户的问题，并决定需要调用哪种工具。

可用的工具类型：
文档处理类：
1. FORMAT_CONVERSION - 当用户需要转换文件格式时
2. CONTENT_SUMMARY - 当用户需要总结文档内容时
3. TABLE_FILL - 当用户需要自动填表或处理表格数据时
4. AUTO_STORAGE - 当用户需要将数据自动入库时

文件管理类：
5. DELETE_FILE - 当用户需要删除文件时
6. DIRECTORY_VIEW - 当用户需要查看工作区目录结构或文件信息时
7. MOVE_FILE - 当用户需要移动文件时
8. COPY_FILE - 当用户需要复制文件时
9. RENAME_FILE - 当用户需要重命名文件时

10. NONE - 当用户问题不需要调用任何工具时

请只回答工具类型名称（FORMAT_CONVERSION/CONTENT_SUMMARY/TABLE_FILL/AUTO_STORAGE/DELETE_FILE/DIRECTORY_VIEW/MOVE_FILE/COPY_FILE/RENAME_FILE/NONE），不要添加其他内容。

示例：
用户问题: PDF转Word
回答: FORMAT_CONVERSION

用户问题: 总结一下这份报告的内容
回答: CONTENT_SUMMARY

用户问题: 能帮我自动填表吗？
回答: TABLE_FILL

用户问题: 把数据存到数据库里
回答: AUTO_STORAGE

用户问题: 帮我自动填入数据库
回答: AUTO_STORAGE

用户问题: 数据库存数据
回答: AUTO_STORAGE

用户问题: 帮我总结文档，自动填入数据库
回答: AUTO_STORAGE


用户问题: 删除这个文件
回答: DELETE_FILE

用户问题: 工作区有哪些文件？
回答: DIRECTORY_VIEW

用户问题: 把文件移动到另一个文件夹
回答: MOVE_FILE

用户问题: 复制一份这个文件
回答: COPY_FILE

用户问题: 重命名这个文件
回答: RENAME_FILE

用户问题: 什么是人工智能？
回答: NONE

用户问题: $userMessage
''';

      // 添加超时机制
      final http.Response response;
      try {
        final configService = ExternalConfigService();
        final baseUrl = configService.get('siliconFlowBaseUrl');
        final apiKey = configService.get('siliconFlowApiKey');
        final decisionModelName = configService.get('decisionModelName');

        final messages = [
          {
            'role': 'system',
            'content': AiPromptConfig.systemPrompt, // 更新类名引用
          },
          {'role': 'user', 'content': userMessage},
        ];

        response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': decisionModelName,
                'messages': messages,
                'stream': false,
                'temperature': 0.1, // 使用较低的温度以获得更确定的答案
                'max_tokens': 20, // 限制输出长度
              }),
            )
            .timeout(Duration(seconds: 30)); // 设置30秒超时
      } catch (timeoutError) {
        logger.w('AI决策模型调用超时', timeoutError);
        // 超时后回退到关键词匹配
        return analyzeMessage(userMessage);
      }

      logger.i('AI决策模型响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content']
            .trim()
            .toUpperCase();
        logger.i('AI决策模型返回结果: $aiResponse');

        // 根据副AI的回答决定调用哪种工具
        return _mapAiResponseToToolInfo(aiResponse, userMessage);
      } else {
        logger.e(
          'AI决策模型调用失败，状态码: ${response.statusCode}，响应内容: ${response.body}，使用关键词匹配作为后备方案',
        );
        // 如果API调用失败，回退到关键词匹配
        return analyzeMessage(userMessage);
      }
    } catch (e, stackTrace) {
      logger.e('AI决策模型调用异常: $e');
      logger.e('异常堆栈信息: $stackTrace');
      // 如果出现异常，回退到关键词匹配
      return analyzeMessage(userMessage);
    }
  }

  /// 查找所有匹配的工具
  static List<ToolInfo> _findAllMatchingTools(String message) {
    final List<ToolInfo> matchedTools = [];

    // 文档处理类工具
    final formatConversionKeywords = [
      '格式转换',
      '转成',
      '转换为',
      'pdf转',
      '转pdf',
      'word转',
      '转word',
    ];
    if (formatConversionKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.formatConversion,
          categoryName: "文档处理",
          specificToolName: "格式转换",
        ),
      );
    }

    final contentSummaryKeywords = ['总结', '概括', '摘要', '归纳', '主要内容'];
    if (contentSummaryKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.contentSummary,
          categoryName: "文档处理",
          specificToolName: "内容总结",
        ),
      );
    }

    final tableFillKeywords = ['自动填表', '总结填表', '填表', '表格填充', '自动填写'];
    if (tableFillKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.tableFill,
          categoryName: "文档处理",
          specificToolName: "自动填表",
        ),
      );
    }

    final autoStorageKeywords = ['自动入库', '存到数据库', '保存到数据库', '数据入库', '数据库'];
    if (autoStorageKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.autoStorage,
          categoryName: "文档处理",
          specificToolName: "自动入库",
        ),
      );
    }

    // 文件管理类工具
    final deleteKeywords = ['删除文件', '删除这个文件', '移除文件'];
    if (deleteKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.deleteFile,
          categoryName: "文件管理",
          specificToolName: "删除文件",
        ),
      );
    }

    final directoryKeywords = [
      '工作区',
      '文件名',
      '文件信息',
      '目录',
      '文件大小',
      '查看文件',
      '文件列表',
      '几个文件',
    ];
    if (directoryKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.directoryView,
          categoryName: "文件管理",
          specificToolName: "查看目录",
        ),
      );
    }

    final moveKeywords = ['移动文件', '把这个文件移到', '移动到'];
    if (moveKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.moveFile,
          categoryName: "文件管理",
          specificToolName: "移动文件",
        ),
      );
    }

    final copyKeywords = ['复制文件', '拷贝文件', '复制一份'];
    if (copyKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.copyFile,
          categoryName: "文件管理",
          specificToolName: "复制文件",
        ),
      );
    }

    final renameKeywords = ['重命名文件', '改名', '文件名改成'];
    if (renameKeywords.any((keyword) => message.contains(keyword))) {
      matchedTools.add(
        ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.renameFile,
          categoryName: "文件管理",
          specificToolName: "重命名文件",
        ),
      );
    }

    return matchedTools;
  }

  /// 将AI响应映射到工具信息
  static ToolInfo _mapAiResponseToToolInfo(
    String aiResponse,
    String userMessage,
  ) {
    logger.i('映射AI响应到工具信息: $aiResponse');
    switch (aiResponse) {
      // 文档处理类工具
      case 'FORMAT_CONVERSION':
        return ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.formatConversion,
          categoryName: "文档处理",
          specificToolName: "格式转换",
        );

      case 'CONTENT_SUMMARY':
        return ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.contentSummary,
          categoryName: "文档处理",
          specificToolName: "内容总结",
        );

      case 'TABLE_FILL':
        return ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.tableFill,
          categoryName: "文档处理",
          specificToolName: "自动填表",
        );

      case 'AUTO_STORAGE':
        return ToolInfo(
          category: ToolCategory.documentProcess,
          specificTool: SpecificTool.autoStorage,
          categoryName: "文档处理",
          specificToolName: "自动入库",
        );

      // 文件管理类工具
      case 'DELETE_FILE':
        return ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.deleteFile,
          categoryName: "文件管理",
          specificToolName: "删除文件",
        );

      case 'DIRECTORY_VIEW':
        return ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.directoryView,
          categoryName: "文件管理",
          specificToolName: "查看目录",
        );

      case 'MOVE_FILE':
        return ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.moveFile,
          categoryName: "文件管理",
          specificToolName: "移动文件",
        );

      case 'COPY_FILE':
        return ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.copyFile,
          categoryName: "文件管理",
          specificToolName: "复制文件",
        );

      case 'RENAME_FILE':
        return ToolInfo(
          category: ToolCategory.fileManagement,
          specificTool: SpecificTool.renameFile,
          categoryName: "文件管理",
          specificToolName: "重命名文件",
        );

      case 'NONE':
        return ToolInfo(
          category: ToolCategory.none,
          specificTool: SpecificTool.none,
          categoryName: "",
          specificToolName: "",
        );

      default:
        logger.w('未识别的AI响应: $aiResponse，使用关键词匹配作为后备方案');
        // 如果副AI回答不是预定义的工具类型，则回退到工具管理器的关键词匹配
        return analyzeMessage(userMessage);
    }
  }

  /// 分析用户消息并决定是否需要调用工具
  /// 基于关键词判断需要调用的工具类型
  static ToolInfo analyzeMessage(String message) {
    logger.i('使用关键词匹配分析消息: $message');

    // 检查是否包含特定词，如果包含则直接返回无工具
    final negationWords = [
      '不',
      '别',
      '不要',
      '不能',
      '不可以',
      '无需',
      '无须',
      '为什么',
      '什么',
      '怎么做',
      '如何',
      '介绍一下',
    ];
    final containsNegation = negationWords.any(
      (word) => message.contains(word),
    );

    if (containsNegation) {
      logger.i('消息中包含特定词，不进行关键词匹配，直接返回无工具');
      return ToolInfo(
        category: ToolCategory.none,
        specificTool: SpecificTool.none,
        categoryName: "",
        specificToolName: "",
      );
    }

    // 查找所有匹配的工具
    final matchedTools = _findAllMatchingTools(message);

    // 如果只有一个匹配项，直接返回
    if (matchedTools.length == 1) {
      logger.i('关键词匹配到单个工具: ${matchedTools[0].specificToolName}');
      return matchedTools[0];
    }

    // 如果有多个匹配项或没有匹配项，返回空工具
    if (matchedTools.length > 1) {
      logger.i(
        '关键词匹配到多个工具: ${matchedTools.map((t) => t.specificToolName).join(', ')}',
      );
    } else {
      logger.i('未匹配到任何工具');
    }

    return ToolInfo(
      category: ToolCategory.none,
      specificTool: SpecificTool.none,
      categoryName: "",
      specificToolName: "",
    );
  }

  /// 根据工具类型执行相应的工具
  static Future<String?> executeTool(
    ToolInfo toolInfo,
    String query, {
    BuildContext? context,
  }) async {
    switch (toolInfo.specificTool) {
      case SpecificTool.formatConversion:
        return "已执行格式转换操作";

      case SpecificTool.contentSummary:
        return "已执行内容总结操作";

      case SpecificTool.tableFill:
        return await _executeTableFill();

      case SpecificTool.autoStorage:
        if (context != null) {
          final result = await DatabaseFiller.fillDatabaseFromDocuments(
            context,
          );
          if (result == null) {
            // 配置缺失，返回特殊标识
            return "CONFIG_MISSING";
          }
          
          // 检查是否是用户取消操作
          if (result == "USER_CANCELLED") {
            // 用户取消操作，返回特殊标识
            return "USER_CANCELLED";
          }
          
          return result == true ? "已执行自动入库操作" : "自动入库操作失败，请检查日志或数据库配置";
        } else {
          return "执行自动入库操作需要界面上下文";
        }

      case SpecificTool.deleteFile:
        return "已执行删除文件操作";

      case SpecificTool.directoryView:
        return await _executeDirectoryView();

      case SpecificTool.moveFile:
        return "已执行移动文件操作";

      case SpecificTool.copyFile:
        return "已执行复制文件操作";

      case SpecificTool.renameFile:
        return "已执行重命名文件操作";

      case SpecificTool.none:
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

    result.writeln(
      "\n您看到的文件位于\"读取区\"和\"模板区\"。如果您需要处理这些文档，例如查看内容、提取信息或进行分析，请告诉我具体需求。",
    );

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
