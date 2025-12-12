import 'package:flutter/material.dart';
import 'widgets/chat_message_item.dart';
import 'models/chat_message.dart';
import 'services/api_service.dart';

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
      final aiMessage = await ApiService.sendMessage(text);
      if (aiMessage != null) {
        setState(() {
          _messages.add(aiMessage);
        });
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
                  return _buildLoadingIndicator();
                }
                return ChatMessageItem(message: _messages[index]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
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
