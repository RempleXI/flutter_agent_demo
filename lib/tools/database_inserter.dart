// 导入必要的库
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import '../services/file_manager.dart';
import '../services/logger_service.dart';
import 'package:logging/logging.dart';

/// Excel转SQL语句工具类
/// 提供将Excel文件内容转换为数据库语句的功能
class DatabaseInserter {
  // 创建Logger实例
  static final LoggerService _logger = LoggerService();
  static final Logger _originalLogger = Logger('DatabaseInserter');
  
  /// 从结果区读取指定的Excel文件并转换为数据库语句
  ///
  /// 参数:
  /// - fileName: 要处理的Excel文件名
  /// - tableName: 目标数据库表名
  ///
  /// 返回值:
  /// - Future<Map<String, dynamic>>: 包含操作结果和SQL语句的映射
  static Future<Map<String, dynamic>> processExcelFile(String fileName, String tableName) async {
    try {
      // 获取结果区域目录
      final directory = await FileManager().getSectionDirectory('结果');
      
      // 构建完整的文件路径
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        return {
          'success': false,
          'message': '错误：文件"$fileName"不存在于结果区域中'
        };
      }
      
      return await _processExcelFile(file, tableName);
    } catch (e) {
      return {
        'success': false,
        'message': '处理文件"$fileName"时发生错误: $e'
      };
    }
  }
  
  /// 在结果区域中查找名为 "待填入数据库内容.xlsx" 或 "待填入数据库内容.xls" 的文件，并进行处理。
  ///
  /// 该方法会按顺序检查这两个文件名，一旦找到存在的文件即停止搜索并处理该文件。
  ///
  /// 参数:
  /// - tableName: 目标数据库表名
  ///
  /// 返回值:
  /// - Future<Map<String, dynamic>>: 包含操作结果和SQL语句的映射
  static Future<Map<String, dynamic>> processDatabaseContentFile(String tableName) async {
    try {
      // 获取结果区域目录
      final directory = await FileManager().getSectionDirectory('结果');
      
      // 定义可能的文件名
      final possibleFileNames = [
        '待填入数据库内容.xlsx',
        '待填入数据库内容.xls'
      ];
      
      File? targetFile;
      
      // 查找确切名称的文件
      for (final fileName in possibleFileNames) {
        final file = File(path.join(directory.path, fileName));
        if (await file.exists()) {
          targetFile = file;
          break;
        }
      }
      
      // 检查是否找到了文件
      if (targetFile == null) {
        return {
          'success': false,
          'message': '错误：结果区域中没有找到名为"待填入数据库内容"的Excel文件'
        };
      }
      
      return await _processExcelFile(targetFile, tableName);
    } catch (e) {
      return {
        'success': false,
        'message': '处理"待填入数据库内容"文件时发生错误: $e'
      };
    }
  }
  
  /// 处理Excel文件的核心逻辑
  ///
  /// 参数:
  /// - file: Excel文件
  /// - tableName: 目标数据库表名
  ///
  /// 返回值:
  /// - Future<Map<String, dynamic>>: 包含操作结果和SQL语句的映射
  static Future<Map<String, dynamic>> _processExcelFile(File file, String tableName) async {
    final fileName = path.basename(file.path);
    _logger.i('开始处理Excel文件: $fileName');
    
    // 读取文件字节数据
    final fileBytes = await file.readAsBytes();
    
    // 将Excel转换为特定格式的文本
    final formattedText = convertExcelToJson(fileBytes);
    _logger.d('转换后的文本:\n$formattedText');
    
    if (formattedText.isEmpty) {
      return {
        'success': false,
        'message': '错误：Excel文件中没有有效数据'
      };
    }
    
    // 从特定格式文本生成SQL语句
    final result = generateSqlFromJson(formattedText, tableName);
    final statements = result['statements'] as List<String>;
    final count = result['count'] as int;
    
    _logger.i('生成了 ${statements.length} 条SQL语句，共 $count 条记录');
    
    if (statements.isEmpty) {
      return {
        'success': false,
        'message': '错误：无法从Excel数据生成SQL语句'
      };
    }
    
    // 输出生成的SQL语句用于调试
    for (int i = 0; i < statements.length; i++) {
      _logger.d('SQL语句 ${i + 1}: ${statements[i]}');
    }
    
    // 输出成功填表信息到终端
    final successMessage = '成功处理文件"$fileName"，共生成$count条记录的SQL语句';
    _logger.i('成功处理: $successMessage');
    stdout.writeln('成功处理: $successMessage');
    
    return {
      'success': true,
      'message': successMessage,
      'statements': statements,
      'count': count,
      'formattedText': formattedText
    };
  }
  
  /// 根据解析的数据生成数据库插入语句
  ///
  /// 参数:
  /// - data: 解析后的数据
  /// - tableName: 目标数据库表名
  ///
  /// 返回值:
  /// - List<String>: 生成的SQL语句列表
  static List<String> _generateInsertStatements(
      List<Map<String, dynamic>> data, String tableName) {
    // 如果没有数据，则返回空列表
    if (data.isEmpty) {
      return [];
    }

    final List<String> statements = [];
    
    // 获取所有列名
    final columns = data[0].keys.toList();
    _logger.i('列名: $columns');
    
    // 构造列名部分
    final columnNames = columns.map((column) => '`$column`').join(', ');
    _logger.d('构造的列名部分: $columnNames');
    
    // 构造所有行的值部分
    final List<String> allValues = [];
    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      _logger.d('处理第${i + 1}行数据: $row');
      
      // 处理每个字段的值
      final values = columns.map((column) {
        final value = row[column];
        _logger.d('处理列 "$column" 的值: $value (类型: ${value.runtimeType})');
        
        if (value == null) {
          return 'NULL';
        } else if (value is String) {
          // 转义单引号并包裹字符串值
          final escapedValue = value.replaceAll("'", "''");
          _logger.d('转义后的字符串值: $escapedValue');
          return "'$escapedValue'";
        } else if (value is num || value is bool) {
          // 数字和布尔值不需要引号
          return value.toString();
        } else {
          // 其他类型转换为字符串并包裹
          final stringValue = value.toString();
          final escapedValue = stringValue.replaceAll("'", "''");
          return "'$escapedValue'";
        }
      }).join(', ');
      
      allValues.add('($values)');
    }
    
    // 生成一条包含所有数据的INSERT语句
    final allValuesString = allValues.join(', ');
    final statement = 'INSERT INTO `$tableName` ($columnNames) VALUES $allValuesString;';
    statements.add(statement);
    
    _logger.i('生成的SQL语句: $statement');
    return statements;
  }
  
  /// 将Excel数据转换为JSON格式文本
  ///
  /// 参数:
  /// - fileBytes: Excel文件的字节数据
  ///
  /// 返回值:
  /// - String: JSON格式的文本，格式为：
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "cells": {
  ///       "R1C1": "等待",
  ///       "R1C2": "读取",
  ///       "R1C3": "模板",
  ///       "R1C4": "结果",
  ///       "R2C1": "1",
  ///       "R2C2": "一",
  ///       "R2C3": "one",
  ///       "R2C4": "q"
  ///     }
  ///   }
  /// }
  static String convertExcelToJson(Uint8List fileBytes) {
    try {
      // 使用excel包加载Excel文件
      final excel = Excel.decodeBytes(fileBytes);
      
      // 获取第一个工作表
      final sheet = excel.tables.values.first;
      
      // 如果工作表为空或没有数据，返回空字符串
      if (sheet.rows.isEmpty) {
        return '';
      }
      
      // 存储所有单元格数据的Map
      final Map<String, String> cells = {};
      
      // 遍历所有行（包括表头）
      for (int i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        
        // 遍历每一列
        for (int j = 0; j < row.length; j++) {
          final cellValue = row[j];
          
          // 只获取单元格的纯文本内容，不包含格式信息
          if (cellValue == null) {
            cells['R${i + 1}C${j + 1}'] = '';
          } else {
            // 提取Excel单元格文本内容
            final cellText = cellValue.value.toString();
            cells['R${i + 1}C${j + 1}'] = cellText;
          }
        }
      }
      
      // 构造最终的JSON结构
      final Map<String, dynamic> jsonStructure = {
        'success': true,
        'data': {
          'cells': cells
        }
      };
      
      // 将Map转换为JSON字符串
      return jsonEncode(jsonStructure);
    } catch (e) {
      _logger.e('将Excel转换为JSON格式文本时发生错误: $e');
      // 出现错误时返回空字符串
      return '';
    }
  }
  
  /// 从JSON格式的文本生成数据库插入语句
  ///
  /// 参数:
  /// - formattedText: JSON格式的文本，包含Excel单元格数据
  /// - tableName: 目标数据库表名
  ///
  /// 返回值:
  /// - Map<String, dynamic>: 包含生成的SQL语句列表和记录数的映射
  ///   {
  ///     'statements': List<String>, // SQL语句列表
  ///     'count': int // 记录数
  ///   }
  static Map<String, dynamic> generateSqlFromJson(String formattedText, String tableName) {
    // 如果没有数据，则返回空列表
    if (formattedText.isEmpty) {
      return {'statements': [], 'count': 0};
    }

    try {
      // 解析JSON格式文本
      final Map<String, dynamic> jsonData = jsonDecode(formattedText);
      
      // 检查JSON结构是否正确
      if (!jsonData.containsKey('success') || !jsonData['success'] || 
          !jsonData.containsKey('data') || !jsonData['data'].containsKey('cells')) {
        _logger.e('JSON格式不正确，缺少必要字段');
        return {'statements': [], 'count': 0};
      }

      final Map<String, dynamic> cells = jsonData['data']['cells'];
      
      // 解析单元格数据，按行和列组织
      final Map<int, Map<int, String>> rowData = {};
      
      // 遍历所有单元格
      cells.forEach((key, value) {
        // 定义正则表达式来匹配RxCy格式的坐标（如R1C2表示第1行第2列）
        final RegExp regExp = RegExp(r'R(\d+)C(\d+)');
        // 在当前键中查找匹配项
        final Match? match = regExp.firstMatch(key);

        // 如果找到匹配项
        if (match != null) {
          // 提取行号（第一个捕获组）
          final int row = int.parse(match.group(1)!);
          // 提取列号（第二个捕获组）
          final int column = int.parse(match.group(2)!);
          
          // 确保行数据结构存在
          if (!rowData.containsKey(row)) {
            rowData[row] = {};
          }
          
          // 存储单元格值
          rowData[row]![column] = value.toString();
        }
      });
      
      // 如果没有解析到数据
      if (rowData.isEmpty) {
        _logger.w('未解析到任何单元格数据');
        return {'statements': [], 'count': 0};
      }
      
      // 提取列名（第一行数据）
      final List<String> headers = [];
      if (rowData.containsKey(1)) {
        final Map<int, String> headerRow = rowData[1]!;
        // 按列顺序提取表头
        final List<int> columnIndices = headerRow.keys.toList()..sort();
        for (int columnIndex in columnIndices) {
          headers.add(headerRow[columnIndex]!);
        }
      }
      
      _logger.i('提取到表头列名: $headers');

      // 存储数据行
      final List<Map<String, dynamic>> tableData = [];

      // 解析数据行（从第二行开始）
      for (int rowIndex = 2; rowIndex <= rowData.keys.reduce((a, b) => a > b ? a : b); rowIndex++) {
        if (rowData.containsKey(rowIndex)) {
          final Map<int, String> dataRow = rowData[rowIndex]!;
          final Map<String, dynamic> rowMap = {};
          
          // 按表头顺序填充数据
          for (int i = 0; i < headers.length; i++) {
            final int columnIndex = i + 1; // 列索引从1开始
            rowMap[headers[i]] = dataRow.containsKey(columnIndex) ? dataRow[columnIndex] : '';
          }
          
          tableData.add(rowMap);
          _logger.d('解析数据行$rowIndex: $rowMap');
        }
      }
      
      _logger.i('共解析到 ${tableData.length} 行数据');

      // 复用原有的SQL生成逻辑
      final statements = _generateInsertStatements(tableData, tableName);
      final count = tableData.length;

      return {'statements': statements, 'count': count};
    } catch (e, s) {
      _logger.e('解析JSON文本时发生错误: $e');
      _logger.e('错误堆栈: $s');
      return {'statements': [], 'count': 0};
    }
  }

}
