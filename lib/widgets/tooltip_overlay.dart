import 'package:flutter/material.dart';

/// 提示位置枚举
enum TooltipPosition {
  /// 文件区中央
  fileAreaCenter,

  /// 对话区中央
  chatAreaCenter,

  /// 总窗口中央
  windowCenter,
}

/// 提示信息类
class TooltipInfo {
  final String message;
  final TooltipPosition position;
  final DateTime timestamp;

  TooltipInfo({
    required this.message,
    required this.position,
    required this.timestamp,
  });
}

/// 全局提示覆盖层组件
class TooltipOverlay extends StatefulWidget {
  final Widget child;

  const TooltipOverlay({super.key, required this.child});

  @override
  State<TooltipOverlay> createState() => _TooltipOverlayState();

  /// 显示提示的静态方法
  static void showTooltip(String message, TooltipPosition position) {
    _TooltipOverlayState.showTooltip(message, position);
  }
}

class _TooltipOverlayState extends State<TooltipOverlay>
    with TickerProviderStateMixin {
  static final List<TooltipInfo> _tooltips = [];
  static _TooltipOverlayState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    _instance = null;
    super.dispose();
  }

  /// 显示提示
  static void showTooltip(String message, TooltipPosition position) {
    if (_instance != null && _instance!.mounted) {
      _instance!.setState(() {
        _tooltips.add(
          TooltipInfo(
            message: message,
            position: position,
            timestamp: DateTime.now(),
          ),
        );
      });

      // 2秒后自动移除提示
      Future.delayed(const Duration(seconds: 2), () {
        if (_instance != null && _instance!.mounted) {
          _instance!.setState(() {
            _tooltips.removeWhere((tooltip) => tooltip.message == message);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._tooltips.map((tooltip) => _buildTooltip(tooltip, context)),
      ],
    );
  }

  /// 构建单个提示组件
  Widget _buildTooltip(TooltipInfo tooltip, BuildContext context) {
    return Positioned(
      top: _getTopPosition(tooltip.position, context),
      left: _getLeftPosition(tooltip.position, context, tooltip.message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tooltip.message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: '等线',
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 计算提示在垂直方向上的位置
  double _getTopPosition(TooltipPosition position, BuildContext context) {
    switch (position) {
      case TooltipPosition.fileAreaCenter:
      case TooltipPosition.chatAreaCenter:
        // 文件区和对话区中央位置
        return MediaQuery.of(context).size.height * 0.5 - 20;
      case TooltipPosition.windowCenter:
        // 总窗口中央位置
        return MediaQuery.of(context).size.height * 0.5 - 20;
    }
  }

  /// 计算提示在水平方向上的位置
  double _getLeftPosition(
    TooltipPosition position,
    BuildContext context,
    String message,
  ) {
    // 根据文本长度计算提示框宽度
    final tooltipWidth = _calculateTooltipWidth(message);
    int adjustPosition = 12;
    switch (position) {
      case TooltipPosition.fileAreaCenter:
        // 文件区中央位置 (左侧区域的中央)
        return MediaQuery.of(context).size.width * 0.25 -
            tooltipWidth / 2 -
            adjustPosition;

      case TooltipPosition.chatAreaCenter:
        // 对话区中央位置 (右侧区域的中央)
        return MediaQuery.of(context).size.width * 0.75 -
            tooltipWidth / 2 -
            adjustPosition;

      case TooltipPosition.windowCenter:
        // 总窗口中央位置
        return MediaQuery.of(context).size.width * 0.5 -
            tooltipWidth / 2 -
            adjustPosition;
    }
  }

  /// 根据文本内容计算提示框宽度
  double _calculateTooltipWidth(String message) {
    // 基础宽度 + 文本长度 * 字符宽度
    const baseWidth = 32.0; // padding宽度 (16*2)
    const charWidth = 8.0; // 每个字符大约宽度
    return baseWidth + message.length * charWidth;
  }
}

/// 提示工具类
class TooltipUtil {
  /// 显示提示
  static void showTooltip(String message, TooltipPosition position) {
    TooltipOverlay.showTooltip(message, position);
  }
}
