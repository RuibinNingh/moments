import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/emoji_style.dart';
import '../utils/latex_renderer.dart';
import 'send_status_page.dart';

class StatusPage extends StatefulWidget {
  final ApiClient api;
  final String? filename; // 可选，用于查询特定状态
  StatusPage(this.api, {this.filename});

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  var status;
  bool loading = true;
  String? _baseUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await widget.api.loadConfig();
      _baseUrl = widget.api.baseUrl;
      
      // 如果提供了 filename，查询特定状态；否则获取当前状态
      if (widget.filename != null) {
        final queriedStatus = await widget.api.queryStatusByFilename(widget.filename!);
        if (queriedStatus != null && mounted) {
          setState(() {
            status = queriedStatus;
            loading = false;
          });
        } else {
          setState(() {
            _error = '状态不存在';
            loading = false;
          });
        }
      } else {
        final currentStatus = await widget.api.fetchCurrentStatus();
        if (mounted) {
          setState(() {
            status = currentStatus;
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _editStatus() async {
    if (status == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendStatusPage(widget.api, status: status),
      ),
    );
    
    if (result == true && mounted) {
      // 编辑成功，重新加载
      await _loadData();
      // 显示提示信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请刷新获取最新历史'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteStatus() async {
    if (status == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这条状态吗？此操作不可撤销。'),
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
        String filename = status.filename;
        if (filename.endsWith('.md')) {
          filename = filename.substring(0, filename.length - 3);
        }
        
        await widget.api.removeItem('status', filename);
        
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
        title: Text(widget.filename != null ? '状态详情' : '当前状态'),
        actions: status != null
            ? [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: _editStatus,
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _deleteStatus,
                  tooltip: '删除',
                ),
              ]
            : null,
      ),
      body: loading
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
                        onPressed: _loadData,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 状态信息
                  if (status != null) ...[
                    Row(
                      children: [
                        if (status.meta['icon'] != null && status.meta['icon'].toString().isNotEmpty)
                          Text(
                            status.meta['icon'].toString(),
                            style: getEmojiTextStyle(
                              fontSize: 32,
                            ),
                          ),
                        if (status.meta['icon'] != null && status.meta['icon'].toString().isNotEmpty)
                          SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (status.meta['name'] != null && status.meta['name'].toString().isNotEmpty)
                                Text(
                                  status.meta['name'].toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (status.meta['time'] != null)
                                Text(
                                  status.meta['time'].toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // 内容（支持 LaTeX）
                    LatexHtml(data: status.html ?? ''),
                    // 背景图片（如果有）
                    if (status.meta['background'] != null &&
                        status.meta['background'].toString().isNotEmpty &&
                        status.meta['background'] != 'null' &&
                        _baseUrl != null)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '$_baseUrl${status.meta['background']}',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
