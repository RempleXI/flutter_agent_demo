class ApiConfig {
  // 硅基流动(SiliconFlow) API密钥
  // 从 https://cloud.siliconflow.cn/ 获取
  static const String siliconFlowApiKey =
      'YOUR_SILICON_FLOW_API_KEY_HERE';

  // 硅基流动API基础URL
  static const String siliconFlowBaseUrl =
      'https://api.siliconflow.cn/v1/chat/completions';

  // 对话AI模型
  static const String chatModelName = 'deepseek-ai/DeepSeek-V3.2';
  
  // 决策AI模型（用于工具调用决策）
  static const String decisionModelName = 'Qwen/Qwen2.5-7B-Instruct';
  
  // 分析AI模型（用于字段提取等分析任务）
  static const String analysisModelName = 'deepseek-ai/DeepSeek-V3.2';
}