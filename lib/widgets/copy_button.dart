import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';

class CopyButton extends StatefulWidget {
  final ChatMessage message;

  const CopyButton({super.key, required this.message});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> with SingleTickerProviderStateMixin {
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