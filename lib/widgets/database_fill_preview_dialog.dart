import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/file_manager.dart';

/// 自动入库工具的结果预览弹窗组件
///
/// 该组件用于展示"待填入数据库.xlsx"文件，支持双击打开文件和点击"下一步"按钮
class DatabaseFillPreviewDialog extends StatefulWidget {
  /// 文件路径
  final String filePath;

  /// 下一步回调函数
  final VoidCallback onNext;

  /// 文件是否存在
  final bool fileExists;

  const DatabaseFillPreviewDialog({
    super.key,
    required this.filePath,
    required this.onNext,
    this.fileExists = true,
  });

  @override
  State<DatabaseFillPreviewDialog> createState() =>
      _DatabaseFillPreviewDialogState();
}

class _DatabaseFillPreviewDialogState extends State<DatabaseFillPreviewDialog> {
  /// 文件名
  late String _fileName;
  bool _isHovered = false; // 添加悬停状态

  @override
  void initState() {
    super.initState();
    _fileName = widget.fileExists ? path.basename(widget.filePath) : '无文件';
  }

  /// 打开文件
  Future<void> _openFile() async {
    // 只有文件存在时才能打开
    if (!widget.fileExists) return;

    try {
      await FileManager().openFile(widget.filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开文件失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自动入库预览'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('检测到以下文件待处理：', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Card(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: GestureDetector(
                  onDoubleTap: widget.fileExists ? _openFile : null,
                  onLongPress: widget.fileExists ? _openFile : null,
                  onTap: () {
                    // 单击无反馈，与文件区行为保持一致
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _isHovered ? Colors.grey[200] : null,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: ListTile(
                      leading: Icon(
                        widget.fileExists
                            ? Icons.description
                            : Icons.description_outlined,
                        color: widget.fileExists ? Colors.green : Colors.grey,
                      ),
                      title: Text(_fileName),
                      subtitle: Text(widget.fileExists ? 'Excel 文件' : '未找到文件'),
                      // 移除高亮效果
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('操作说明：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              widget.fileExists
                  ? '• 双击或长按文件可使用默认程序打开'
                  : '• 请先确保结果区存在"待填入数据库.xlsx"文件',
            ),
            const Text('• 确认无误后点击"下一步"完成入库'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: widget.fileExists
              ? () {
                  Navigator.of(context).pop();
                  widget.onNext();
                }
              : null, // 文件不存在时禁用按钮
          child: const Text('下一步'),
        ),
      ],
    );
  }
}
