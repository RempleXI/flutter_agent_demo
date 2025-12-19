import 'package:flutter/material.dart';
import '../services/config_service.dart';
import 'tooltip_overlay.dart';

class ConfigDialog extends StatefulWidget {
  const ConfigDialog({super.key});

  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _chatModelController;
  late TextEditingController _decisionModelController;
  late TextEditingController _analysisModelController;
  // 数据库配置控制器
  late TextEditingController _databaseUrlController;
  late TextEditingController _databaseUsernameController;
  late TextEditingController _databasePasswordController;
  late TextEditingController _databaseNameController;
  late TextEditingController _databaseTableNameController;
  late TextEditingController _databaseTypeController;

  // 防止重复提交的标志位
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final configService = ExternalConfigService();
    setState(() {
      _apiKeyController = TextEditingController(
        text: configService.get('siliconFlowApiKey') ?? '',
      );
      _baseUrlController = TextEditingController(
        text:
            configService.get('siliconFlowBaseUrl') ??
            'https://api.siliconflow.cn/v1/chat/completions',
      );
      _chatModelController = TextEditingController(
        text: configService.get('chatModelName') ?? 'deepseek-ai/DeepSeek-V3.2',
      );
      _decisionModelController = TextEditingController(
        text:
            configService.get('decisionModelName') ??
            'Qwen/Qwen2.5-7B-Instruct',
      );
      _analysisModelController = TextEditingController(
        text:
            configService.get('analysisModelName') ??
            'deepseek-ai/DeepSeek-V3.2',
      );
      // 数据库配置
      _databaseUrlController = TextEditingController(
        text: configService.get('databaseUrl') ?? '',
      );
      _databaseUsernameController = TextEditingController(
        text: configService.get('databaseUsername') ?? '',
      );
      _databasePasswordController = TextEditingController(
        text: configService.get('databasePassword') ?? '',
      );
      _databaseNameController = TextEditingController(
        text: configService.get('databaseName') ?? '',
      );
      _databaseTableNameController = TextEditingController(
        text: configService.get('databaseTableName') ?? '',
      );
      _databaseTypeController = TextEditingController(
        text: configService.get('databaseType') ?? '',
      );
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _chatModelController.dispose();
    _decisionModelController.dispose();
    _analysisModelController.dispose();
    // 释放数据库配置控制器资源
    _databaseUrlController.dispose();
    _databaseUsernameController.dispose();
    _databasePasswordController.dispose();
    _databaseNameController.dispose();
    _databaseTableNameController.dispose();
    _databaseTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    // 防止重复提交
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final configService = ExternalConfigService();
      await configService.updateConfig({
        'siliconFlowApiKey': _apiKeyController.text,
        'siliconFlowBaseUrl': _baseUrlController.text,
        'chatModelName': _chatModelController.text,
        'decisionModelName': _decisionModelController.text,
        'analysisModelName': _analysisModelController.text,
        // 数据库配置
        'databaseUrl': _databaseUrlController.text,
        'databaseUsername': _databaseUsernameController.text,
        'databasePassword': _databasePasswordController.text,
        'databaseName': _databaseNameController.text,
        'databaseTableName': _databaseTableNameController.text,
        'databaseType': _databaseTypeController.text,
      });

      if (mounted) {
        Navigator.of(context).pop(true); // 返回true表示配置已保存
        // 显示配置保存成功提示
        WidgetsBinding.instance.addPostFrameCallback((_) {
          TooltipUtil.showTooltip('配置已保存', TooltipPosition.windowCenter);
        });
      }

      // 保存完成后重置状态
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配置'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AI API配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'SiliconFlow API Key *',
                    hintText: '请输入您的 SiliconFlow API 密钥',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入 API 密钥';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'API 基础地址',
                  ),
                ),
                TextFormField(
                  controller: _chatModelController,
                  decoration: const InputDecoration(
                    labelText: '对话模型名称',
                    hintText: '用于主要对话的 AI 模型',
                  ),
                ),
                TextFormField(
                  controller: _decisionModelController,
                  decoration: const InputDecoration(
                    labelText: '决策模型名称',
                    hintText: '用于工具调用决策的 AI 模型',
                  ),
                ),
                TextFormField(
                  controller: _analysisModelController,
                  decoration: const InputDecoration(
                    labelText: '分析模型名称',
                    hintText: '用于字段提取等分析任务的 AI 模型',
                  ),
                ),

                // 数据库配置项
                const Divider(
                  height: 32,
                  thickness: 1,
                  indent: 0,
                  endIndent: 0,
                  color: Colors.deepPurple,
                ),
                const Text(
                  '数据库配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  controller: _databaseUrlController,
                  decoration: const InputDecoration(
                    labelText: '数据库 URL',
                    hintText: '例如: localhost:3306',
                  ),
                ),
                TextFormField(
                  controller: _databaseUsernameController,
                  decoration: const InputDecoration(
                    labelText: '数据库用户名',
                    hintText: '登录数据库的用户名',
                  ),
                ),
                TextFormField(
                  controller: _databasePasswordController,
                  decoration: const InputDecoration(
                    labelText: '数据库密码',
                    hintText: '登录数据库的密码',
                  ),
                  obscureText: true,
                ),
                TextFormField(
                  controller: _databaseNameController,
                  decoration: const InputDecoration(
                    labelText: '数据库名',
                    hintText: '要连接的数据库名称',
                  ),
                ),
                TextFormField(
                  controller: _databaseTableNameController,
                  decoration: const InputDecoration(
                    labelText: '表名',
                    hintText: '要操作的数据表名称',
                  ),
                ),
                TextFormField(
                  controller: _databaseTypeController,
                  decoration: const InputDecoration(
                    labelText: '数据库类型',
                    hintText: '例如: mysql, postgresql',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _saveConfig, child: const Text('保存')),
      ],
    );
  }
}
