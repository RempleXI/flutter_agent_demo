import 'package:flutter/material.dart';

class FileSection extends StatelessWidget {
  final String title;

  const FileSection({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题栏
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // 返回上级文件夹功能
                    // 这里需要实现实际的导航逻辑
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.upload_file, size: 20),
                  onPressed: () {
                    // 导入文件功能
                    // 这里需要实现实际的文件导入逻辑
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          // 文件列表区域
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: const [
                  // 示例文件项
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.folder, size: 20),
                    title: Text('示例文件夹', style: TextStyle(fontSize: 14)),
                    onTap: null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.description, size: 20),
                    title: Text('示例文件.txt', style: TextStyle(fontSize: 14)),
                    onTap: null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}