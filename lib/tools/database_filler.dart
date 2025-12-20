import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:async';
import '../services/file_manager.dart';
import '../services/database_service.dart';
import '../tools/database_header_fetcher.dart' as db_header;
import '../tools/document_converter.dart';
import '../tools/table_filler.dart';
import '../tools/xlsx_generator.dart';
import '../tools/database_inserter.dart';
import '../services/logger_service.dart';
import '../widgets/database_fill_preview_dialog.dart';
import '../widgets/config_dialog.dart';

/// 数据库填充工具类
/// 实现从数据库配置检查到生成Excel文件的完整数据库填充流程
class DatabaseFiller {
  /// 填充数据库的完整流程
  ///
  /// 流程说明:
  /// 1. 检查数据库配置
  /// 2. 调用【获取填写数据库需要的表头】
  /// 3. 调用【预处理所有读取区文件】，获取读取区全部文件的文本内容
  /// 4. 调用【根据读取区内容与表头、格式填写表格内容】，获取需要填写Excel的全部内容
  /// 5. 调用【根据整理后文本内容填写表格】，在结果区创建填写完毕后的Excel文件（命名为"待填入数据库内容"）
  /// 6. 调用组件【弹窗Excel内容(databaseFillPreviewDialog)】文件并提示用户可以核对、修改
  /// 7. 用户点击下一步，调用【Excel转化为数据库语句并执行】，完成
  /// 8. 删除结果区中"待填入数据库内容.xlsx"文件
  ///
  /// 参数:
  /// - context: BuildContext上下文
  ///
  /// 返回值:
  /// - 成功时返回true
  /// - 失败时返回false
  /// - 配置缺失时返回null
  static Future<bool?> fillDatabaseFromDocuments(BuildContext context) async {
    logger.i('开始执行数据库填充流程');
    String? generatedFilePath; // 保存生成的文件路径，用于后续删除

    try {
      // 1. 检查数据库配置
      final databaseService = DatabaseService();
      await databaseService.init(); // 确保数据库服务已初始化
      if (!databaseService.isConfigValid()) {
        logger.w('数据库配置不完整');
        // 提示用户需要配置数据库
        await _showDatabaseConfigDialog(context);
        return null; // 返回null表示配置缺失
      }

      // 2. 调用【获取填写数据库需要的表头】
      logger.i('步骤1: 获取数据库表头信息');
      final headerJson = await db_header.DatabaseHeaderFetcher.fetchDatabaseHeaders();
      final headerResult = json.decode(headerJson);

      if (headerResult.containsKey('error')) {
        logger.e('获取表头失败: ${headerResult['error']}');
        // 如果是配置错误，提示用户需要配置数据库
        if (headerResult['error'].toString().contains('数据库配置不完整')) {
          await _showDatabaseConfigDialog(context);
        }
        return false;
      }

      final tableInfo = headerResult['table'];
      final headers = List<String>.from(tableInfo['columns']);
      final format = tableInfo['format'] as String;
      logger.i('成功获取表头: $headers, 格式: $format');

      // 3. 调用【预处理所有读取区文件】，获取读取区全部文件的文本内容
      logger.i('步骤2: 预处理所有读取区文件');
      final readContent = await _preprocessAllReadFiles();
      if (readContent.isEmpty) {
        logger.w('读取区没有可用的文件内容');
        return false;
      }
      logger.i('成功预处理读取区文件，内容长度: ${readContent.length}');

      // 4. 调用【根据读取区内容与表头、格式填写表格内容】，获取需要填写Excel的全部内容
      logger.i('步骤3: 根据读取区内容与表头、格式填写表格内容');
      final filledContent = await TableFiller.fillTableContent(
        readContent,
        headers,
        format,
      );
      
      final filledContentResult = json.decode(filledContent);
      if (filledContentResult.containsKey('error')) {
        logger.e('填充表格内容失败: ${filledContentResult['error']}');
        return false;
      }
      
      logger.i('成功填充表格内容');

      // 5. 调用【根据整理后文本内容填写表格】，在结果区创建填写完毕后的Excel文件（命名为"待填入数据库内容"）
      logger.i('步骤4: 生成Excel文件');
      final generator = XlsxGenerator();
      final filePath = await generator.generateXlsxFromJson(
        json.encode(filledContentResult),
        '待填入数据库内容',
      );
      
      if (filePath.isEmpty) {
        logger.e('生成Excel文件失败');
        return false;
      }
      
      generatedFilePath = filePath; // 保存文件路径
      logger.i('成功生成Excel文件: $filePath');

      // 6. 调用组件【弹窗Excel内容(databaseFillPreviewDialog)】文件并提示用户可以核对、修改
      logger.i('步骤5: 弹窗显示Excel内容');
      final completer = Completer<bool>();
      
      // 检查文件是否存在
      final fileExists = await File(filePath).exists();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return DatabaseFillPreviewDialog(
              filePath: filePath,
              fileExists: fileExists,
              onNext: () {
                // 不需要手动调用Navigator.pop()，因为Dialog组件会在onNext后自动关闭
                completer.complete(true);
              },
            );
          },
        );
      });
      
      // 等待用户点击下一步
      final shouldProceed = await completer.future;
      if (!shouldProceed) {
        logger.i('用户取消了数据库填充操作');
        // 步骤8: 用户取消时删除生成的文件
        await _deleteGeneratedFile(generatedFilePath);
        return false;
      }

      // 7. 用户点击下一步，调用【Excel转化为数据库语句并执行】，完成
      logger.i('步骤6: 将Excel转化为数据库语句并执行');
      final insertResult = await DatabaseInserter.processDatabaseContentFile(
        databaseService.tableName,
      );
      
      if (!insertResult['success']) {
        logger.e('数据库插入失败: ${insertResult['message']}');
        // 步骤8: 插入失败时也删除生成的文件
        await _deleteGeneratedFile(generatedFilePath);
        return false;
      }
      
      logger.i('数据库插入成功: ${insertResult['message']}');
      
      // 步骤8: 数据库插入成功后删除生成的文件
      await _deleteGeneratedFile(generatedFilePath);
      return true;
    } catch (e, stackTrace) {
      logger.e('执行数据库填充流程时发生错误', e, stackTrace);
      // 发生异常时也尝试删除生成的文件
      await _deleteGeneratedFile(generatedFilePath);
      return false;
    }
  }

  /// 显示数据库配置对话框
  static Future<void> _showDatabaseConfigDialog(BuildContext context) async {
    logger.i('显示数据库配置提示对话框');
    
    // 等待当前帧结束再显示对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('数据库配置缺失'),
            content: const Text('数据库配置不完整，请前往配置页面完善数据库相关信息。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 显示配置对话框
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const ConfigDialog();
                    },
                  );
                },
                child: const Text('去配置'),
              ),
            ],
          );
        },
      );
    });
  }

  /// 删除生成的Excel文件
  ///
  /// 参数:
  /// - filePath: 要删除的文件路径
  static Future<void> _deleteGeneratedFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logger.i('成功删除生成的Excel文件: $filePath');
      } else {
        logger.i('文件不存在，无需删除: $filePath');
      }
    } catch (e) {
      logger.w('删除生成的Excel文件时发生错误: $e');
    }
  }

  /// 预处理所有读取区文件
  ///
  /// 返回值:
  /// - 包含所有读取区文件文本内容的字符串
  static Future<String> _preprocessAllReadFiles() async {
    // 使用FileManager获取读取区目录 (使用与DocumentTableFiller相同的中文目录名)
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
        logger.i('读取区目录为空');
      }
    } catch (e) {
      logger.e('读取读取区目录时出错', e);
    }

    return contentBuffer.toString();
  }
}



