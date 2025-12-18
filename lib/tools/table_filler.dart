import 'dart:convert';
import 'dart:developer' as developer;
import '../services/api_service.dart';

/// 表格填充工具类
/// 用于根据读取区内容与表头、格式填写表格内容
class TableFiller {
  /// 根据读取区内容、表头和格式填写表格
  ///
  /// 参数:
  /// - contentText: 读取区的纯文本内容
  /// - headers: 表头列表
  /// - format: 表格格式 ("horizontal" 或 "vertical")
  ///
  /// 返回:
  /// - 成功时返回包含填充数据的JSON字符串
  /// - 失败时返回错误信息
  static Future<String> fillTableContent(
    String contentText,
    List<String> headers,
    String format,
  ) async {
    try {
      // 第一步：使用正则表达式初步提取数据
      final preliminaryData = _extractDataWithRegex(contentText, headers);

      // 第二步：计算置信度
      final confidence = _calculateConfidence(preliminaryData, headers);

      // 第三步：将初步数据、置信度和原始内容传递给AI进一步完善
      final aiResult = await _refineWithAI(
        preliminaryData,
        headers,
        format,
        contentText,
        confidence,
      );

      // 输出返回的JSON到终端
      print('TableFiller result: $aiResult');

      return aiResult;
    } catch (e) {
      final errorResult = '{"error": "填充过程中发生错误: ${e.toString()}"}';
      print('TableFiller error: $errorResult');
      return errorResult;
    }
  }

