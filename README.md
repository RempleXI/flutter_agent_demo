# flutter_agent_demo

## 项目简介

这是一个基于 Flutter 开发的 AI 助手演示项目，专注于文档处理任务。该应用集成了多种 AI 工具，能够处理文档、管理文件、填充表格等多种功能。通过三级 AI 机制，系统能够智能地判断用户需求并调用适当的工具来完成任务。

## 核心功能

### 1. 文档处理

- 格式转换：支持多种文档格式之间的相互转换
- 内容总结：自动生成文档摘要和关键信息提取
- 自动填表：根据文档内容自动填充 Excel 表格
- 自动入库：将处理后的数据自动存储到数据库

### 2. 文件管理

- 删除文件：安全删除指定文件或文件夹
- 查看目录：浏览工作区的文件结构和信息
- 移动文件：在不同目录间移动文件或文件夹
- 复制文件：创建文件或文件夹的副本
- 重命名文件：修改文件或文件夹名称

### 3. 智能 AI 交互

- 三级 AI 机制：针对不同类型的任务使用专门优化的 AI 模型
- 工具调用：根据用户需求智能调用相应工具
- 实时反馈：提供清晰的工具调用状态和结果反馈

## Getting Started

This project is a starting point for a Flutter application.

## 配置 API 密钥

要使用此应用程序，您需要配置硅基流动(SiliconFlow)的 API 密钥：

1. 复制 `lib/config_example.dart` 文件并将其重命名为 `lib/config.dart`
2. 在 [硅基流动平台](https://cloud.siliconflow.cn/) 获取您的 API 密钥
3. 将 `config.dart` 文件中的 `YOUR_SILICON_FLOW_API_KEY_HERE` 替换为您的实际 API 密钥

注意：`config.dart` 文件已被添加到 `.gitignore` 中，以防止意外提交到版本控制系统。

## 三 AI 机制配置

本项目采用了三 AI 机制来提高不同任务的处理效率和准确性：

- **对话 AI 模型** (`chatModelName`)：负责主要的对话和回答生成
- **决策 AI 模型** (`decisionModelName`)：专门用于判断是否需要调用外部工具
- **分析 AI 模型** (`analysisModelName`)：专门用于字段提取等分析任务

三个模型都可以在 `lib/config.dart` 文件中配置。默认情况下，我们使用 DeepSeek-V3.2 作为对话和分析模型，Qwen2.5-7B-Instruct 作为决策模型。

## Resources

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
