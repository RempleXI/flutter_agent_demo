import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/file_manager.dart';

/// 目录查看工具类
/// 提供查看各个数据区域目录的功能
class DirectoryViewer {
  /// 查看等待区目录
  /// 返回等待区目录中的所有文件和子目录列表
  static Future<List<String>> viewWaitDirectory() async {
    return _listDirectory(await FileManager().getSectionDirectory('等待'));
  }

  /// 查看读取区目录
  /// 返回读取区目录中的所有文件和子目录列表
  static Future<List<String>> viewReadDirectory() async {
    return _listDirectory(await FileManager().getSectionDirectory('读取'));
  }

  /// 查看模板区目录
  /// 返回模板区目录中的所有文件和子目录列表
  static Future<List<String>> viewTemplateDirectory() async {
    return _listDirectory(await FileManager().getSectionDirectory('模板'));
  }

  /// 查看结果区目录
  /// 返回结果区目录中的所有文件和子目录列表
  static Future<List<String>> viewResultDirectory() async {
    return _listDirectory(await FileManager().getSectionDirectory('结果'));
  }

  /// 列出指定目录中的所有文件和子目录
  static Future<List<String>> _listDirectory(Directory dir) async {
    if (!await dir.exists()) {
      return ['目录不存在: ${dir.path}'];
    }

    try {
      final entities = dir.listSync();
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
}