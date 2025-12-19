import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../services/config_service.dart';
import '../services/logger_service.dart';

/// 数据库表头获取工具类
/// 用于从真实数据库中获取表的列名信息
class DatabaseHeaderFetcher {
  /// 从数据库获取表头信息
  ///
  /// 参数:
  /// - specifiedColumns: 用户指定的列名列表（可选）
  ///
  /// 返回:
  /// - 成功时返回包含表头和格式的JSON对象
  /// - 失败时返回错误信息
  static Future<Map<String, dynamic>> fetchDatabaseHeaders([List<String>? specifiedColumns]) async {
    try {
      // 1. 获取数据库配置
      final configService = ExternalConfigService();
      
      final databaseUrl = configService.get('databaseUrl') as String? ?? '';
      final databaseUsername = configService.get('databaseUsername') as String? ?? '';
      final databasePassword = configService.get('databasePassword') as String? ?? '';
      final databaseTableName = configService.get('databaseTableName') as String? ?? '';
      final databaseType = configService.get('databaseType') as String? ?? '';
      final databaseName = configService.get('databaseName') as String? ?? '';

      logger.i('数据库配置信息: URL=$databaseUrl, Username=$databaseUsername, TableName=$databaseTableName, Type=$databaseType, DatabaseName=$databaseName');

      // 检查必要配置是否存在
      if (databaseUrl.isEmpty || databaseTableName.isEmpty || databaseType.isEmpty) {
        return {
          'error': '数据库配置不完整，请检查databaseUrl、databaseTableName和databaseType配置项'
        };
      }

      // 获取列名列表
      List<String> columns;
      switch (databaseType.toLowerCase()) {
        case 'mysql':
          columns = await _fetchMySQLColumns(
            databaseUrl, 
            databaseUsername, 
            databasePassword, 
            databaseName,
            databaseTableName
          );
          break;
          
        case 'sqlite':
          columns = await _fetchSQLiteColumns(databaseUrl, databaseTableName);
          break;
          
        default:
          return {
            'error': '暂不支持的数据库类型: $databaseType，目前支持 MySQL 和 SQLite'
          };
      }

      // 处理用户指定的列
      List<String> finalColumns;
      if (specifiedColumns != null && specifiedColumns.isNotEmpty) {
        // 检查用户指定的列是否都在实际列中
        final invalidColumns = specifiedColumns.where((col) => !columns.contains(col)).toList();
        if (invalidColumns.isNotEmpty) {
          return {
            'error': '指定的列名 "${invalidColumns.join(", ")}" 在表中不存在'
          };
        }
        finalColumns = specifiedColumns;
      } else {
        // 使用所有列
        finalColumns = columns;
      }

      // 构造返回的JSON对象
      return {
        'table': {
          'columns': finalColumns,
          'format': 'horizontal'
        }
      };
    } catch (e, stackTrace) {
      logger.e('获取数据库表头时发生错误', e, stackTrace);
      return {
        'error': '获取表头时发生错误: ${e.toString()}'
      };
    }
  }

  /// 获取 MySQL 数据库表列名
  static Future<List<String>> _fetchMySQLColumns(
    String url, 
    String username, 
    String password, 
    String databaseName,
    String tableName
  ) async {
    logger.i('开始连接MySQL数据库: $url');
    
    // 解析数据库URL
    String host = 'localhost';
    int port = 3306;
    String? dbName = databaseName.isNotEmpty ? databaseName : null;
    
    // 处理URL格式
    if (url.startsWith('mysql://')) {
      // 完整URL格式: mysql://host:port/database_name
      final uri = Uri.parse(url);
      host = uri.host;
      port = uri.port;
      if (uri.pathSegments.isNotEmpty) {
        dbName = uri.pathSegments[0];
      }
    } else if (url.contains(':')) {
      // 简单格式: host:port
      final parts = url.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 3306;
    } else {
      // 只有主机名
      host = url;
    }
    
    logger.i('解析后的连接信息: host=$host, port=$port, database=$dbName');
    
    MySQLConnection? conn;
    try {
      // 使用mysql_client库连接数据库
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: username,
        password: password,
        databaseName: dbName,
        secure: false,  // 不使用SSL连接
      );

      logger.i('MySQL连接配置: host=$host, port=$port, user=$username, db=$dbName');

      // 连接数据库
      await conn.connect();
      logger.i('成功连接到MySQL数据库');
      
      // 执行查询
      final result = await conn.execute('SHOW COLUMNS FROM `$tableName`');
      logger.i('查询成功，查询到${result.numOfRows}个列');
      
      // 提取列名
      final columns = <String>[];
      for (final row in result.rows) {
        columns.add(row.typedColAt(0) as String);
      }
      
      return columns;
    } on Exception catch (e) {
      logger.e('MySQL查询错误', e);
      rethrow;
    } finally {
      // 确保连接被正确关闭
      if (conn != null && conn.connected) {
        try {
          await conn.close();
          logger.i('关闭MySQL数据库连接');
        } catch (e) {
          logger.w('关闭MySQL数据库连接时发生错误: $e');
        }
      }
    }
  }

  /// 获取 SQLite 数据库表列名
  static Future<List<String>> _fetchSQLiteColumns(String dbPath, String tableName) async {
    logger.i('开始连接SQLite数据库: $dbPath');
    
    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(dbPath);
      logger.i('成功打开SQLite数据库');
      
      // 查询表的列信息
      final result = db.select(
        'PRAGMA table_info(`$tableName`)', 
      );
      
      logger.i('查询到${result.length}个列');

      return result.map((row) => row['name'] as String).toList();
    } on TimeoutException catch (e) {
      logger.e('SQLite操作超时', e);
      rethrow;
    } finally {
      if (db != null) {
        try {
          db.dispose();
          logger.i('关闭SQLite数据库连接');
        } catch (e) {
          logger.w('关闭SQLite数据库连接时发生错误: $e');
        }
      }
    }
  }
}