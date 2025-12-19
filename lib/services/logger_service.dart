import 'package:flutter/foundation.dart';

/// 日志级别枚举
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 日志服务类
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  LogLevel _currentLevel = LogLevel.info;

  /// 设置日志级别
  void setLogLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// 输出verbose级别的日志
  void v(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.verbose, message, error, stackTrace);
  }

  /// 输出debug级别的日志
  void d(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// 输出info级别的日志
  void i(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// 输出warning级别的日志
  void w(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// 输出error级别的日志
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// 实际的日志输出方法
  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    // 检查当前日志级别是否应该输出
    if (!_shouldLog(level)) return;

    final levelStr = level.toString().split('.').last.toUpperCase();
    final timestamp = DateTime.now().toString();
    
    // 在调试模式下输出日志
    if (kDebugMode) {
      print('[$timestamp] $levelStr: $message');
      
      if (error != null) {
        print('Error: $error');
      }
      
      if (stackTrace != null) {
        print('StackTrace:\n$stackTrace');
      }
    }
  }

  /// 判断是否应该输出指定级别的日志
  bool _shouldLog(LogLevel level) {
    const levels = LogLevel.values;
    return levels.indexOf(level) >= levels.indexOf(_currentLevel);
  }
}

/// 全局日志服务实例
final logger = LoggerService();