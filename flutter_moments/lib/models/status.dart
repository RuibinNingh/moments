class Status {
  final String filename;
  final String html;
  final Map meta;
  final String? raw; // 原始 Markdown 内容

  Status({required this.filename, required this.html, required this.meta, this.raw});
}
