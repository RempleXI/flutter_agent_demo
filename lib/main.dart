import 'package:flutter/material.dart';
import 'widgets/chat_message_item.dart';
import 'models/chat_message.dart';
import 'services/api_service.dart';
import 'widgets/file_section.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'services/tool_decision_service.dart';
import 'ai_config.dart';
import 'services/config_service.dart';
import 'widgets/config_dialog.dart';

void main() {
  runApp(const MyApp());

  // 设置窗口属性
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(1024, 768);
    win.minSize = initialSize;
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "AI Chat Demo";
    win.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        // 使用等线字体
        fontFamily: '等线',
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'AI Chat Interface'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _isLoading = false;

  // 为每个区域创建 GlobalKey
  final GlobalKey<FileSectionState> _waitingSectionKey = GlobalKey();
  final GlobalKey<FileSectionState> _readSectionKey = GlobalKey();
  final GlobalKey<FileSectionState> _templateSectionKey = GlobalKey();
  final GlobalKey<FileSectionState> _resultSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initConfig().then((_) {
      // 初始化完成后自动开始新对话
      _resetChat();
    });
  }

  Future<void> _initConfig() async {
    final configService = ExternalConfigService();
    await configService.init();

    // 检查API密钥是否已设置
    if (!configService.isApiKeySet() && mounted) {
      _showConfigDialog();
    }
  }

  Future<void> _showConfigDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const ConfigDialog();
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  // 发送消息
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isLoading = true;
    });

    // 滚动到最新消息
    _scrollToBottom();

    try {
      // 使用双AI机制判断是否需要调用工具
      print('开始工具决策过程');
      final toolInfo = await ToolDecisionService.shouldCallTool(text);
      print('工具决策结果: 类别=${toolInfo.category}, 具体工具=${toolInfo.specificTool}');

      String? toolResult;
      String? toolName;
      bool needRefresh = false;
      if (toolInfo.category != ToolCategory.none) {
        print('检测到需要调用工具: ${toolInfo.displayName}');
        // 添加工具调用提示消息（显示通用类别名称）
        setState(() {
          _messages.add(
            ChatMessage(
              text: '正在调用${toolInfo.displayName}工具',
              isUser: false,
              isToolCall: true,
            ),
          );
        });

        // 执行工具调用
        print('开始执行工具: ${toolInfo.specificToolName}');
        toolResult = await ToolDecisionService.executeTool(toolInfo, text);
        toolName = toolInfo.displayName;
        print('工具执行结果: $toolResult');

        // 检查是否需要刷新界面
        if (toolInfo.specificTool == SpecificTool.tableFill ||
            toolInfo.specificTool == SpecificTool.directoryView) {
          needRefresh = true;
        }

        // 工具执行完成提示消息（显示具体工具名称）
        if (toolResult != null) {
          String displayMessage = '已执行${toolInfo.specificToolName}操作';

          setState(() {
            _messages.add(
              ChatMessage(
                text: displayMessage,
                isUser: false,
                isToolCall: true,
              ),
            );
          });
        }
      } else {
        print('未检测到需要调用的工具');
      }

      // 将工具结果加入到AI请求中
      String finalText = text;
      if (toolResult != null) {
        finalText = "工具执行结果 ($toolName):\n$toolResult\n\n用户原始问题: $text";
      }

      // 获取AI回复（传递对话历史）
      print('开始获取AI回复');
      final aiMessage = await ApiService.sendMessage(
        finalText,
        List.unmodifiable(_messages),
      );
      print('AI回复获取完成');

      if (aiMessage != null) {
        setState(() {
          _messages.add(aiMessage);
        });
      }

      // 如果需要刷新界面，则刷新所有区域
      if (needRefresh) {
        print('刷新文件区域界面');
        _refreshAllSections();
      }
    } catch (e, stackTrace) {
      print('处理消息时发生错误: $e');
      print('错误堆栈: $stackTrace');
      // 添加错误消息到聊天界面
      setState(() {
        _messages.add(ChatMessage(text: '处理您的请求时发生了错误，请稍后重试。', isUser: false));
      });
    } finally {
      print('设置加载状态为false');
      setState(() {
        _isLoading = false;
      });
      // AI回复后再次滚动到底部
      _scrollToBottom();

      // 发送消息后焦点回到输入框
      FocusScope.of(context).requestFocus(_textFieldFocusNode);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _refreshAllSections() {
    // 调用每个区域的刷新方法
    [
          _waitingSectionKey,
          _readSectionKey,
          _templateSectionKey,
          _resultSectionKey,
        ]
        .map((key) => key.currentState)
        .whereType<FileSectionState>()
        .forEach((state) => state.refreshFiles());
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
    });

    // 显示新对话开始的提示消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages.add(
          ChatMessage(text: '您好！我是您的AI智能文档助手，有什么我可以帮您的吗？', isUser: false),
        );
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllSections,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _resetChat,
            tooltip: '新对话',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
            tooltip: '配置',
          ),
        ],
      ),
      body: Container(
        constraints: const BoxConstraints(minWidth: 1024, minHeight: 768),
        child: Row(
          children: [
            // 左侧四个区域 - 分为上下两排，每排两个区域
            Expanded(flex: 1, child: _buildLeftPanel()),
            // 右侧聊天区域
            Expanded(flex: 1, child: _buildChatPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        // 上排两个区域
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Expanded(
                child: FileSection(
                  key: _waitingSectionKey,
                  title: '等待',
                  onFilesChanged: _refreshAllSections,
                ),
              ),
              Expanded(
                child: FileSection(
                  key: _readSectionKey,
                  title: '读取',
                  onFilesChanged: _refreshAllSections,
                ),
              ),
            ],
          ),
        ),
        // 下排两个区域
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Expanded(
                child: FileSection(
                  key: _templateSectionKey,
                  title: '模板',
                  onFilesChanged: _refreshAllSections,
                ),
              ),
              Expanded(
                child: FileSection(
                  key: _resultSectionKey,
                  title: '结果',
                  onFilesChanged: _refreshAllSections,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) {
                return _buildLoadingIndicator();
              }
              return ChatMessageItem(message: _messages[index]);
            },
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color.fromARGB(255, 177, 197, 213),
                width: 2.0,
              ),
            ),
            child: const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 5),
                Text(
                  'AI正在思考...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _textFieldFocusNode,
              controller: _textController,
              decoration: const InputDecoration(
                hintText: '请输入您的问题...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            onPressed: () => _sendMessage(_textController.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
