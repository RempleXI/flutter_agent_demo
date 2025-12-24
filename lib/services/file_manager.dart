import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../models/file_info.dart';

class FileManager {
  static final FileManager _instance = FileManager._internal();
  factory FileManager() => _instance;
  FileManager._internal();

  // 当前路径堆栈，用于导航
  final Map<String, List<String>> _pathStacks = {};

  // 获取应用文档目录下的文件存储根目录
  Future<Directory> _getRootDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final rootDir = Directory('${docDir.path}/flutter-agent-demo-filedata');
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

  // 获取指定区域的目录
  Future<Directory> getSectionDirectory(String sectionName, [String subPath = '']) async {
    final rootDir = await _getRootDirectory();
    final sectionDir = Directory('${rootDir.path}/$sectionName$subPath');
    if (!await sectionDir.exists()) {
      await sectionDir.create(recursive: true);
    }
    return sectionDir;
  }

  // 列出指定目录下的所有文件和文件夹
  Future<List<FileInfo>> listFiles(String sectionName, [String subPath = '']) async {
    try {
      final sectionDir = await getSectionDirectory(sectionName, subPath);
      final entities = sectionDir.listSync();
      
      final List<FileInfo> files = [];
      for (var entity in entities) {
        final file = entity is File ? entity : null;
        final dir = entity is Directory ? entity : null;
        
        // 检查是否为隐藏文件或临时文件
        final fileName = path.basename(entity.path);
        if (_isHiddenOrTempFile(fileName)) {
          continue; // 跳过隐藏文件或临时文件
        }
        
        final stat = await entity.stat();
        files.add(FileInfo(
          name: fileName,
          path: entity.path,
          isDirectory: dir != null,
          modified: stat.modified,
          size: stat.size,
        ));
      }
      
      return files;
    } catch (e) {
      // 出错时返回空列表
      return [];
    }
  }

  // 检查文件是否为隐藏文件或临时文件
  bool _isHiddenOrTempFile(String fileName) {
    // 以点开头的文件（如 .DS_Store, .gitignore 等）
    if (fileName.startsWith('.')) {
      return true;
    }
    
    // Office临时文件
    if (fileName.startsWith('~\$') || // Excel临时文件
        fileName.endsWith('.tmp') || // 临时文件
        fileName.endsWith('.temp')) { // 临时文件
      return true;
    }
    
    // 常见的隐藏文件和临时文件模式
    const hiddenPatterns = [
      '.DS_Store', // macOS隐藏文件
      'Thumbs.db', // Windows缩略图缓存
      'desktop.ini', // Windows桌面配置
      'Icon\r', // macOS图标文件
    ];
    
    if (hiddenPatterns.contains(fileName)) {
      return true;
    }
    
    // 检查常见临时文件扩展名
    const tempExtensions = [
      '.tmp', '.temp', '.cache', '.bak', '.log'
    ];
    
    for (final ext in tempExtensions) {
      if (fileName.toLowerCase().endsWith(ext)) {
        return true;
      }
    }
    
    return false;
  }

