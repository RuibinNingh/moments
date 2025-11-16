import 'package:flutter/material.dart';
import '../models/post.dart';
import '../api_client.dart';
import 'package:flutter_html/flutter_html.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post?.filename ?? widget.filename ?? '动态详情'),
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
                      child: Html(data: _post!.html ?? ''),
                    )
                  : Center(
                      child: Text('无内容', style: TextStyle(color: Colors.grey)),
                    ),
    );
  }
}
