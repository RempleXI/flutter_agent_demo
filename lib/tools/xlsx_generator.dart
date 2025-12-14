// 导入必要的库
// dart:io - 用于文件操作
// package:excel/excel.dart - 用于创建和操作Excel文件
// package:path/path.dart - 用于处理文件路径
// dart:convert - 用于JSON数据解析
// package:flutter_agent_demo/services/file_manager.dart - 用于获取文件目录
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:flutter_agent_demo/services/file_manager.dart';

/// XLSX文件生成器类
/// 这个类负责将不同格式的数据（如CSV、JSON）转换成Excel文件(.xlsx)
class XlsxGenerator {
  /// 将AI返回的CSV格式数据转换为XLSX文件并保存
  ///
  /// 参数:
  /// - csvData: 包含表格数据的CSV格式字符串
  /// - fileName: 要保存的Excel文件名（不含扩展名）
  ///
  /// 返回值:
  /// - Future<String>: 生成的Excel文件的完整路径
  ///
  /// 异常:
  /// - Exception: 如果生成过程中出现错误则抛出异常
  Future<String> generateXlsxFromData(String csvData, String fileName) async {
    try {
      // 解析CSV数据，将其转换为二维字符串数组
      List<List<String>> tableData = _parseCsvData(csvData);

      // 创建一个新的Excel工作簿
      final excel = Excel.createExcel();
      // 获取默认的工作表Sheet1
      final sheet = excel['Sheet1'];

      // 遍历所有行和列，将数据填入Excel表格中
      for (int i = 0; i < tableData.length; i++) {
        for (int j = 0; j < tableData[i].length; j++) {
          // 设置单元格的值，i代表行索引，j代表列索引
          sheet
                  .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
                  .value =
              tableData[i][j];
        }
      }

      // 获取"结果"目录，这是保存生成文件的位置
      final directory = await FileManager().getSectionDirectory('结果');

      // 构建完整的文件路径，文件名为传入的文件名加上.xlsx扩展名
      final filePath = path.join(directory.path, '$fileName.xlsx');
      // 保存Excel文件为字节数组
      final fileBytes = excel.save();
      // 创建File对象用于写入文件
      final file = File(filePath);
      // 将字节数组写入文件
      await file.writeAsBytes(fileBytes!);

      // 返回生成的文件路径
      return filePath;
    } catch (e) {
      // 如果发生任何错误，抛出带有详细信息的异常
      throw Exception('Failed to generate XLSX file: $e');
    }
  }

  /// 解析CSV格式数据为二维数组
  ///
  /// 参数:
  /// - csvData: CSV格式的字符串数据
  ///
  /// 返回值:
  /// - List<List<String>>: 二维字符串数组，表示表格数据
  List<List<String>> _parseCsvData(String csvData) {
    // 创建存储结果的列表
    List<List<String>> result = [];
    // 按换行符分割数据，得到每一行
    List<String> rows = csvData.split('\n');

    // 遍历每一行数据
    for (String row in rows) {
      // 如果行不为空，则处理该行
      if (row.isNotEmpty) {
        // 按逗号分割每行，得到各个列的数据
        List<String> columns = row.split(',');
        // 遍历每个字段，移除可能存在的引号并去除空格
        for (int i = 0; i < columns.length; i++) {
          columns[i] = columns[i].replaceAll('"', '').trim();
        }
        // 将处理好的行数据添加到结果中
        result.add(columns);
      }
    }

    // 返回解析后的二维数组
    return result;
  }

  /// 检查数据是否可能是表格格式（包含逗号和换行符）
  ///
  /// 参数:
  /// - data: 待检查的字符串数据
  ///
  /// 返回值:
  /// - bool: 如果数据包含逗号和换行符则返回true，否则返回false
  bool isTableData(String data) {
    // 判断数据中是否同时包含逗号和换行符，这是CSV格式的基本特征
    return data.contains(',') && data.contains('\n');
  }

