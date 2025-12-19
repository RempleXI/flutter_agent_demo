import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../services/file_manager.dart';
import '../tools/document_converter.dart';
import '../tools/table_analyzer.dart';
import '../tools/table_filler.dart';
import '../tools/xlsx_generator.dart';
import '../tools/database_header_fetcher.dart';
import '../services/logger_service.dart';

/// 数据库填充工具类
/// 实现根据文档内容自动填充数据库的完整流程
class DatabaseFiller {
  /// 根据文档填写数据库的完整流程
  ///
  /// 流程：
  /// 1. 检查数据库配置，若无配置则提示需要数据库配置
  /// 2. 调用【获取填写数据库需要的表头】
  /// 3. 调用【预处理所有读取区文件】，获取读取区全部文件的文本内容
  /// 4. 调用【根据读取区内容与表头、格式填写表格内容】，获取需要填写Excel的全部内容
  /// 5. 调用【根据整理后文本内容填写表格】，在结果区创建填写完毕后的Excel文件（命名为待填入数据库内容）
  static Future<String> fillDatabaseFromDocuments() async {
    logger.i('开始执行数据库填充流程');

    // 1. 检查数据库配置，若无配置则提示需要数据库配置
    final configCheckResult = await _checkDatabaseConfig();
    if (!configCheckResult) {
      logger.w('数据库配置检查失败');
      return '数据库配置不完整，请检查数据库配置';
    }

    // 2. 获取数据库表头
    final headersResult = await _fetchDatabaseHeaders();
    if (headersResult == null) {
      logger.w('获取数据库表头失败');
      return '获取数据库表头失败，请检查数据库配置';
    }

    final tableInfo = headersResult['table'];
    final headers = List<String>.from(tableInfo['columns']);
    final format = tableInfo['format'] as String;

    logger.i('获取到数据库表头: $headers，格式: $format');

    // 3. 调用【预处理所有读取区文件】，获取读取区全部文件的文本内容
    final readContent = await _preprocessAllReadFiles();
    logger.i('已完成读取区文件预处理');

    // 4. 调用【根据读取区内容与表头、格式填写表格内容】，获取需要填写Excel的全部内容
    final filledContent = await TableFiller.fillTableContent(
      readContent,
      headers,
      format,
    );

    // 5. 调用【根据整理后文本内容填写表格】，在结果区创建填写完毕后的Excel文件（命名为待填入数据库内容）
    final filePath = await _generateXlsxFile(filledContent);
    logger.i('已在结果区创建填写完毕的Excel文件: $filePath');

    return '已完成数据库填充操作';
  }

  /// 检查数据库配置是否完整
  static Future<bool> _checkDatabaseConfig() async {
    try {
      final headersResult = await DatabaseHeaderFetcher.fetchDatabaseHeaders();
      if (headersResult.containsKey('error')) {
        logger.w('数据库配置检查失败: ${headersResult['error']}');
        return false;
      }
      return true;
    } catch (e, stackTrace) {
      logger.e('检查数据库配置时发生错误', e, stackTrace);
      return false;
    }
  }

  /// 获取数据库表头
  static Future<Map<String, dynamic>?> _fetchDatabaseHeaders() async {
    try {
      final headersResult = await DatabaseHeaderFetcher.fetchDatabaseHeaders();
      if (headersResult.containsKey('error')) {
        logger.w('获取数据库表头失败: ${headersResult['error']}');
        return null;
      }
      return headersResult;
    } catch (e, stackTrace) {
      logger.e('获取数据库表头时发生错误', e, stackTrace);
      return null;
    }
  }

  /// 预处理所有读取区文件，获取读取区全部文件的文本内容
  static Future<String> _preprocessAllReadFiles() async {
    // 使用FileManager获取读取区目录
    final readDir = await FileManager().getSectionDirectory('读取');

    if (!await readDir.exists()) {
      logger.w('读取区目录不存在: ${readDir.path}');
      return '';
    }

    final StringBuffer contentBuffer = StringBuffer();
    int fileCount = 0;

    try {
      final entities = readDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          fileCount++;
          final fileName = path.basename(entity.path);
          logger.i('正在预处理读取区文件: $fileName');

          try {
            // 读取文件内容
            final bytes = await entity.readAsBytes();
            final fileType = DocumentConverter.detectFileType(fileName);

            // 预处理文件
            final processedData = await DocumentConverter.preprocessFile(
              bytes,
              fileType,
              fileName,
            );

            // 添加文件名标识和内容到缓冲区
            contentBuffer.writeln('=== $fileName ===');
            contentBuffer.writeln(processedData['textContent']);
            contentBuffer.writeln(); // 添加空行分隔
          } catch (e) {
            logger.e('预处理文件 $fileName 时出错', e);
          }
        }
      }

      if (fileCount == 0) {
        logger.w('读取区目录为空');
      }
    } catch (e) {
      logger.e('读取读取区目录时出错', e);
    }

    return contentBuffer.toString();
  }

  /// 生成XLSX文件
  static Future<String> _generateXlsxFile(String jsonContent) async {
    try {
      // 清理JSON字符串中的控制字符
      String cleanedJsonContent = jsonContent;
      // 移除可能的控制字符和多余的空白字符
      cleanedJsonContent = cleanedJsonContent
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final analysisResult = json.decode(cleanedJsonContent);
      if (analysisResult.containsKey('error')) {
        logger.e('表格填充失败: ${analysisResult['error']}');
        throw Exception('表格填充失败: ${analysisResult['error']}');
      }

      // 使用XLSX生成器创建Excel文件
      final generator = XlsxGenerator();
      final resultFileName = '待填入数据库内容';

      final filePath = await generator
          .generateXlsxFromJsonWithConflictResolution(
            cleanedJsonContent,
            resultFileName,
          );
      logger.i('Excel文件已生成: $filePath');
      return filePath;
    } catch (e) {
      logger.e('生成XLSX文件时出错', e);
      rethrow;
    }
  }
}
