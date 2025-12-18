class FileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final DateTime modified;
  final int size;

  FileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.modified,
    required this.size,
  });
}