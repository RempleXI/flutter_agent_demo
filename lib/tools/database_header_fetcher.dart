import 'dart:convert';
import '../services/database_service.dart';
import '../services/logger_service.dart';

/// 数据库表头获取工具类
/// 实现获取数据库表列名并生成标准格式的表头信息
class DatabaseHeaderFetcher {
  /// 获取数据库表头信息
  ///
  /// 步骤：
  /// 1. 获取数据库配置，得到用户需要填写的库、表
  /// 2. 查询数据库中该表列名
  ///    - 若用户未指定列：使用全部列名
  ///    - 若用户已指定列：核对列名是否包含在内，若出现错误则提示用户列名错误并停止（未实现）
  ///    - 随后表头为列名，格式为横向
  /// 3. 根据表头、格式创建json
  ///
  /// 参数:
  /// - [specifiedColumns]: 用户指定的列名列表，如果为null或空则使用所有列
  ///
  /// 返回值:
  /// - 成功时返回包含表头和格式的JSON对象
  /// - 失败时返回错误信息
  static Future<String> fetchDatabaseHeaders([
    List<String>? specifiedColumns,
  ]) async {
    logger.i('开始获取数据库表头信息');

    try {
      final databaseService = DatabaseService();

      // 检查数据库配置是否完整
      if (!databaseService.isConfigValid()) {
        logger.w('数据库配置不完整');
        return json.encode({'error': '数据库配置不完整，请检查相关配置项'});
      }

      // 调用DatabaseService的fetchDatabaseHeaders方法获取表头
      final result = await databaseService.fetchDatabaseHeaders(
        specifiedColumns,
      );

      // 返回JSON格式的结果
      return json.encode(result);
    } catch (e, stackTrace) {
      logger.e('获取数据库表头时发生错误', e, stackTrace);
      return json.encode({'error': '获取数据库表头时发生错误: ${e.toString()}'});
    }
  }
}