  // 选择并导入文件到指定区域
  Future<bool> pickAndImportFile(String sectionName, [String subPath = '']) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withReadStream: true,
      );
      
      if (result != null && result.files.single.path != null) {
        final platformFile = result.files.single;
        final fileName = platformFile.name;
        
        // 获取目标目录
        final sectionDir = await getSectionDirectory(sectionName, subPath);
        final targetPath = '${sectionDir.path}/$fileName';
        final targetFile = File(targetPath);
        
        // 检查目标文件是否已存在
        if (await targetFile.exists()) {
          // 目标文件已存在，需要处理冲突
          final newName = await _resolveFileConflict(sectionDir, fileName);
          if (newName == null) {
            // 用户选择取消导入
            return false;
          }
          
          // 使用新名称
          final newTargetPath = '${sectionDir.path}/$newName';
          final newTargetFile = File(newTargetPath);
          
          // 复制文件到目标目录
          final file = File(platformFile.path!);
          await file.copy(newTargetPath);
        } else {
          // 文件不存在，直接复制
          final file = File(platformFile.path!);
          await file.copy(targetPath);
        }
        
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 解决文件名冲突
  Future<String?> _resolveFileConflict(Directory sectionDir, String originalName) async {
    // 首先检查是否已有带数字后缀的版本
    String newName = originalName;
    int counter = 2;
    
    while (await File('${sectionDir.path}/$newName').exists()) {
      // 分离文件名和扩展名
      final lastDotIndex = originalName.lastIndexOf('.');
      if (lastDotIndex > 0) {
        final nameWithoutExtension = originalName.substring(0, lastDotIndex);
        final extension = originalName.substring(lastDotIndex);
        newName = '$nameWithoutExtension($counter)$extension';
      } else {
        newName = '$originalName($counter)';
      }
      counter++;
    }
    
    // 如果新名称和原名称相同，表示没有冲突
    if (newName == originalName) {
      return newName;
    }
    
    // 返回新名称，调用者负责使用这个名称
    return newName;
  }
  
  // 公开方法：解决文件名冲突
  Future<String?> resolveFileConflict(Directory sectionDir, String originalName) async {
    return _resolveFileConflict(sectionDir, originalName);
  }

  // 选择并导入文件夹到指定区域
  Future<bool> pickAndImportDirectory(String sectionName, [String subPath = '']) async {
    try {
      final selectedDirectoryPath = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectoryPath != null) {
        final sourceDir = Directory(selectedDirectoryPath);
        if (await sourceDir.exists()) {
          final dirName = path.basename(selectedDirectoryPath);
          
          // 获取目标目录
          final sectionDir = await getSectionDirectory(sectionName, subPath);
          final targetPath = '${sectionDir.path}/$dirName';
          final targetDir = Directory(targetPath);
          
          // 检查目标目录是否已存在
          if (await targetDir.exists()) {
            // 目标目录已存在，需要处理冲突
            final newName = await _resolveDirectoryConflict(sectionDir, dirName);
            if (newName == null) {
              // 用户选择取消导入
              return false;
            }
            
            // 使用新名称
            final newTargetPath = '${sectionDir.path}/$newName';
            final newTargetDir = Directory(newTargetPath);
            
            // 复制整个目录到目标目录
            await _copyDirectory(sourceDir, newTargetDir);
          } else {
            // 目录不存在，直接复制
            await _copyDirectory(sourceDir, targetDir);
          }
          
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // 解决文件夹名冲突
  Future<String?> _resolveDirectoryConflict(Directory sectionDir, String originalName) async {
    // 首先检查是否已有带数字后缀的版本
    String newName = originalName;
    int counter = 2;
    
    while (await Directory('${sectionDir.path}/$newName').exists()) {
      newName = '$originalName($counter)';
      counter++;
    }
    
    // 如果新名称和原名称相同，表示没有冲突
    if (newName == originalName) {
      return newName;
    }
    
    // 返回新名称，调用者负责使用这个名称
    return newName;
  }
  
  // 公开方法：解决文件夹名冲突
  Future<String?> resolveDirectoryConflict(Directory sectionDir, String originalName) async {
    return _resolveDirectoryConflict(sectionDir, originalName);
  }

  // 辅助方法：递归复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    // 创建目标目录
    await destination.create(recursive: true);
    
    // 遍历源目录中的所有实体
    await for (final entity in source.list()) {
      final newPath = path.join(destination.path, path.basename(entity.path));
      
      if (entity is File) {
        // 如果是文件，直接复制
        await entity.copy(newPath);
      } else if (entity is Directory) {
        // 如果是目录，递归复制
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
  
  // 公开方法：递归复制目录（供外部使用）
  Future<void> copyDirectory(Directory source, Directory destination) async {
    await _copyDirectory(source, destination);
  }

  // 打开文件（使用系统默认应用）
  Future<void> openFile(String filePath) async {
    await OpenFile.open(filePath);
  }
  
  // 删除文件或文件夹
  Future<bool> deleteFile(String filePath) async {
    try {
      final fileSystemEntity = FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound 
        ? (FileSystemEntity.typeSync(filePath) == FileSystemEntityType.directory 
           ? Directory(filePath) 
           : File(filePath))
        : File(filePath);
           
      if (await fileSystemEntity.exists()) {
        // 检查是否是目录，如果是则递归删除
        if (fileSystemEntity is Directory) {
          await fileSystemEntity.delete(recursive: true);
        } else {
          await fileSystemEntity.delete();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 移动文件到另一个区域
  Future<bool> moveFileToSection(String filePath, String targetSection, [String targetSubPath = '']) async {
    try {
      final fileSystemEntity = FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound 
        ? (FileSystemEntity.typeSync(filePath) == FileSystemEntityType.directory 
           ? Directory(filePath) 
           : File(filePath))
        : File(filePath);
        
      if (!await fileSystemEntity.exists()) {
        return false;
      }

      final targetDir = await getSectionDirectory(targetSection, targetSubPath);
      final fileName = path.basename(filePath);
      final targetPath = '${targetDir.path}/$fileName';
      
      // 检查目标位置是否已存在同名文件或文件夹
      final targetEntity = FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound 
        ? (FileSystemEntity.typeSync(targetPath) == FileSystemEntityType.directory 
           ? Directory(targetPath) 
           : File(targetPath))
        : File(targetPath);
           
      if (await targetEntity.exists()) {
        if (fileSystemEntity is Directory) {
          // 如果是移动文件夹且目标位置已存在同名文件夹，生成新的文件夹名
          final newName = await resolveDirectoryConflict(targetDir, fileName);
          if (newName != null) {
            final newTargetPath = '${targetDir.path}/$newName';
            await fileSystemEntity.rename(newTargetPath);
            return true;
          } else {
            // 用户选择取消操作
            return false;
          }
        } else {
          // 如果是移动文件且目标位置已存在同名文件，生成新的文件名
          final newName = await resolveFileConflict(targetDir, fileName);
          if (newName != null) {
            final newTargetPath = '${targetDir.path}/$newName';
            await fileSystemEntity.rename(newTargetPath);
            return true;
          } else {
            // 用户选择取消操作
            return false;
          }
        }
      } else {
        // 目标位置不存在同名文件或文件夹，直接移动
        await fileSystemEntity.rename(targetPath);
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  // 导出文件或文件夹
  Future<bool> exportFileOrDirectory(String filePath, String fileName, bool isDirectory) async {
    try {
      final fileSystemEntity = isDirectory 
        ? Directory(filePath) 
        : File(filePath);
        
      if (!await fileSystemEntity.exists()) {
        return false;
      }

      if (isDirectory) {
        // 导出文件夹
        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '请选择保存位置:'
        );

        if (result != null) {
          final targetPath = path.join(result, fileName);
          final targetDir = Directory(targetPath);
          
          // 如果目标目录已存在，先删除
          if (await targetDir.exists()) {
            await targetDir.delete(recursive: true);
          }
          
          // 复制整个目录到目标目录
          await _copyDirectory(Directory(filePath), targetDir);
          return true;
        }
        
        // 用户取消操作
        return false;
      } else {
        // 导出文件
        final result = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置:',
          fileName: fileName,
        );

        if (result != null) {
          // 复制文件到用户选择的位置
          await File(filePath).copy(result);
          return true;
        }
        
        // 用户取消操作
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  // 导出文件（为了向后兼容保留此方法）
  Future<bool> exportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      
      // 使用file_picker让用户选择保存位置
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置:',
        fileName: path.basename(filePath),
      );
      
      if (result != null) {
        // 复制文件到用户选择的位置
        await file.copy(result);
        return true;
      }
      
      // 用户取消操作
      return false;
    } catch (e) {
      return false;
    }
  }
}