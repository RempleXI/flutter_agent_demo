import 'dart:async';
import 'package:mysql_client/mysql_client.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'config_service.dart';
import 'logger_service.dart';

/// 数据库服务类
/// 统一管理不同类型的数据库连接和基本操作
class DatabaseService {
  /// 创建DatabaseService的静态单例实例
  static final DatabaseService _instance = DatabaseService._internal();

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  /// 数据库配置信息
  late String _databaseUrl;
  late String _databaseUsername;
  late String _databasePassword;
  late String _databaseTableName;
  late String _databaseType;
  late String _databaseName;

  /// 初始化数据库服务
  Future<void> init() async {
    final configService = ExternalConfigService();

    _databaseUrl = configService.get('databaseUrl') as String? ?? '';
    _databaseUsername = configService.get('databaseUsername') as String? ?? '';
    _databasePassword = configService.get('databasePassword') as String? ?? '';
    _databaseTableName =
        configService.get('databaseTableName') as String? ?? '';
    _databaseType = configService.get('databaseType') as String? ?? '';
    _databaseName = configService.get('databaseName') as String? ?? '';

    logger.i('数据库服务初始化完成');
  }

  /// 检查数据库配置是否完整
  bool isConfigValid() {
    return _databaseUrl.isNotEmpty &&
        _databaseName.isNotEmpty &&
        _databaseType.isNotEmpty &&
        _databaseUsername.isNotEmpty &&
        _databasePassword.isNotEmpty &&
        _databaseTableName.isNotEmpty;
  }

  /// 获取数据库表的所有列名
  ///
  /// 根据数据库类型使用不同的实现方式：
  /// - MySQL: 使用 SHOW COLUMNS FROM `tableName` 命令
  /// - SQLite: 使用 PRAGMA table_info(tableName) 命令
  Future<List<String>> getTableColumns() async {
    logger.i('获取表 $_databaseTableName 的列名，数据库类型: $_databaseType');

    if (_databaseType.toLowerCase() == 'mysql') {
      return await _fetchMySQLColumns(_databaseTableName);
    } else if (_databaseType.toLowerCase() == 'sqlite') {
      return await _fetchSQLiteColumns(_databaseTableName);
    } else {
      throw Exception('不支持的数据库类型: $_databaseType');
    }
  }

  /// MySQL 获取表列名
  Future<List<String>> _fetchMySQLColumns(String tableName) async {
    logger.i('开始连接MySQL数据库: $_databaseUrl');

    // 解析数据库URL
    String host = 'localhost';
    int port = 3306;
    String? dbName = _databaseName.isNotEmpty ? _databaseName : null;

    if (_databaseUrl.startsWith('mysql://')) {
      final uri = Uri.parse(_databaseUrl);
      host = uri.host;
      port = uri.port;
      if (uri.pathSegments.isNotEmpty) {
        dbName = uri.pathSegments[0];
      }
    } else if (_databaseUrl.contains(':')) {
      final parts = _databaseUrl.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 3306;
    } else {
      host = _databaseUrl;
    }

    MySQLConnection? conn;
    try {
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: _databaseUsername,
        password: _databasePassword,
        databaseName: dbName,
        secure: false,
      );

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

  /// SQLite 获取表列名
  Future<List<String>> _fetchSQLiteColumns(String tableName) async {
    logger.i('开始连接SQLite数据库: $_databaseUrl');

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(_databaseUrl);
      logger.i('成功打开SQLite数据库');

      // 查询表的列信息
      final result = db.select('PRAGMA table_info(`$tableName`)');
      logger.i('查询到${result.length}个列');

      return result.map((row) => row[1] as String).toList();
    } on TimeoutException catch (e) {
      logger.e('SQLite操作超时', e);
      rethrow;
    } finally {
      if (db != null) {
        try {
          db.close();
          logger.i('关闭SQLite数据库连接');
        } catch (e) {
          logger.w('关闭SQLite数据库连接时发生错误: $e');
        }
      }
    }
  }

