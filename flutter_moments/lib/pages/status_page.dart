import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('当前状态')),
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
                            style: GoogleFonts.notoColorEmoji(
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
                    // 内容
                    Html(data: status.html ?? ''),
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
