import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  runApp(const MyApp());
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

  // 发送消息到AI API
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
      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.modelName,
          'messages': [
            {'role': 'user', 'content': text},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add(ChatMessage(text: aiResponse, isUser: false));
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'API请求失败，状态码: ${response.statusCode}',
              isUser: false,
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: '抱歉，发生错误: $e', isUser: false));
      });
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _buildMessageItem(_messages[index]);
              },
            ),
          ),
          Padding(
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.isUser) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: SelectionArea(
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.normal,
                      // 减少字符间距，改善视觉效果
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // AI消息，添加复制按钮和支持Markdown渲染
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Flexible(child: BubbleWithCopyButton(message: message))],
        ),
      );
    }
  }
}

// 新增气泡和复制按钮组合组件
class BubbleWithCopyButton extends StatefulWidget {
  final ChatMessage message;

  const BubbleWithCopyButton({super.key, required this.message});

  @override
  State<BubbleWithCopyButton> createState() => _BubbleWithCopyButtonState();
}

class _BubbleWithCopyButtonState extends State<BubbleWithCopyButton> {
  bool _isHovering = false;
  bool _isButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 整个区域包括气泡和右侧扩展区域
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 消息气泡 - 使用Flexible而不是Expanded以适应内容宽度
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: SelectionArea(
                    child: MarkdownBody(
                      data: widget.message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.normal,
                          // 减少字符间距，改善视觉效果
                          letterSpacing: 0.5,
                        ),
                        code: const TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 14.0,
                          color: Colors.black,
                        ),
                        codeblockPadding: const EdgeInsets.all(8.0),
                        codeblockDecoration: BoxDecoration(
                          color: Color(0xFFCCCCCC),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      // 添加自定义构建器以改善代码块选中效果
                      builders: {'code': CodeElementBuilder()},
                    ),
                  ),
                ),
              ),
              // 右侧扩展区域，增加鼠标检测范围
              Container(
                width: 40, // 增加到40像素以提高可检测性
                height: 60,
                color: Colors.transparent, // 透明区域用于扩大检测范围
              ),
            ],
          ),
        ),
        // 复制按钮放置在右下角
        Positioned(
          right: 5, // 微调位置
          bottom: 5,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isButtonHovered = true),
            onExit: (_) => setState(() => _isButtonHovered = false),
            child: AnimatedOpacity(
              opacity: _isHovering || _isButtonHovered
                  ? 1.0
                  : 0.0, // 任一悬停条件满足时显示
              duration: const Duration(milliseconds: 150),
              child: _CopyButton(message: widget.message),
            ),
          ),
        ),
      ],
    );
  }
}

// 独立的复制按钮组件
class _CopyButton extends StatefulWidget {
  final ChatMessage message;

  const _CopyButton({required this.message});

  @override
  State<_CopyButton> createState() => __CopyButtonState();
}

class __CopyButtonState extends State<_CopyButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150), // 使用推荐的150ms
      vsync: this,
    );
    
    // 创建透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.message.text));
          
          // 显示淡入淡出提示
          _showCopySuccessToast();
        },
        child: Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            color: _isHovered ? Colors.grey[600] : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.copy,
            size: 16,
            color: _isHovered ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
  
  // 显示复制成功提示动画
  void _showCopySuccessToast() {
    // 移除之前的overlay
    _overlayEntry?.remove();
    
    // 创建新的overlay
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    
    // 淡入动画
    _controller.forward().then((_) {
      // 停留一段时间
      return Future.delayed(const Duration(milliseconds: 800)); // 缩短提示时间至800ms
    }).then((_) {
      // 淡出动画
      return _controller.reverse();
    }).then((_) {
      // 动画完成后移除overlay
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
  
  // 创建OverlayEntry
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        // 定位在屏幕底部中央
        bottom: 100,
        left: MediaQuery.of(context).size.width * 0.5 - 75, // 居中 (150/2)
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            width: 150, // 设置提示宽度为胶囊状
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20), // 胶囊形状
            ),
            child: const Text(
              '已复制到剪贴板',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none, // 移除下划线
                fontFamily: '等线', // 使用等线字体
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

// 自定义代码元素构建器，添加选中高亮效果
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        // 移除背景色，让选中高亮可见
      ),
      child: Text(
        element.textContent,
        style: const TextStyle(
          fontFamily: 'Courier New',
          fontSize: 14.0,
          color: Colors.black,
        ),
      ),
    );
  }
}
