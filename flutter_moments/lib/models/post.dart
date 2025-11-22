class Post {
  final String filename;
  final String html;
  final Map meta;
  final String? raw; // 原始 Markdown 内容

  Post({required this.filename, required this.html, required this.meta, this.raw});
}
