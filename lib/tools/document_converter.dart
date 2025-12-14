import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:archive/archive.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';

/// 文件类型枚举
enum FileType { word, excel, powerpoint, pdf, text, markdown, unknown }

/// 文档预处理工具类
/// 支持识别常见办公文档类型(word, excel, ppt, pdf, txt, md)并进行预处理
class DocumentConverter {
  /// 根据文件扩展名判断文件类型
  static FileType detectFileType(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'doc':
      case 'docx':
        return FileType.word;
      case 'xls':
      case 'xlsx':
        return FileType.excel;
      case 'ppt':
      case 'pptx':
        return FileType.powerpoint;
      case 'pdf':
        return FileType.pdf;
      case 'txt':
      case 'text':
        return FileType.text;
      case 'md':
      case 'markdown':
        return FileType.markdown;
      default:
        return FileType.unknown;
    }
  }

  /// 获取文件类型的描述
  static String getFileTypeDescription(FileType fileType) {
    switch (fileType) {
      case FileType.word:
        return 'Microsoft Word 文档';
      case FileType.excel:
        return 'Microsoft Excel 电子表格';
      case FileType.powerpoint:
        return 'Microsoft PowerPoint 演示文稿';
      case FileType.pdf:
        return 'PDF 文档';
      case FileType.text:
        return '纯文本文件';
      case FileType.markdown:
        return 'Markdown 文档';
      case FileType.unknown:
        return '未知文件类型';
    }
  }

  /// 预处理文件内容并返回结构化数据
  static Future<Map<String, dynamic>> preprocessFile(
    Uint8List fileBytes,
    FileType fileType,
    String fileName,
  ) async {
    print('正在分析: $fileName');

    switch (fileType) {
      case FileType.word:
        print('正在预处理Word文档: $fileName');
        final result = await _preprocessWord(fileBytes, fileName);
        print('预处理结束: $fileName');
        return result;

      case FileType.excel:
        print('正在预处理Excel文档: $fileName');
        final result = await _preprocessExcel(fileBytes, fileName);
        print('预处理结束: $fileName');
        return result;

      case FileType.powerpoint:
        print('正在预处理PowerPoint文档: $fileName');
        final result = await _preprocessPowerPoint(fileBytes, fileName);
        print('预处理结束: $fileName');
        return result;

      case FileType.pdf:
        print('正在预处理PDF文档: $fileName');
        final result = await _preprocessPdf(fileBytes, fileName);
        print('预处理结束: $fileName');
        return result;

      case FileType.text:
      case FileType.markdown:
        // 特别处理CSV文件
        if (fileName.toLowerCase().endsWith('.csv')) {
          print('正在预处理CSV文件: $fileName');
          final result = await _preprocessText(fileBytes, fileName);
          print('预处理结束: $fileName');
          return result;
        }
        if (fileType == FileType.text) {
          print('正在预处理文本文件: $fileName');
          final result = await _preprocessText(fileBytes, fileName);
          print('预处理结束: $fileName');
          return result;
        } else {
          print('正在预处理Markdown文件: $fileName');
          final result = await _preprocessMarkdown(fileBytes, fileName);
          print('预处理结束: $fileName');
          return result;
        }

      case FileType.unknown:
        // 对于未知类型，尝试按文件扩展名判断
        final lowerFileName = fileName.toLowerCase();
        if (lowerFileName.endsWith('.csv')) {
          print('检测到CSV文件: $fileName');
          final result = await _preprocessText(fileBytes, fileName);
          print('预处理结束: $fileName');
          return result;
        }
        throw Exception('不支持的文件类型: ${getFileTypeDescription(fileType)}');
    }
  }

  /// 预处理Word文档
  static Future<Map<String, dynamic>> _preprocessWord(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      if (fileName.toLowerCase().endsWith('.docx')) {
        // docx文件实际上是ZIP压缩包，包含XML文件
        final archive = ZipDecoder().decodeBytes(fileBytes);

        // 提取文档内容
        final documentXml = archive.findFile('word/document.xml');
        String textContent = '';
        if (documentXml != null) {
          final xmlContent = utf8.decode(
            documentXml.content as Uint8List,
            allowMalformed: true,
          );
          textContent = _extractTextFromXml(xmlContent);
        }

        // 提取文档属性
        final coreProps = archive.findFile('docProps/core.xml');
        Map<String, dynamic> metadata = {};
        if (coreProps != null) {
          final propsContent = utf8.decode(
            coreProps.content as Uint8List,
            allowMalformed: true,
          );
          metadata = _extractMetadataFromXml(propsContent);
        }

        // 提取内部文本内容预览
        String textPreview = textContent;
        if (textContent.length > 2000) {
          textPreview =
              '${textContent.substring(0, 2000)}'
              '\n\n... (content truncated, total ${textContent.length} characters)';
        }

        return {
          'type': 'word',
          'format': 'docx',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': textContent,
          'textContentPreview': textPreview,
          'wordCount': textContent
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length,
          'metadata': metadata,
        };
      } else {
        // 对于旧版.doc文件，Dart没有原生支持
        return {
          'type': 'word',
          'format': 'doc',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': '',
          'textContentPreview': '',
          'error': '旧版Word文档(.doc)格式无法直接解析，请转换为.docx格式',
        };
      }
    } catch (e) {
      return {
        'type': 'word',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': '',
        'error': '解析过程中发生错误: $e',
      };
    }
  }

  /// 预处理Excel文档
  static Future<Map<String, dynamic>> _preprocessExcel(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      if (fileName.toLowerCase().endsWith('.xlsx')) {
        // xlsx文件实际上是ZIP压缩包
        final archive = ZipDecoder().decodeBytes(fileBytes);

        // 提取共享字符串表
        final sharedStringsXml = archive.findFile('xl/sharedStrings.xml');
        List<String> sharedStrings = [];
        if (sharedStringsXml != null) {
          final xmlContent = utf8.decode(
            sharedStringsXml.content as Uint8List,
            allowMalformed: true,
          );
          sharedStrings = _extractSharedStringsFromXml(xmlContent);
        }

        // 获取工作表列表和内容
        final workbookXml = archive.findFile('xl/workbook.xml');
        List<String> sheetNames = [];
        if (workbookXml != null) {
          final xmlContent = utf8.decode(
            workbookXml.content as Uint8List,
            allowMalformed: true,
          );
          sheetNames = _extractSheetNamesFromXml(xmlContent);
        }

        // 提取所有工作表的文本内容
        List<String> allTextContent = [];
        
        // 提取每个工作表的单元格内容
        for (final file in archive) {
          if (file.name.startsWith('xl/worksheets/sheet') &&
              file.name.endsWith('.xml')) {
            final xmlContent = utf8.decode(
              file.content as Uint8List,
              allowMalformed: true,
            );
            // 提取单元格中的文本内容（包括共享字符串引用）
            final cellTexts = _extractCellTextFromWorksheet(xmlContent, sharedStrings);
            allTextContent.addAll(cellTexts);
            
            // 同时使用备选方法提取所有文本内容
            final allTexts = _extractAllTextFromXml(xmlContent);
            allTextContent.addAll(allTexts);
          }
        }

        // 去重并保留顺序
        final uniqueTexts = <String>[];
        final seen = <String>{};
        for (final text in allTextContent) {
          if (!seen.contains(text)) {
            uniqueTexts.add(text);
            seen.add(text);
          }
        }
        allTextContent = uniqueTexts;

        print('通过所有方法提取的文本数量: ${allTextContent.length}');
        print('提取的文本内容: ${allTextContent.take(20).join(", ")}${allTextContent.length > 20 ? "..." : ""}');

        // 尝试构建CSV格式的内容
        String csvContent = _buildCsvFromExcelContent(archive, sharedStrings);
        
        final fullTextContent = allTextContent.join('\n').trim();
        print('最终合并后的文本内容长度: ${fullTextContent.length}');

        // 提取内部文本内容预览
        String textPreview = fullTextContent;
        if (fullTextContent.length > 2000) {
          textPreview =
              '${fullTextContent.substring(0, 2000)}'
              '\n\n... (content truncated, total ${fullTextContent.length} characters)';
        }

        return {
          'type': 'excel',
          'format': 'xlsx',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': csvContent.isNotEmpty ? csvContent : fullTextContent,
          'textContentPreview': textPreview,
          'sheetCount': sheetNames.length,
          'sheetNames': sheetNames,
          'sharedStringsCount': sharedStrings.length,
          'metadata': {'created': DateTime.now().toIso8601String()},
        };
      } else {
        // 对于旧版.xls文件，Dart没有原生支持
        return {
          'type': 'excel',
          'format': 'xls',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': '',
          'textContentPreview': '',
          'error': '旧版Excel文档(.xls)格式无法直接解析，请转换为.xlsx格式',
        };
      }
    } catch (e) {
      return {
        'type': 'excel',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': '',
        'error': '解析过程中发生错误: $e',
      };
    }
  }

  /// 从工作表XML中提取单元格文本
  static List<String> _extractCellTextFromWorksheet(String xmlContent, List<String> sharedStrings) {
    final cellTexts = <String>[];
    
    // 匹配单元格元素 <c>...</c>
    final cellMatches = RegExp(
      r'<c[^>]*>(.*?)</c>',
      dotAll: true,
    ).allMatches(xmlContent);
    
    for (final cellMatch in cellMatches) {
      final cellContent = cellMatch.group(1) ?? '';
      
      // 查找直接文本 <t>...</t>
      final directTextMatches = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(cellContent);
      for (final textMatch in directTextMatches) {
        String text = textMatch.group(1) ?? '';
        // 处理转义字符
        text = text.replaceAll('&lt;', '<');
        text = text.replaceAll('&gt;', '>');
        text = text.replaceAll('&amp;', '&');
        text = text.replaceAll('&quot;', '"');
        text = text.replaceAll('&#39;', "'");
        if (text.trim().isNotEmpty) {
          cellTexts.add(text.trim());
        }
      }
      
      // 如果没有直接文本，查找数值引用 <v>...</v>
      if (directTextMatches.isEmpty) {
        final valueMatches = RegExp(r'<v[^>]*>(.*?)</v>', dotAll: true).allMatches(cellContent);
        for (final valueMatch in valueMatches) {
          String value = valueMatch.group(1) ?? '';
          if (value.trim().isNotEmpty) {
            // 尝试将值解析为整数，作为共享字符串的索引
            try {
              final index = int.parse(value.trim());
              if (index >= 0 && index < sharedStrings.length && sharedStrings[index].isNotEmpty) {
                // 使用共享字符串
                cellTexts.add(sharedStrings[index]);
              } else {
                // 如果索引无效或对应字符串为空，则直接使用值
                // 但要过滤掉纯数字索引
                if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                  cellTexts.add(value.trim());
                }
              }
            } catch (e) {
              // 如果不是数字，直接使用值
              cellTexts.add(value.trim());
            }
          }
        }
      }
    }
    
    return cellTexts;
  }

  /// 从XML中提取所有文本内容
  static List<String> _extractAllTextFromXml(String xmlContent) {
    final texts = <String>[];
    
    // 移除XML声明和注释
    String content = xmlContent;
    content = content.replaceAll(RegExp(r'<\?xml[^>]*>', dotAll: true), '');
    content = content.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    
    // 提取所有<t>标签中的文本内容（这是Excel中最常见的文本存储方式）
    final tTagMatches = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(content);
    for (final match in tTagMatches) {
      String text = match.group(1) ?? '';
      // 处理转义字符
      text = text.replaceAll('&lt;', '<');
      text = text.replaceAll('&gt;', '>');
      text = text.replaceAll('&amp;', '&');
      text = text.replaceAll('&quot;', '"');
      text = text.replaceAll('&#39;', "'");
      // 清理空白字符
      text = text.trim();
      if (text.isNotEmpty) {
        texts.add(text);
      }
    }
    
    // 提取is标签中的文本内容（另一种可能的文本存储方式）
    final isTagMatches = RegExp(r'<is><t[^>]*>(.*?)</t></is>', dotAll: true).allMatches(content);
    for (final match in isTagMatches) {
      String text = match.group(1) ?? '';
      // 处理转义字符
      text = text.replaceAll('&lt;', '<');
      text = text.replaceAll('&gt;', '>');
      text = text.replaceAll('&amp;', '&');
      text = text.replaceAll('&quot;', '"');
      text = text.replaceAll('&#39;', "'");
      // 清理空白字符
      text = text.trim();
      if (text.isNotEmpty) {
        texts.add(text);
      }
    }
    
    // 如果没有找到<t>标签内容，尝试提取所有标签内的文本内容
    if (texts.isEmpty) {
      final textMatches = RegExp(r'>[^<]+<', dotAll: true).allMatches(content);
      for (final match in textMatches) {
        String text = match.group(0) ?? '';
        // 移除开头的>和结尾的<
        text = text.substring(1, text.length - 1);
        // 清理空白字符
        text = text.trim();
        // 过滤掉纯数字和非常短的字符串（可能是索引）
        if (text.isNotEmpty && 
            (text.length > 1 || !RegExp(r'^\d+$').hasMatch(text))) {
          texts.add(text);
        }
      }
    }
    
    return texts;
  }

  /// 预处理PowerPoint文档
  static Future<Map<String, dynamic>> _preprocessPowerPoint(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      if (fileName.toLowerCase().endsWith('.pptx')) {
        // pptx文件实际上是ZIP压缩包
        final archive = ZipDecoder().decodeBytes(fileBytes);

        // 提取所有幻灯片内容
        List<String> slideContents = [];
        for (final file in archive) {
          if (file.name.startsWith('ppt/slides/slide') &&
              file.name.endsWith('.xml')) {
            final xmlContent = utf8.decode(
              file.content as Uint8List,
              allowMalformed: true,
            );
            final textContent = _extractTextFromXml(xmlContent);
            if (textContent.isNotEmpty) {
              slideContents.add(textContent);
            }
          }
        }

        final fullTextContent = slideContents.join('\n\n');

        // 提取内部文本内容预览
        String textPreview = fullTextContent;
        if (fullTextContent.length > 2000) {
          textPreview =
              '${fullTextContent.substring(0, 2000)}'
              '\n\n... (content truncated, total ${fullTextContent.length} characters)';
        }

        // 计算幻灯片数量
        int slideCount = slideContents.length;

        return {
          'type': 'powerpoint',
          'format': 'pptx',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': fullTextContent,
          'textContentPreview': textPreview,
          'slideCount': slideCount,
          'metadata': {'created': DateTime.now().toIso8601String()},
        };
      } else {
        // 对于旧版.ppt文件，Dart没有原生支持
        return {
          'type': 'powerpoint',
          'format': 'ppt',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'textContent': '',
          'textContentPreview': '',
          'error': '旧版PowerPoint文档(.ppt)格式无法直接解析，请转换为.pptx格式',
        };
      }
    } catch (e) {
      return {
        'type': 'powerpoint',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': '',
        'error': '解析过程中发生错误: $e',
      };
    }
  }

  /// 预处理PDF文档
  static Future<Map<String, dynamic>> _preprocessPdf(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // 检查是否是有效的PDF文件
      bool isValidPdf = false;
      if (fileBytes.length >= 4) {
        final magic = String.fromCharCodes(fileBytes.sublist(0, 4));
        isValidPdf = magic == '%PDF';
      }

      // 在Web平台上无法直接处理文件，需要特殊处理
      if (kIsWeb) {
        return {
          'type': 'pdf',
          'format': 'pdf',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'isValid': isValidPdf,
          'textContent': '', // Web平台无法提取PDF文本
          'textContentPreview': '',
          'error': 'Web平台不支持PDF文本提取，请在移动设备或桌面应用中使用此功能',
        };
      }

      // 创建临时文件用于PDF处理
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes);

      try {
        // 使用flutter_pdf_text库提取PDF文本
        final pdfDoc = await PDFDoc.fromFile(tempFile);
        final textContent = await pdfDoc.text;

        // 提取文档信息
        final docInfo = pdfDoc.info;
        final metadata = <String, dynamic>{};
        if (docInfo.author != null) metadata['author'] = docInfo.author;
        if (docInfo.title != null) metadata['title'] = docInfo.title;
        if (docInfo.subject != null) metadata['subject'] = docInfo.subject;
        if (docInfo.creator != null) metadata['creator'] = docInfo.creator;
        if (docInfo.producer != null) metadata['producer'] = docInfo.producer;
        if (docInfo.creationDate != null)
          metadata['creationDate'] = docInfo.creationDate.toString();
        if (docInfo.modificationDate != null)
          metadata['modificationDate'] = docInfo.modificationDate.toString();

        // 提取内部文本内容预览
        String textPreview = textContent;
        if (textContent.length > 2000) {
          textPreview =
              '${textContent.substring(0, 2000)}'
              '\n\n... (content truncated, total ${textContent.length} characters)';
        }

        return {
          'type': 'pdf',
          'format': 'pdf',
          'fileName': fileName,
          'fileSize': fileBytes.length,
          'isValid': isValidPdf,
          'pageCount': pdfDoc.length,
          'textContent': textContent,
          'textContentPreview': textPreview,
          'metadata': metadata,
        };
      } finally {
        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      // 处理插件未实现等平台相关异常
      String errorMessage = '解析过程中发生错误: $e';

      // 检查是否为平台不支持的错误
      if (e.toString().contains('MissingPluginException')) {
        errorMessage = '当前平台不支持PDF文本提取功能。请在Android或iOS设备上运行此应用以使用PDF处理功能。';
      }

      // 尝试估算页数（基于EOF标记的数量）
      int pageCount = 0;
      final byteList = fileBytes.toList();
      for (int i = 0; i < byteList.length - 4; i++) {
        if (byteList[i] == 0x25 && // %
            byteList[i + 1] == 0x45 && // E
            byteList[i + 2] == 0x4F && // O
            byteList[i + 3] == 0x46) {
          // F
          pageCount++;
        }
      }

      // 尝试提取文本内容预览（简单方法）
      String textPreview = '';
      if (fileBytes.isNotEmpty) {
        // 取前2000字节尝试解码为文本
        final previewBytes = fileBytes.length > 2000
            ? fileBytes.sublist(0, 2000)
            : fileBytes;
        textPreview = utf8.decode(previewBytes, allowMalformed: true);
        // 移除非打印字符
        textPreview = textPreview.replaceAll(
          RegExp(r'[^\x20-\x7E\x0A\x0D\t]'),
          '',
        );
      }

      return {
        'type': 'pdf',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': textPreview,
        'pageCountEstimate': pageCount,
        'error': errorMessage,
      };
    }
  }

  /// 预处理文本文件（包括CSV文件）
  static Future<Map<String, dynamic>> _preprocessText(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // 解码文本内容
      String content = utf8.decode(fileBytes, allowMalformed: true);

      // 移除BOM标记（如果存在）
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      // 对于CSV文件，保留全部内容
      if (fileName.toLowerCase().endsWith('.csv')) {
        // CSV文件不需要特殊处理，保留全部内容即可
        // 可以在这里添加特殊的CSV处理逻辑（如格式化等），但目前只需保留原始内容
      }

      // 截断过长的内容
      String truncatedContent = content;
      if (content.length > 10000) {
        truncatedContent =
            '${content.substring(0, 10000)}'
            '\n\n... (content truncated, total ${content.length} characters)';
      }

      return {
        'type': 'text',
        'format': fileName.toLowerCase().endsWith('.csv') ? 'csv' : 'txt',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': content,  // 全部内容作为文本内容
        'textContentPreview': truncatedContent,
        'lineCount': content.split('\n').length,
        'wordCount': content
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length,
        'characterCount': content.length,
      };
    } catch (e) {
      return {
        'type': 'text',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': '',
        'error': '解析过程中发生错误: $e',
      };
    }
  }

  /// 预处理Markdown文档
  static Future<Map<String, dynamic>> _preprocessMarkdown(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // 解码文本内容
      String content = utf8.decode(fileBytes, allowMalformed: true);

      // 移除BOM标记（如果存在）
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      // 截断过长的内容
      String truncatedContent = content;
      if (content.length > 10000) {
        truncatedContent =
            '${content.substring(0, 10000)}'
            '\n\n... (content truncated, total ${content.length} characters)';
      }

      return {
        'type': 'markdown',
        'format': 'md',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': content,
        'textContentPreview': truncatedContent,
        'lineCount': content.split('\n').length,
        'wordCount': content
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length,
        'characterCount': content.length,
      };
    } catch (e) {
      return {
        'type': 'markdown',
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'textContent': '',
        'textContentPreview': '',
        'error': '解析过程中发生错误: $e',
      };
    }
  }

  /// 从XML中提取纯文本
  static String _extractTextFromXml(String xmlContent) {
    // 简单提取文本内容（去除XML标签）
    String textContent = xmlContent;
    textContent = textContent.replaceAll(
      RegExp('<[^>]*>', multiLine: true),
      '',
    );
    textContent = textContent.replaceAll('&lt;', '<');
    textContent = textContent.replaceAll('&gt;', '>');
    textContent = textContent.replaceAll('&amp;', '&');
    textContent = textContent.replaceAll('&quot;', '"');
    textContent = textContent.replaceAll('&#39;', "'");

    // 清理多余空白字符
    textContent = textContent.replaceAll(RegExp(r'\s+'), ' ');
    return textContent.trim();
  }

  /// 从XML中提取元数据
  static Map<String, dynamic> _extractMetadataFromXml(String xmlContent) {
    final metadata = <String, dynamic>{};

    // 提取常见元数据字段
    final titleMatch = RegExp(
      r'<dc:title>(.*?)</dc:title>',
    ).firstMatch(xmlContent);
    if (titleMatch != null) {
      metadata['title'] = titleMatch.group(1);
    }

    final creatorMatch = RegExp(
      r'<dc:creator>(.*?)</dc:creator>',
    ).firstMatch(xmlContent);
    if (creatorMatch != null) {
      metadata['creator'] = creatorMatch.group(1);
    }

    final createdMatch = RegExp(
      r'<dcterms:created[^>]*>(.*?)</dcterms:created>',
    ).firstMatch(xmlContent);
    if (createdMatch != null) {
      metadata['created'] = createdMatch.group(1);
    }

    return metadata;
  }

  /// 从共享字符串XML中提取字符串列表
  static List<String> _extractSharedStringsFromXml(String xmlContent) {
    final strings = <String>[];
    
    // 查找所有共享字符串项 <si>...</si>
    final siMatches = RegExp(
      r'<si>(.*?)</si>',
      dotAll: true,
    ).allMatches(xmlContent);

    for (final siMatch in siMatches) {
      final siContent = siMatch.group(1) ?? '';
      
      // 查找 <t> 标签中的文本
      final tMatch = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).firstMatch(siContent);
      if (tMatch != null) {
        String text = tMatch.group(1) ?? '';
        // 处理转义字符
        text = text.replaceAll('&lt;', '<');
        text = text.replaceAll('&gt;', '>');
        text = text.replaceAll('&amp;', '&');
        text = text.replaceAll('&quot;', '"');
        text = text.replaceAll('&#39;', "'");
        strings.add(text);
      } else {
        // 如果没有 <t> 标签，可能是复杂的富文本格式
        // 尝试提取所有文本内容
        final textNodes = RegExp(r'>([^<]+)<', dotAll: true).allMatches(siContent);
        final richText = textNodes.map((match) => match.group(1) ?? '').join('').trim();
        if (richText.isNotEmpty) {
          strings.add(richText);
        } else {
          strings.add('');
        }
      }
    }

    return strings;
  }

  /// 从工作簿XML中提取工作表名称
  static List<String> _extractSheetNamesFromXml(String xmlContent) {
    final sheetNames = <String>[];
    final matches = RegExp(r'<sheet[^>]*name="(.*?)"').allMatches(xmlContent);

    for (final match in matches) {
      sheetNames.add(match.group(1) ?? '');
    }

    return sheetNames;
  }

  /// 将Excel内容转换为CSV格式
  static String _buildCsvFromExcelContent(Archive archive, List<String> sharedStrings) {
    try {
      // 遍历所有工作表
      for (final file in archive) {
        if (file.name.startsWith('xl/worksheets/sheet') &&
            file.name.endsWith('.xml')) {
          
          final xmlContent = utf8.decode(
            file.content as Uint8List,
            allowMalformed: true,
          );
          
          // 解析工作表数据并转换为CSV
          return _parseWorksheetToCsv(xmlContent, sharedStrings);
        }
      }
    } catch (e) {
      print('构建CSV内容时出错: $e');
    }
    
    return '';
  }

  /// 解析工作表XML并转换为CSV格式
  static String _parseWorksheetToCsv(String xmlContent, List<String> sharedStrings) {
    try {
      final rows = <List<String>>[];
      
      // 查找所有的行 <row>...</row>
      final rowMatches = RegExp(
        r'<row[^>]*>(.*?)</row>',
        dotAll: true,
      ).allMatches(xmlContent);
      
      for (final rowMatch in rowMatches) {
        final rowContent = rowMatch.group(1) ?? '';
        final cells = <String>[];
        
        // 查找行内的所有单元格 <c>...</c>
        // 注意：单元格可能有引用属性，如 r="A1" t="s" 等
        final cellMatches = RegExp(
          r'<c[^>]*>(.*?)</c>',
          dotAll: true,
        ).allMatches(rowContent);
        
        for (final cellMatch in cellMatches) {
          final cellContent = cellMatch.group(1) ?? '';
          
          // 查找直接文本 <t>...</t>
          final tMatch = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).firstMatch(cellContent);
          if (tMatch != null) {
            String text = tMatch.group(1) ?? '';
            // 处理转义字符
            text = text.replaceAll('&lt;', '<');
            text = text.replaceAll('&gt;', '>');
            text = text.replaceAll('&amp;', '&');
            text = text.replaceAll('&quot;', '"');
            text = text.replaceAll('&#39;', "'");
            cells.add(text.trim());
            continue;
          }
          
          // 查找内联字符串 <is><t>...</t></is>
          final isMatch = RegExp(r'<is><t[^>]*>(.*?)</t></is>', dotAll: true).firstMatch(cellContent);
          if (isMatch != null) {
            String text = isMatch.group(1) ?? '';
            // 处理转义字符
            text = text.replaceAll('&lt;', '<');
            text = text.replaceAll('&gt;', '>');
            text = text.replaceAll('&amp;', '&');
            text = text.replaceAll('&quot;', '"');
            text = text.replaceAll('&#39;', "'");
            cells.add(text.trim());
            continue;
          }
          
          // 查找数值引用 <v>...</v>
          final vMatch = RegExp(r'<v[^>]*>(.*?)</v>', dotAll: true).firstMatch(cellContent);
          if (vMatch != null) {
            String value = vMatch.group(1) ?? '';
            try {
              final index = int.parse(value.trim());
              if (index >= 0 && index < sharedStrings.length) {
                cells.add(sharedStrings[index]);
              } else {
                // 检查单元格是否有类型属性 t="s" 表示共享字符串
                // 如果是共享字符串但索引无效，则添加空字符串
                // 否则添加数值本身
                cells.add(value.trim());
              }
            } catch (e) {
              cells.add(value.trim());
            }
            continue;
          }
          
          // 如果都没有找到，添加空字符串
          cells.add('');
        }
        
        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }
      
      // 将行数据转换为CSV格式
      final csvLines = <String>[];
      for (final row in rows) {
        final csvCells = row.map((cell) {
          // 如果单元格包含逗号、换行符或双引号，则需要用双引号包围并转义双引号
          if (cell.contains(',') || cell.contains('\n') || cell.contains('"')) {
            return '"${cell.replaceAll('"', '""')}"';
          }
          return cell;
        }).join(',');
        csvLines.add(csvCells);
      }
      
      return csvLines.join('\n');
    } catch (e) {
      print('解析工作表为CSV时出错: $e');
      return '';
    }
  }

  /// 保存预处理结果到文件（在Web平台上不可用）
  static Future<void> savePreprocessedResult(
    Map<String, dynamic> result,
    String outputPath,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持直接保存文件');
    }

    // 在实际实现中，您需要使用dart:io库来保存文件
    // 这里只是一个占位符
    print('保存预处理结果到: $outputPath');
  }
}