  /// 使用正则表达式初步提取数据
  static Map<String, dynamic> _extractDataWithRegex(
    String contentText,
    List<String> headers,
  ) {
    // 这里实现简单的正则表达式数据提取逻辑
    // 实际应用中可以根据表头关键词来匹配相关内容
    final data = <String, dynamic>{};

    // 示例：尝试提取常见字段
    final lines = contentText.split('\n');
    final records = <Map<String, String>>[];

    // 简单地按行分割数据记录
    final recordLines = <List<String>>[];
    List<String> currentRecord = [];

    for (final line in lines) {
      if (line.trim().isEmpty && currentRecord.isNotEmpty) {
        recordLines.add(List<String>.from(currentRecord));
        currentRecord.clear();
      } else if (line.trim().isNotEmpty) {
        currentRecord.add(line.trim());
      }
    }

    if (currentRecord.isNotEmpty) {
      recordLines.add(currentRecord);
    }

    // 对每条记录尝试提取字段
    for (final recordLineList in recordLines) {
      final record = <String, String>{};
      final recordText = recordLineList.join(' ');

      for (final header in headers) {
        // 根据表头关键字尝试提取数据
        if (header.contains('姓名') || header.contains('名称')) {
          // 简单匹配中文姓名（2-4个汉字）
          final nameReg = RegExp(r'[\u4e00-\u9fa5]{2,4}');
          final match = nameReg.firstMatch(recordText);
          record[header] = match?.group(0) ?? '';
        } else if (header.contains('电话') ||
            header.contains('手机') ||
            header.contains('联系方式')) {
          // 匹配手机号
          final phoneReg = RegExp(r'(1[3-9]\d{9})');
          final match = phoneReg.firstMatch(recordText);
          record[header] = match?.group(0) ?? '';
        } else if (header.contains('邮箱')) {
          // 匹配邮箱
          final emailReg = RegExp(
            r'([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)',
          );
          final match = emailReg.firstMatch(recordText);
          record[header] = match?.group(0) ?? '';
        } else if (header.contains('身份证')) {
          // 匹配身份证号
          final idReg = RegExp(r'(\d{17}[0-9Xx])');
          final match = idReg.firstMatch(recordText);
          record[header] = match?.group(0) ?? '';
        } else if (header.contains('日期')) {
          // 匹配日期
          final dateReg = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})');
          final match = dateReg.firstMatch(recordText);
          record[header] = match?.group(0) ?? '';
        } else {
          // 默认处理，简单提取
          record[header] = '';
        }
      }
      records.add(record);
    }

    data['records'] = records;
    return data;
  }

  /// 计算置信度
  static Map<String, dynamic> _calculateConfidence(
    Map<String, dynamic> preliminaryData,
    List<String> headers,
  ) {
    final confidence = <String, dynamic>{};

    final records = List<Map<String, String>>.from(preliminaryData['records']);

    // 1. 覆盖率评估
    double coverageScore = 0;
    if (headers.isNotEmpty) {
      double totalFields = (headers.length * records.length).toDouble();
      double filledFields = 0;

      for (final record in records) {
        for (final header in headers) {
          if (record[header]?.isNotEmpty == true) {
            filledFields++;
          }
        }
      }

      coverageScore = totalFields > 0 ? filledFields / totalFields : 0;
    }

    // 2. 准确性评估
    double accuracyScore = 0;
    if (records.isNotEmpty) {
      double totalValidations = 0;
      double passedValidations = 0;

      for (final record in records) {
        for (final header in headers) {
          final value = record[header] ?? '';
          if (value.isEmpty) continue;

          // 增加验证项计数
          totalValidations++;

          // 根据字段类型进行验证
          if (header.contains('电话') ||
              header.contains('手机') ||
              header.contains('联系方式')) {
            // 验证手机号格式
            if (RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
              passedValidations++;
            }
          } else if (header.contains('邮箱')) {
            // 验证邮箱格式
            if (RegExp(
              r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+$',
            ).hasMatch(value)) {
              passedValidations++;
            }
          } else if (header.contains('身份证')) {
            // 验证身份证格式
            if (RegExp(r'^\d{17}[0-9Xx]$').hasMatch(value)) {
              passedValidations++;
            }
          } else if (header.contains('日期')) {
            // 验证日期格式
            if (RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}$').hasMatch(value)) {
              passedValidations++;
            }
          } else if (header.contains('姓名') || header.contains('名称')) {
            // 验证姓名长度
            if (value.length >= 2 && value.length <= 4) {
              passedValidations++;
            }
          } else {
            // 其他字段默认通过验证
            passedValidations++;
          }
        }
      }

      accuracyScore = totalValidations > 0
          ? passedValidations / totalValidations
          : 0;
    }

    // 3. 完整性评估
    double completenessScore = 0;
    if (records.isNotEmpty) {
      double totalAssessments = 0;
      double passedAssessments = 0;

      for (final record in records) {
        for (final header in headers) {
          final value = record[header] ?? '';

          // 增加评估项计数
          totalAssessments++;

          // 检查内容长度合理性
          if (value.isEmpty) {
            continue;
          } else if (header.contains('地址') && value.length < 5) {
            // 地址过短
            continue;
          } else if (value.length > 100) {
            // 内容过长
            continue;
          } else if (value.contains('待填写') || value.contains('XXX')) {
            // 包含占位符
            continue;
          } else {
            // 通过完整性检查
            passedAssessments++;
          }
        }
      }

      completenessScore = totalAssessments > 0
          ? passedAssessments / totalAssessments
          : 0;
    }

    // 计算综合置信度 (覆盖率40% + 准确性30% + 完整性30%)
    final overallScore =
        (coverageScore * 0.4) +
        (accuracyScore * 0.3) +
        (completenessScore * 0.3);

    confidence['coverage'] = coverageScore;
    confidence['accuracy'] = accuracyScore;
    confidence['completeness'] = completenessScore;
    confidence['overall'] = overallScore;
    confidence['recordCount'] = records.length;

    return confidence;
  }

  /// 将初步提取的数据交给AI进一步完善
  static Future<String> _refineWithAI(
    Map<String, dynamic> preliminaryData,
    List<String> headers,
    String format,
    String originalContent,
    Map<String, dynamic> confidence,
  ) async {
    // 构造给AI的完整提示词
    final prompt =
        '''
你是一个数据整理助手，请根据以下信息完善表格数据。

【处理流程】
1. 我已经使用正则表达式对原始文本进行了初步提取
2. 已经计算了当前提取结果的置信度分数
3. 请你根据置信度和原始内容，对初步提取的数据进行完善

【输入信息】
1. 原始文本内容：
$originalContent

2. 表头列表：
${json.encode(headers)}

3. 表格格式：
$format

4. 初步提取的数据：
${json.encode(preliminaryData)}

5. 置信度评估结果：
${json.encode(confidence)}

【处理规则】
1. 表头定位：
   - 如果格式为 \`horizontal\`：表头位于第一行。用户提供的表头列表依次填入 R1C1, R1C2, R1C3...
   - 如果格式为 \`vertical\`：表头位于第一列。用户提供的表头列表依次填入 R1C1, R2C1, R3C1...

2. 记录识别：
   首先，参考初步提取的结果，同时结合原始文本内容识别独立的**数据记录**（如不同人员、不同项目等）。

3. 数据组织：
   当格式为 \`horizontal\` 时：每个独立的数据记录占用一行，从第二行开始。
   当格式为 \`vertical\` 时：每个独立的数据记录占用一列，从第二列开始。

4. 数据完善：
   - 置信度较高的数据可以直接使用
   - 置信度较低的数据需要结合原始文本内容进行修正
   - 缺失的数据需要从原始文本中查找补充
   - 如果原始文本中确实没有某些字段的信息，在该记录对应的单元格填写"数据丢失"

【坐标规则】
所有行（R）和列（C）的索引均从 1 开始。
当格式为 \`horizontal\` 时：表头占第1行，数据从第2行开始。
当格式为 \`vertical\` 时：表头占第1列，数据从第2列开始。
坐标格式：RxCy 表示第x行第y列。

【输出格式】
输出一个严格的JSON对象，包含以下字段：

1. 处理成功时：
{
  "success": true,
  "data": {
    "cells": {
      "R1C1": "表头1",
      "R1C2": "表头2",
      "R2C1": "数据1",
      "R2C2": 数字1,
      "R3C1": "数据2",
      "R3C2": 数字2,
      ...
    }
  }
}

重要提醒：
- 所有坐标必须从R1C1开始，不要有任何偏移
- 不要留空第一行或第一列
- 确保表头数据从R1C1开始放置
- 如果单元格内容是数字，请以数字类型输出，而不是字符串类型
- 如果单元格内容是非数字，请以字符串类型输出
- 示例：
  - 数字："R2C1": 25，"R3C4": 1800.5
  - 字符串："R2C2": "张三"，"R3C5": "数据丢失"

请严格按照上述格式返回JSON，不要添加任何解释或其他内容，只返回JSON。
''';

    try {
      // 调用AI服务填充表格
      final aiResponse = await ApiService.sendMessage(prompt, []);

      if (aiResponse != null) {
        // 尝试解析AI返回的JSON
        try {
          // 清理返回的内容，移除可能的多余字符
          String cleanedResponse = aiResponse.text
              .trim()
              .replaceAll(RegExp(r'^[^{]*'), '') // 移除开头的非JSON内容
              .replaceAll(RegExp(r'[^}]*$'), ''); // 移除结尾的非JSON内容

          // 验证返回内容是否为有效的JSON
          final decodedJson = json.decode(cleanedResponse);

          // 检查是否是有效的表格填充结果
          if (decodedJson is Map &&
              (decodedJson.containsKey('success') ||
                  decodedJson.containsKey('error'))) {
            return cleanedResponse;
          } else {
            // 如果不是期望的格式，返回错误
            return '{"error": "AI返回格式错误: 请提供正确的参数内容，以便我进行处理。"}';
          }
        } catch (e) {
          // 如果不是有效JSON，检查是否包含有用信息
          if (aiResponse.text.trim().isEmpty) {
            return '{"error": "AI返回空响应"}';
          } else if (aiResponse.text.contains("请提供") &&
              aiResponse.text.contains("内容")) {
            // AI在请求更多内容，这表示填充失败
            return '{"error": "AI返回格式错误: 请提供正确的参数内容，以便我进行处理。"}';
          } else {
            // 尝试包装成错误信息
            return '{"error": "AI返回格式错误: ${aiResponse.text.replaceAll('"', '')}"}';
          }
        }
      } else {
        return '{"error": "AI服务调用失败"}';
      }
    } catch (e) {
      return '{"error": "AI完善过程中发生错误: ${e.toString()}"}';
    }
  }
}
