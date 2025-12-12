import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

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
        // 设置默认字体为黑体，确保中文显示正常
        fontFamily: 'Helvetica Neue',
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
  bool _isLoading = false;

  // 发送消息到AI API
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isLoading = true;
    });

    try {
      // 使用硅基流动(SiliconFlow)的DeepSeek API
      final response = await http.post(
        Uri.parse(ApiConfig.siliconFlowBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${ApiConfig.siliconFlowApiKey}',
        },
        body: jsonEncode({
          'model': ApiConfig.modelName,
          'messages': [
            {'role': 'user', 'content': text}
          ],
          'stream': false
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
          _messages.add(ChatMessage(text: 'API请求失败，状态码: ${response.statusCode}', isUser: false));
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
    }
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
                              color: Colors.blue,
                              width: 2.0,
                            ),
                          ),
                          child: const Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 10),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.blue[100] : Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
