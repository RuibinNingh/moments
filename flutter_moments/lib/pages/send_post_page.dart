import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/post.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SendPostPage extends StatefulWidget {
  final ApiClient api;
  final Post? post; // 可选，如果提供则进入编辑模式
  SendPostPage(this.api, {this.post});

  @override
  _SendPostPageState createState() => _SendPostPageState();
}

class _SendPostPageState extends State<SendPostPage> {
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _showPreview = false;

  String _extractBodyFromRaw(String? raw) {
    if (raw == null) return '';
    // 如果包含 YAML front matter，提取 body 部分
    if (raw.startsWith('---')) {
      final parts = raw.split('---');
      if (parts.length >= 3) {
        return parts.sublist(2).join('---').trim();
      }
    }
    return raw.trim();
  }

  @override
  void initState() {
    super.initState();
    // 如果是编辑模式，填充初始值
    if (widget.post != null) {
      // 从 raw 字段提取原始内容
      final content = _extractBodyFromRaw(widget.post!.raw);
      if (content.isNotEmpty) {
        _contentController.text = content;
      }
      // 从 meta 中提取标签
      final meta = widget.post!.meta;
      if (meta['tags'] != null) {
        final tags = meta['tags'];
        if (tags is List) {
          _tagsController.text = tags.join(', ');
        }
      }
    }
    // 监听内容变化，实时更新预览
    _contentController.addListener(() {
      if (_showPreview && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post != null ? '编辑动态' : '发送动态'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(_showPreview ? Icons.preview : Icons.edit),
            onSelected: (value) {
              setState(() {
                if (value == 'edit') {
                  _showPreview = false;
                } else if (value == 'preview') {
                  _showPreview = true;
                } else {
                  _showPreview = false;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('编辑模式'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.preview, size: 20),
                    SizedBox(width: 8),
                    Text('预览模式'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签输入
                  TextField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      labelText: '标签, 用逗号分隔',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 内容编辑/预览
                  if (!_showPreview) ...[
                    Text('内容 (Markdown):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _contentController,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: '输入Markdown格式的内容...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text('预览:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      constraints: BoxConstraints(minHeight: 200),
                      child: _contentController.text.isEmpty
                          ? Center(
                              child: Text(
                                '输入内容后可以预览',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : MarkdownBody(data: _contentController.text),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 发送按钮
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    
                    if (widget.post != null) {
                      // 编辑模式
                      final now = DateTime.now();
                      final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                      await widget.api.editPost(
                        postFile: widget.post!.filename,
                        content: _contentController.text,
                        tags: tags,
                        time: timeStr,
                      );
                      Navigator.pop(context, true); // 返回true表示成功编辑
                    } else {
                      // 新建模式
                      final now = DateTime.now();
                      final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                      await widget.api.sendPost(_contentController.text, tags, timeStr);
                      Navigator.pop(context, true); // 返回true表示成功发送
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.post != null ? '编辑失败: $e' : '发送失败: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(widget.post != null ? '保存' : '发送'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
