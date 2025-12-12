// API配置文件示例
// 复制此文件并重命名为config.dart，然后填入您的API密钥

class ApiConfig {
  // 硅基流动(SiliconFlow) API密钥
  // 从 https://cloud.siliconflow.cn/ 获取
  static const String siliconFlowApiKey = 'YOUR_SILICON_FLOW_API_KEY_HERE';
  
  // 硅基流动API基础URL
  static const String siliconFlowBaseUrl = 'https://api.siliconflow.cn/v1/chat/completions';
  
  // 使用的模型
  static const String modelName = 'deepseek-ai/DeepSeek-V3.2';
}