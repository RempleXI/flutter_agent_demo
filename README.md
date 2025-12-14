# flutter_agent_demo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## 配置 API 密钥

要使用此应用程序，您需要配置硅基流动(SiliconFlow)的API密钥：

1. 复制 `lib/config_example.dart` 文件并将其重命名为 `lib/config.dart`
2. 在 [硅基流动平台](https://cloud.siliconflow.cn/) 获取您的API密钥
3. 将 `config.dart` 文件中的 `YOUR_SILICON_FLOW_API_KEY_HERE` 替换为您的实际API密钥

注意：`config.dart` 文件已被添加到 `.gitignore` 中，以防止意外提交到版本控制系统。

## 双AI机制配置

本项目采用了双AI机制来提高工具调用决策的准确性：

- **主AI模型** (`primaryModelName`)：负责主要的对话和回答生成
- **副AI模型** (`secondaryModelName`)：专门用于判断是否需要调用外部工具

两个模型都可以在 `lib/config.dart` 文件中配置。默认情况下，我们使用 DeepSeek-V3.2 作为主模型，Qwen2.5-7B-Instruct 作为副模型。

## Resources

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.