// API配置文件示例
// 复制此文件并重命名为config.dart，然后填入您的API密钥

class ApiConfig {
  // 硅基流动(SiliconFlow) API密钥
  // 从 https://cloud.siliconflow.cn/ 获取
  static const String siliconFlowApiKey = 'YOUR_SILICON_FLOW_API_KEY_HERE';

  // 硅基流动API基础URL
  static const String siliconFlowBaseUrl =
      'https://api.siliconflow.cn/v1/chat/completions';

  // 主AI使用的模型
  static const String primaryModelName = 'deepseek-ai/DeepSeek-V3.2';
  
  // 副AI使用的模型（用于工具调用决策）
  static const String secondaryModelName = 'Qwen/Qwen2.5-7B-Instruct';
}
