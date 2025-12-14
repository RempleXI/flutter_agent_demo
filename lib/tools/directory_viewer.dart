import 'dart:io';
import 'package:path/path.dart' as path;

/// 目录查看工具类
/// 提供查看写入区和结果区目录的功能
class DirectoryViewer {
  /// 写入区目录路径
  static const String _writeDirPath = 'data/wait';
  
  /// 结果区目录路径
  static const String _resultDirPath = 'data/result';

  /// 查看写入区目录
  /// 返回写入区目录中的所有文件和子目录列表
  static List<String> viewWriteDirectory() {
    return _listDirectory(_writeDirPath);
  }

  /// 查看结果区目录
  /// 返回结果区目录中的所有文件和子目录列表
  static List<String> viewResultDirectory() {
    return _listDirectory(_resultDirPath);
  }

  /// 列出指定目录中的所有文件和子目录
  static List<String> _listDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return ['目录不存在: $dirPath'];
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