  /// 检查数据是否为JSON表格格式
  ///
  /// 参数:
  /// - data: 待检查的字符串数据
  ///
  /// 返回值:
  /// - bool: 如果数据是有效的JSON且符合指定格式则返回true，否则返回false
  ///
  /// 正确的JSON格式应该如下所示:
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "cells": {
  ///       "R1C1": "表头1",
  ///       "R1C2": "表头2",
  ///       "R2C1": "数据1",
  ///       "R2C2": "数据2",
  ///       ...
  ///     }
  ///   }
  /// }
  bool isJsonTableData(String data) {
    try {
      // 尝试解析JSON数据
      final jsonData = jsonDecode(data);
      // 检查解析后的数据是否为Map类型并且包含指定的结构
      return jsonData is Map &&
          jsonData.containsKey('success') &&
          jsonData['success'] == true &&
          jsonData.containsKey('data') &&
          jsonData['data'] is Map &&
          jsonData['data'].containsKey('cells');
    } catch (e) {
      // 如果解析失败，说明不是有效的JSON格式，返回false
      return false;
    }
  }

  /// 将JSON格式表格数据转换为XLSX文件
  ///
  /// 参数:
  /// - jsonData: 包含表格数据的JSON格式字符串
  /// - fileName: 要保存的Excel文件名（不含扩展名）
  ///
  /// 返回值:
  /// - Future<String>: 生成的Excel文件的完整路径
  ///
  /// JSON格式应该如下所示:
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "cells": {
  ///       "R1C1": "表头1",
  ///       "R1C2": "表头2",
  ///       "R2C1": "数据1",
  ///       "R2C2": "数据2",
  ///       ...
  ///     }
  ///   }
  /// }
  /// 其中RxCy表示第x行第y列（从1开始计数）
  Future<String> generateXlsxFromJson(String jsonData, String fileName) async {
    try {
      // 清理JSON数据中的控制字符
      String cleanedJsonData = jsonData
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
          
      // 解析JSON数据，转换为Map对象
      final Map<String, dynamic> response = jsonDecode(cleanedJsonData);
      // 获取data部分的数据
      final Map<String, dynamic> tableData = response['data'];
      // 获取cells部分的数据，这部分包含了所有的单元格数据
      final Map<String, dynamic> cells = tableData['cells'];

      // 创建一个新的Excel工作簿
      final excel = Excel.createExcel();
      // 获取默认的工作表Sheet1
      final sheet = excel['Sheet1'];

      // 遍历所有单元格数据
      cells.forEach((key, value) {
        // 定义正则表达式来匹配RxCy格式的坐标（如R1C2表示第1行第2列）
        final RegExp regExp = RegExp(r'R(\d+)C(\d+)');
        // 在当前键中查找匹配项
        final Match? match = regExp.firstMatch(key);

        // 如果找到匹配项
        if (match != null) {
          // 提取行号（第一个捕获组），并减1以适应0基索引
          final int row = int.parse(match.group(1)!) - 1;
          // 提取列号（第二个捕获组），并减1以适应0基索引
          final int column = int.parse(match.group(2)!) - 1;

          // 在对应位置设置单元格的值
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              )
              .value = value
              .toString();
        }
      });

      // 获取"结果"目录，这是保存生成文件的位置
      final directory = await FileManager().getSectionDirectory('结果');

      // 构建完整的文件路径，文件名为传入的文件名加上.xlsx扩展名
      final filePath = path.join(directory.path, '$fileName.xlsx');
      // 保存Excel文件为字节数组
      final fileBytes = excel.save();
      // 创建File对象用于写入文件
      final file = File(filePath);
      // 将字节数组写入文件
      await file.writeAsBytes(fileBytes!);

      // 返回生成的文件路径
      return filePath;
    } catch (e) {
      // 如果发生任何错误，抛出带有详细信息的异常
      throw Exception('Failed to generate XLSX file from JSON: $e. Original JSON: $jsonData');
    }
  }
  
  /// 将JSON格式表格数据转换为XLSX文件（带冲突解决）
  ///
  /// 参数:
  /// - jsonData: 包含表格数据的JSON格式字符串
  /// - fileName: 要保存的Excel文件名（不含扩展名）
  ///
  /// 返回值:
  /// - Future<String>: 生成的Excel文件的完整路径
  Future<String> generateXlsxFromJsonWithConflictResolution(String jsonData, String fileName) async {
    try {
      // 清理JSON数据中的控制字符
      String cleanedJsonData = jsonData
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
          
      // 解析JSON数据，转换为Map对象
      final Map<String, dynamic> response = jsonDecode(cleanedJsonData);
      // 获取data部分的数据
      final Map<String, dynamic> tableData = response['data'];
      // 获取cells部分的数据，这部分包含了所有的单元格数据
      final Map<String, dynamic> cells = tableData['cells'];

      // 创建一个新的Excel工作簿
      final excel = Excel.createExcel();
      // 获取默认的工作表Sheet1
      final sheet = excel['Sheet1'];

      // 遍历所有单元格数据
      cells.forEach((key, value) {
        // 定义正则表达式来匹配RxCy格式的坐标（如R1C2表示第1行第2列）
        final RegExp regExp = RegExp(r'R(\d+)C(\d+)');
        // 在当前键中查找匹配项
        final Match? match = regExp.firstMatch(key);

        // 如果找到匹配项
        if (match != null) {
          // 提取行号（第一个捕获组），并减1以适应0基索引
          final int row = int.parse(match.group(1)!) - 1;
          // 提取列号（第二个捕获组），并减1以适应0基索引
          final int column = int.parse(match.group(2)!) - 1;

          // 在对应位置设置单元格的值
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              )
              .value = value
              .toString();
        }
      });

      // 获取"结果"目录，这是保存生成文件的位置
      final directory = await FileManager().getSectionDirectory('结果');
      
      // 处理文件名冲突
      String finalFileName = fileName;
      int counter = 2;
      String filePath = path.join(directory.path, '$finalFileName.xlsx');
      
      while (await File(filePath).exists()) {
        finalFileName = '${fileName}($counter)';
        filePath = path.join(directory.path, '$finalFileName.xlsx');
        counter++;
      }

      // 保存Excel文件为字节数组
      final fileBytes = excel.save();
      // 创建File对象用于写入文件
      final file = File(filePath);
      // 将字节数组写入文件
      await file.writeAsBytes(fileBytes!);

      // 返回生成的文件路径
      return filePath;
    } catch (e) {
      // 如果发生任何错误，抛出带有详细信息的异常
      throw Exception('Failed to generate XLSX file from JSON: $e. Original JSON: $jsonData');
    }
  }

  /// 从JSON文件读取数据并生成XLSX文件
  ///
  /// 参数:
  /// - jsonFilePath: JSON文件的完整路径
  /// - fileName: 要保存的Excel文件名（不含扩展名）
  ///
  /// 返回值:
  /// - Future<String>: 生成的Excel文件的完整路径
  Future<String> generateXlsxFromJsonFile(
    String jsonFilePath,
    String fileName,
  ) async {
    try {
      // 读取JSON文件内容
      final file = File(jsonFilePath);
      final jsonString = await file.readAsString();

      // 调用现有的generateXlsxFromJson方法处理数据
      return await generateXlsxFromJson(jsonString, fileName);
    } catch (e) {
      // 如果发生任何错误，抛出带有详细信息的异常
      throw Exception('Failed to generate XLSX file from JSON file: $e');
    }
  }
}