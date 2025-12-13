import 'package:flutter/material.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/chat_message.dart';
import 'copy_button.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserMessage();
    } else {
      return _buildAIMessage(context);
    }
  }

  Widget _buildUserMessage() {
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
  }

  Widget _buildAIMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: _BubbleWithCopyButton(message: message),
          ),
        ],
      ),
    );
  }
}

// 将BubbleWithCopyButton移到这里以避免循环依赖
class _BubbleWithCopyButton extends StatefulWidget {
  final ChatMessage message;

  const _BubbleWithCopyButton({required this.message});

  @override
  State<_BubbleWithCopyButton> createState() => _BubbleWithCopyButtonState();
}

class _BubbleWithCopyButtonState extends State<_BubbleWithCopyButton> {
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
                        // 添加链接样式
                        a: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      // 添加自定义构建器以改善代码块选中效果
                      builders: {'code': _CodeElementBuilder()},
                      // 添加链接点击处理
                      onTapLink: (String url, String? title, String? text) async {
                        // 检查url是否是有效的URL，如果不是，尝试使用title
                        String actualUrl = url;
                        // 检查url是否包含有效的协议
                        bool isUrlValid = url.startsWith('http://') || url.startsWith('https://');
                        
                        // 如果url不是有效的URL，但title是有效的URL，则使用title
                        if (!isUrlValid && title != null && 
                            (title.startsWith('http://') || title.startsWith('https://'))) {
                          actualUrl = title;
                        }
                        
                        try {
                          // 首先尝试直接使用实际的URL
                          final uri = Uri.parse(actualUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                            return;
                          }
                        } catch (e) {
                          // 忽略首次解析错误
                        }
                        
                        try {
                          // 如果URL包含明显的协议，则尝试编码后解析
                          if (actualUrl.startsWith('http://') || actualUrl.startsWith('https://')) {
                            final encodedUrl = Uri.encodeFull(actualUrl);
                            final uri = Uri.parse(encodedUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                              return;
                            }
                          }
                        } catch (e) {
                          // 忽略编码后解析错误
                        }
                        
                        try {
                          // 如果URL看起来像一个域名（包含点号且不含空格等非法字符），则添加https协议
                          if (actualUrl.contains('.') && 
                              !actualUrl.contains(' ') && 
                              !actualUrl.contains('\n') &&
                              RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(actualUrl)) {
                            final fullUrl = 'https://$actualUrl';
                            final uri = Uri.parse(fullUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                              return;
                            }
                          }
                        } catch (e) {
                          // 忽略添加协议后解析错误
                        }
                      },

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
              opacity: _isHovering || _isButtonHovered ? 1.0 : 0.0, // 任一悬停条件满足时显示
              duration: const Duration(milliseconds: 150),
              child: CopyButton(message: widget.message),
            ),
          ),
        ),
      ],
    );
  }
}

// 自定义代码元素构建器，添加选中高亮效果
class _CodeElementBuilder extends MarkdownElementBuilder {
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