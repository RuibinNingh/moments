import 'package:flutter/material.dart';
import '../models/post.dart';
import '../api_client.dart';
import 'package:flutter_html/flutter_html.dart';
import 'send_post_page.dart';
import '../utils/latex_renderer.dart';

class PostDetailPage extends StatefulWidget {
  final Post? post; // 可选，如果有就直接显示
  final String? filename; // 可选，用于查询
  final ApiClient? api; // 用于查询的API客户端
  
  PostDetailPage({this.post, this.filename, this.api});

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _post = widget.post;
    } else if (widget.filename != null && widget.api != null) {
      _loadPost();
    } else {
      _error = '缺少必要参数';
    }
  }

  Future<void> _loadPost() async {
    if (widget.filename == null || widget.api == null) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final post = await widget.api!.queryPostByFilename(widget.filename!);
      if (post != null && mounted) {
        setState(() {
          _post = post;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '动态不存在';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _editPost() async {
    if (_post == null || widget.api == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendPostPage(widget.api!, post: _post),
      ),
    );
    
    if (result == true && mounted) {
      // 编辑成功，重新加载
      await _loadPost();
      // 显示提示信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请刷新获取最新历史'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePost() async {
    if (_post == null || widget.api == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这条动态吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        // 移除 .md 后缀
        String filename = _post!.filename;
        if (filename.endsWith('.md')) {
          filename = filename.substring(0, filename.length - 3);
        }
        
        await widget.api!.removeItem('posts', filename);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除成功，请刷新获取最新历史'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context); // 返回
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post?.filename ?? widget.filename ?? '动态详情'),
        actions: _post != null && widget.api != null
            ? [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: _editPost,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _deletePost,
                  tooltip: '删除',
                ),
              ]
            : null,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPost,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _post != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: LatexHtml(data: _post!.html ?? ''),
                    )
                  : Center(
                      child: Text('无内容', style: TextStyle(color: Colors.grey)),
                    ),
    );
  }
}