  /// 获取数据库表头信息
  ///
  /// 返回:
  /// - 成功时返回包含表头和格式的JSON对象
  /// - 失败时返回错误信息
  Future<Map<String, dynamic>> fetchDatabaseHeaders([
    List<String>? specifiedColumns,
  ]) async {
    try {
      logger.i(
        '数据库配置信息: URL=$_databaseUrl, Username=$_databaseUsername, TableName=$_databaseTableName, Type=$_databaseType, DatabaseName=$_databaseName',
      );

      // 检查必要配置是否存在
      if (_databaseUrl.isEmpty ||
          _databaseTableName.isEmpty ||
          _databaseType.isEmpty) {
        return {
          'error': '数据库配置不完整，请检查databaseUrl、databaseTableName和databaseType配置项',
        };
      }

      // 获取列名列表
      List<String> columns;
      if (_databaseType.toLowerCase() == 'mysql') {
        columns = await _fetchMySQLColumns(_databaseTableName);
      } else if (_databaseType.toLowerCase() == 'sqlite') {
        columns = await _fetchSQLiteColumns(_databaseTableName);
      } else {
        return {'error': '暂不支持的数据库类型: $_databaseType，目前支持 MySQL 和 SQLite'};
      }

      // 处理用户指定的列
      List<String> finalColumns;
      if (specifiedColumns != null && specifiedColumns.isNotEmpty) {
        // 检查用户指定的列是否都在实际列中
        final invalidColumns = specifiedColumns
            .where((col) => !columns.contains(col))
            .toList();
        if (invalidColumns.isNotEmpty) {
          return {'error': '指定的列名 "${invalidColumns.join(", ")}" 在表中不存在'};
        }
        finalColumns = specifiedColumns;
      } else {
        // 使用所有列
        finalColumns = columns;
      }

      // 构造返回的JSON对象
      return {
        'table': {'columns': finalColumns, 'format': 'horizontal'},
      };
    } catch (e, stackTrace) {
      logger.e('获取数据库表头时发生错误', e, stackTrace);
      return {'error': '获取表头时发生错误: ${e.toString()}'};
    }
  }

  /// 插入数据到表中
  Future<bool> insertData(
    Map<String, dynamic> data, [
    String? tableName,
  ]) async {
    final actualTableName = tableName ?? _databaseTableName;

    if (!isConfigValid()) {
      throw Exception('数据库配置不完整');
    }

    switch (_databaseType.toLowerCase()) {
      case 'mysql':
        return _insertMySQLData(data, actualTableName);

      case 'sqlite':
        return _insertSQLiteData(data, actualTableName);

      default:
        throw Exception('暂不支持的数据库类型: $_databaseType，目前支持 MySQL 和 SQLite');
    }
  }

