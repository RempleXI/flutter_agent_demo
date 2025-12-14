import 'package:flutter/material.dart';
import 'widgets/chat_message_item.dart';
import 'models/chat_message.dart';
import 'services/api_service.dart';
import 'widgets/file_section.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'tools/tool_manager.dart';
import 'ai_config.dart';
import 'services/tool_decision_service.dart';

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
      final shouldCallTool = await ToolDecisionService.shouldCallTool(text);

      ToolType toolType = ToolManager.analyzeMessage(text);
      if (shouldCallTool && toolType == ToolType.none) {
        toolType = ToolType.document;
      }

      String? toolResult;
      String? toolName;
      bool needRefresh = false;
      if (toolType != ToolType.none) {
        // 添加工具调用提示消息
        setState(() {
          _messages.add(
            ChatMessage(
              text: '正在调用"${ToolResult(toolType: toolType).toolName}"工具...',
              isUser: false,
              isToolCall: true,
            ),
          );
        });

        // 执行工具调用
        toolResult = await ToolManager.executeTool(toolType, text);
        toolName = ToolResult(toolType: toolType).toolName;
        
        // 检查是否需要刷新界面（特别是表格填充工具执行后）
        if (toolType == ToolType.tableFill || toolType == ToolType.directoryView) {
          needRefresh = true;
        }
        
        // 将工具执行结果作为系统消息发送给AI（但对于目录查看工具，显示简化的消息）
        if (toolResult != null) {
          String displayMessage = toolResult;
          if (toolType == ToolType.directoryView) {
            displayMessage = "已完成目录查看";
          }
          
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
      }

      // 将工具结果加入到AI请求中
      String finalText = text;
      if (toolResult != null) {
        finalText = "工具执行结果 ($toolName):\n$toolResult\n\n用户原始问题: $text";
      }

      // 获取AI回复
      final aiMessage = await ApiService.sendMessage(finalText);

      if (aiMessage != null) {
        setState(() {
          _messages.add(aiMessage);
        });
      }
      
      // 如果需要刷新界面，则刷新所有区域
      if (needRefresh) {
        _refreshAllSections();
      }
    } finally {
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