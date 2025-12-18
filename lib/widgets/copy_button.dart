import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import 'tooltip_overlay.dart';

class CopyButton extends StatefulWidget {
  final ChatMessage message;

  const CopyButton({super.key, required this.message});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _isHovered = false;
  bool _isCopying = false; // 防止重复点击的标志位

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          // 防止重复点击
          if (_isCopying) return;
          
          setState(() {
            _isCopying = true;
          });
          
          Clipboard.setData(ClipboardData(text: widget.message.text));
          // 显示复制成功提示
          TooltipUtil.showTooltip(
            '已复制到剪贴板',
            TooltipPosition.chatAreaCenter,
          );
          
          // 重置复制状态
          setState(() {
            _isCopying = false;
          });
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
}