  /// MySQL 插入数据
  Future<bool> _insertMySQLData(
    Map<String, dynamic> data,
    String tableName,
  ) async {
    logger.i('开始向MySQL数据库插入数据');

    // 解析数据库URL
    String host = 'localhost';
    int port = 3306;
    String? dbName = _databaseName.isNotEmpty ? _databaseName : null;

    if (_databaseUrl.startsWith('mysql://')) {
      final uri = Uri.parse(_databaseUrl);
      host = uri.host;
      port = uri.port;
      if (uri.pathSegments.isNotEmpty) {
        dbName = uri.pathSegments[0];
      }
    } else if (_databaseUrl.contains(':')) {
      final parts = _databaseUrl.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 3306;
    } else {
      host = _databaseUrl;
    }

    MySQLConnection? conn;
    try {
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: _databaseUsername,
        password: _databasePassword,
        databaseName: dbName,
        secure: false,
      );

      await conn.connect();
      logger.i('成功连接到MySQL数据库');

      // 构造 INSERT 语句
      final columns = data.keys.toList();
      final values = data.values.toList();
      final placeholders = List.filled(columns.length, '?').join(', ');
      final columnNames = columns.map((col) => '`$col`').join(', ');

      final sql =
          'INSERT INTO `$tableName` ($columnNames) VALUES ($placeholders)';
      logger.i('执行SQL: $sql');

      // 将values转换为Map<String, dynamic>格式
      final params = <String, dynamic>{};
      for (int i = 0; i < columns.length; i++) {
        params['${i + 1}'] = values[i];
      }

      final result = await conn.execute(sql, params);
      return result.affectedRows.toInt() > 0;
    } finally {
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

  /// SQLite 插入数据
  Future<bool> _insertSQLiteData(
    Map<String, dynamic> data,
    String tableName,
  ) async {
    logger.i('开始向SQLite数据库插入数据');

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(_databaseUrl);
      logger.i('成功打开SQLite数据库');

      // 构造 INSERT 语句
      final columns = data.keys.toList();
      // final values = data.values.toList();
      final placeholders = List.filled(columns.length, '?').join(', ');
      final columnNames = columns.map((col) => '`$col`').join(', ');

      final sql =
          'INSERT INTO `$tableName` ($columnNames) VALUES ($placeholders)';
      logger.i('执行SQL: $sql');

      final stmt = db.prepare(sql);
      final result = stmt.execute(data.values.toList());
      stmt.dispose();

      // 对于sqlite3，execute方法返回void，我们无法直接知道是否成功
      // 我们假设执行没有抛出异常即为成功
      return true;
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

  /// 执行 SELECT 查询
  Future<List<Map<String, dynamic>>> selectData({
    List<String>? columns,
    String? tableName,
    Map<String, dynamic>? whereConditions,
    int? limit,
  }) async {
    final actualTableName = tableName ?? _databaseTableName;

    if (!isConfigValid()) {
      throw Exception('数据库配置不完整');
    }

    switch (_databaseType.toLowerCase()) {
      case 'mysql':
        return _selectMySQLData(
          columns: columns,
          tableName: actualTableName,
          whereConditions: whereConditions,
          limit: limit,
        );

      case 'sqlite':
        return _selectSQLiteData(
          columns: columns,
          tableName: actualTableName,
          whereConditions: whereConditions,
          limit: limit,
        );

      default:
        throw Exception('暂不支持的数据库类型: $_databaseType，目前支持 MySQL 和 SQLite');
    }
  }

  /// MySQL SELECT 查询
  Future<List<Map<String, dynamic>>> _selectMySQLData({
    List<String>? columns,
    required String tableName,
    Map<String, dynamic>? whereConditions,
    int? limit,
  }) async {
    logger.i('开始执行MySQL SELECT 查询');

    // 解析数据库URL
    String host = 'localhost';
    int port = 3306;
    String? dbName = _databaseName.isNotEmpty ? _databaseName : null;

    if (_databaseUrl.startsWith('mysql://')) {
      final uri = Uri.parse(_databaseUrl);
      host = uri.host;
      port = uri.port;
      if (uri.pathSegments.isNotEmpty) {
        dbName = uri.pathSegments[0];
      }
    } else if (_databaseUrl.contains(':')) {
      final parts = _databaseUrl.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 3306;
    } else {
      host = _databaseUrl;
    }

    MySQLConnection? conn;
    try {
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: _databaseUsername,
        password: _databasePassword,
        databaseName: dbName,
        secure: false,
      );

      await conn.connect();
      logger.i('成功连接到MySQL数据库');

      // 构造 SELECT 语句
      final columnNames = columns != null && columns.isNotEmpty
          ? columns.map((col) => '`$col`').join(', ')
          : '*';

      var sql = 'SELECT $columnNames FROM `$tableName`';
      final whereValues = <String, dynamic>{};

      if (whereConditions != null && whereConditions.isNotEmpty) {
        final whereClause = whereConditions.keys
            .map((key) => '`$key` = ?')
            .join(' AND ');
        sql += ' WHERE $whereClause';

        // 将whereConditions转换为索引映射
        final keys = whereConditions.keys.toList();
        for (int i = 0; i < keys.length; i++) {
          whereValues['${i + 1}'] = whereConditions[keys[i]];
        }
      }

      if (limit != null && limit > 0) {
        sql += ' LIMIT $limit';
      }

      logger.i('执行SQL: $sql');

      final result = await conn.execute(sql, whereValues);

      // 将结果转换为 List<Map<String, dynamic>>
      final List<Map<String, dynamic>> rows = [];
      for (final row in result.rows) {
        final Map<String, dynamic> rowData = {};
        // 参考database_header_fetcher.dart中的做法，逐个访问列数据
        // 由于不知道确切的列数量和名称，我们只能通过已知的列名来访问
        // 这里假设最多处理10列数据，实际情况可能需要动态获取列数
        for (int i = 0; i < 10; i++) {
          try {
            rowData['col_$i'] = row.typedColAt(i);
          } catch (e) {
            // 当访问超出范围的列时会抛出异常，此时停止访问
            break;
          }
        }
        rows.add(rowData);
      }

      return rows;
    } finally {
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

  /// SQLite SELECT 查询
  Future<List<Map<String, dynamic>>> _selectSQLiteData({
    List<String>? columns,
    required String tableName,
    Map<String, dynamic>? whereConditions,
    int? limit,
  }) async {
    logger.i('开始执行SQLite SELECT 查询');

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(_databaseUrl);
      logger.i('成功打开SQLite数据库');

      // 构造 SELECT 语句
      final columnNames = columns != null && columns.isNotEmpty
          ? columns.map((col) => '`$col`').join(', ')
          : '*';

      var sql = 'SELECT $columnNames FROM `$tableName`';
      final List<dynamic> whereValues = [];

      if (whereConditions != null && whereConditions.isNotEmpty) {
        final whereClause = whereConditions.keys
            .map((key) => '`$key` = ?')
            .join(' AND ');
        sql += ' WHERE $whereClause';
        whereValues.addAll(whereConditions.values);
      }

      if (limit != null && limit > 0) {
        sql += ' LIMIT $limit';
      }

      logger.i('执行SQL: $sql');

      final stmt = db.prepare(sql);
      final resultSet = stmt.select(whereValues);
      stmt.dispose();

      // 将结果转换为 List<Map<String, dynamic>>
      final List<Map<String, dynamic>> rows = [];
      for (final row in resultSet) {
        final Map<String, dynamic> rowData = {};
        row.forEach((key, value) {
          rowData[key] = value;
        });
        rows.add(rowData);
      }

      return rows;
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

/// DatabaseHeaderFetcher适配器类
/// 提供与原来DatabaseHeaderFetcher类相同的静态接口
class DatabaseHeaderFetcher {
  /// 获取数据库表头信息的静态方法
  /// 与原来的DatabaseHeaderFetcher.fetchDatabaseHeaders方法具有相同的签名和行为
  static Future<Map<String, dynamic>> fetchDatabaseHeaders([
    List<String>? specifiedColumns,
  ]) async {
    final service = DatabaseService();
    await service.init();
    // 如果指定了列，则需要筛选
    if (specifiedColumns != null && specifiedColumns.isNotEmpty) {
      final allColumns = await service.getTableColumns();
      final invalidColumns = specifiedColumns
          .where((col) => !allColumns.contains(col))
          .toList();
      if (invalidColumns.isNotEmpty) {
        return {'error': '指定的列名 "${invalidColumns.join(", ")}" 在表中不存在'};
      }
      return {
        'table': {'columns': specifiedColumns, 'format': 'horizontal'},
      };
    }
    // 否则获取所有列
    final allColumns = await service.getTableColumns();
    return {
      'table': {'columns': allColumns, 'format': 'horizontal'},
    };
  }
}
