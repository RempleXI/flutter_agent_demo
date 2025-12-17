import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../services/file_manager.dart';
import '../services/tool_decision_service.dart';
import 'document_converter.dart';
import 'table_analyzer.dart';
import 'table_filler.dart';
import 'xlsx_generator.dart';

/// 文档表格填充工具类
/// 实现根据文档内容自动填充Excel表格的完整流程
class DocumentTableFiller {
  /// 根据文档填写表格的完整流程
  ///
  /// 流程：
  /// 1. 调用预处理所有读取区文件，获取读取区全部文件的文本内容
  /// 2. 调用查看模板区目录，获取模板区目录
  /// 3. 判断共有几个文件需要处理
  /// 4. 根据目录顺序处理每个模板区文件：
  /// 5. 预处理当前文件（模板区文件）
  /// 6. 调用读取模板区表格并返回表头与格式的工具，获取需要填写的Excel的表头与格式
  /// 7. 调用【根据读取区内容与表头、格式填写表格内容】的工具，获取需要填写Excel的全部内容
  /// 8. 调用【根据整理后文本内容填写表格】的工具，在结果区创建填写完毕后的Excel文件
  /// 9. 重复处理下一个模板区文件，直至全部处理完成
  static Future<void> fillTablesFromDocuments() async {
    print('开始执行文档表格填充流程');

    // 1. 预处理所有读取区文件，获取读取区全部文件的文本内容
    final readContent = await _preprocessAllReadFiles();
    print('已完成读取区文件预处理');

    // 2. 调用查看模板区目录，获取模板区目录
    final templateFiles = await _getTemplateFiles();
    print('模板区文件列表: $templateFiles');

    // 3. 判断共有几个文件需要处理
    // 过滤掉错误信息和空目录提示
    final validTemplateFiles = templateFiles
        .where(
          (file) =>
              file != '目录为空' &&
              !file.startsWith('目录不存在:') &&
              !file.startsWith('读取目录失败:'),
        )
        .toList();

    if (validTemplateFiles.isEmpty) {
      print('模板区没有需要处理的有效文件');
      return;
    }

    print('共需要处理 ${validTemplateFiles.length} 个文件');

    // 4. 根据目录顺序处理每个文件
    for (int i = 0; i < validTemplateFiles.length; i++) {
      final fileName = validTemplateFiles[i];
      print('正在处理第 ${i + 1} 个文件: $fileName');

      // 5. 预处理当前模板区文件
      final processedFileData = await _preprocessCurrentTemplateFile(fileName);
      if (processedFileData == null) {
        print('文件 $fileName 预处理失败，跳过');
        continue;
      }

      // 6. 调用分析工具，获取需要填写的Excel的表头与格式
      // 传入的是模板区文件预处理后的内容
      final textContent = processedFileData['textContent'] as String;
      print('准备传给表格分析工具的文本内容:');
      print('----------------------------------------');
      if (textContent.isEmpty) {
        print('(空内容)');
      } else {
        print(textContent);
      }
      print('----------------------------------------');
      print('文本内容长度: ${textContent.length}');

      final tableAnalysis = await TableAnalyzer.analyzeTableHeaders(
        textContent,
      );

      final analysisResult = json.decode(tableAnalysis);
      if (analysisResult.containsKey('error')) {
        print('文件 $fileName 表头分析失败: ${analysisResult['error']}');
        continue;
      }

      final tableInfo = analysisResult['table'];
      final headers = List<String>.from(tableInfo['columns']);
      final format = tableInfo['format'] as String;

      print('文件 $fileName 分析完成，表头: $headers，格式: $format');

      // 7. 调用填充工具，获取需要填写Excel的全部内容
      final filledContent = await TableFiller.fillTableContent(
        readContent,
        headers,
        format,
      );

      // 8. 调用XLSX生成器，在结果区创建填写完毕后的Excel文件
      await _generateXlsxFile(fileName, filledContent);
      print('文件 $fileName 处理完成');
    }

    print('文档表格填充流程执行完毕');
  }

