import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';

/// 外部配置服务
/// 使用path_provider管理外部配置文件，使配置可以在部署后修改
class ExternalConfigService {
  static final ExternalConfigService _instance =
      ExternalConfigService._internal();
  factory ExternalConfigService() => _instance;
  ExternalConfigService._internal();

  // 配置文件名
  static const String _configFileName = 'app_config.json';

  // 配置数据
  Map<String, dynamic> _config = {};

  /// 初始化配置服务
  Future<void> init() async {
    await _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final configFile = await _getConfigFile();
      if (await configFile.exists()) {
        final jsonString = await configFile.readAsString();
        _config = jsonDecode(jsonString);
        logger.i('配置文件加载成功: ${configFile.path}');
      } else {
        // 如果配置文件不存在，创建默认配置
        await _createDefaultConfig(configFile);
        logger.i('创建默认配置文件: ${configFile.path}');
      }
    } catch (e) {
      logger.e('加载配置文件时出错', e);
      // 出错时使用默认配置
      _config = _getDefaultConfig();
    }
  }

  /// 获取配置文件
  Future<File> _getConfigFile() async {
    final directory = await getApplicationSupportDirectory();
    final configFile = File(path.join(directory.path, _configFileName));
    return configFile;
  }

  /// 创建默认配置
  Future<void> _createDefaultConfig(File configFile) async {
    _config = _getDefaultConfig();
    await _saveConfigToFile(configFile);
  }

  /// 获取默认配置
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'siliconFlowApiKey': '',
      'siliconFlowBaseUrl': 'https://api.siliconflow.cn/v1/chat/completions',
      'chatModelName': 'deepseek-ai/DeepSeek-V3.2',
      'decisionModelName': 'Qwen/Qwen2.5-7B-Instruct',
      'analysisModelName': 'deepseek-ai/DeepSeek-V3.2',
      // 数据库配置
      'databaseUrl': '',
      'databaseUsername': '',
      'databasePassword': '',
      'databaseTableName': '',
      'databaseType': '',
      'databaseName': '',
    };
  }

  /// 保存配置到文件
  Future<void> _saveConfigToFile(File configFile) async {
    await configFile.create(recursive: true);
    final jsonString = jsonEncode(_config);
    await configFile.writeAsString(jsonString);
  }

  /// 获取配置值
  dynamic get(String key) {
    return _config[key];
  }

  /// 设置配置值
  Future<void> set(String key, dynamic value) async {
    _config[key] = value;
    final configFile = await _getConfigFile();
    await _saveConfigToFile(configFile);
  }

  /// 批量更新配置
  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    _config.addAll(newConfig);
    final configFile = await _getConfigFile();
    await _saveConfigToFile(configFile);
  }

  /// 获取所有配置
  Map<String, dynamic> getAllConfig() {
    return Map<String, dynamic>.from(_config);
  }

  /// 检查API密钥是否已设置
  bool isApiKeySet() {
    final apiKey = get('siliconFlowApiKey');
    return apiKey != null && apiKey.isNotEmpty;
  }
}