  /// 预处理所有读取区文件，获取读取区全部文件的文本内容
  static Future<String> _preprocessAllReadFiles() async {
    // 使用FileManager获取读取区目录
    final readDir = await FileManager().getSectionDirectory('读取');

    if (!await readDir.exists()) {
      print('读取区目录不存在: ${readDir.path}');
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
          print('正在预处理读取区文件: $fileName');

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
            print('预处理文件 $fileName 时出错: $e');
          }
        }
      }

      if (fileCount == 0) {
        print('读取区目录为空');
      }
    } catch (e) {
      print('读取读取区目录时出错: $e');
    }

    return contentBuffer.toString();
  }

  /// 获取模板区文件列表
  static Future<List<String>> _getTemplateFiles() async {
    try {
      // 使用FileManager获取模板区目录
      final templateDir = await FileManager().getSectionDirectory('模板');
      if (!await templateDir.exists()) {
        return ['目录不存在: ${templateDir.path}'];
      }

      final entities = templateDir.listSync();
      if (entities.isEmpty) {
        return ['目录为空'];
      }

      return entities.map((entity) {
        final filename = path.basename(entity.path);
        return entity is Directory ? '$filename/' : filename;
      }).toList();
    } catch (e) {
      return ['读取目录失败: $e'];
    }
  }

  /// 预处理当前模板区文件
  static Future<Map<String, dynamic>?> _preprocessCurrentTemplateFile(
    String fileName,
  ) async {
    try {
      // 使用FileManager获取模板区文件路径
      final templateDir = await FileManager().getSectionDirectory('模板');
      final filePath = path.join(templateDir.path, fileName);
      final file = File(filePath);

      if (!file.existsSync()) {
        print('文件不存在: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final fileType = DocumentConverter.detectFileType(fileName);

      print(
        '文件 $fileName 的类型: ${DocumentConverter.getFileTypeDescription(fileType)}',
      );

      final processedData = await DocumentConverter.preprocessFile(
        bytes,
        fileType,
        fileName,
      );

      // 打印预处理结果的详细信息
      print('文件 $fileName 预处理结果:');
      print('- 类型: ${processedData['type']}');
      print('- 格式: ${processedData['format']}');
      print('- 文件大小: ${processedData['fileSize']} 字节');

      if (processedData.containsKey('textContent')) {
        final textContent = processedData['textContent'] as String;
        print('- 文本内容长度: ${textContent.length} 字符');
        print(
          '- 文本内容预览: ${textContent.substring(0, (textContent.length < 200 ? textContent.length : 200))}',
        );
      }

      if (processedData.containsKey('error')) {
        print('- 错误信息: ${processedData['error']}');
      }

      if (processedData.containsKey('sheetNames')) {
        print('- 工作表名称: ${processedData['sheetNames']}');
      }

      if (processedData.containsKey('sharedStringsCount')) {
        print('- 共享字符串数量: ${processedData['sharedStringsCount']}');
      }

      return processedData;
    } catch (e) {
      print('预处理模板区文件 $fileName 时出错: $e');
      return null;
    }
  }

  /// 生成XLSX文件
  static Future<void> _generateXlsxFile(
    String originalFileName,
    String jsonContent,
  ) async {
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
        print('表格填充失败: ${analysisResult['error']}');
        return;
      }

      // 使用XLSX生成器创建Excel文件
      final generator = XlsxGenerator();
      final fileBaseName = path.basenameWithoutExtension(originalFileName);
      final resultFileName = '${fileBaseName}_filled';

      final filePath = await generator.generateXlsxFromJsonWithConflictResolution(
        cleanedJsonContent,
        resultFileName,
      );
      print('Excel文件已生成: $filePath');
    } catch (e) {
      print('生成XLSX文件时出错: $e');
      // 提供更详细的错误信息
      print('原始JSON内容: $jsonContent');
    }
  }
}