import 'package:flutter/material.dart';
import '../api_client.dart';
import 'post_detail_page.dart';
import 'send_post_page.dart';
import 'status_list_page.dart';
import 'status_page.dart';
import 'config_page.dart';
import 'file_manager_page.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/emoji_style.dart';

class PostListPage extends StatefulWidget {
  final ApiClient api;
  PostListPage(this.api);

  @override
  _PostListPageState createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List posts = [];
  Map<String, dynamic>? userInfo;
  dynamic currentStatus; // 当前状态
  bool loading = true;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await widget.api.loadConfig();
      // 获取用户信息、动态列表和当前状态
      final userInfoFuture = widget.api.fetchUserInfo();
      final postsFuture = widget.api.fetchPosts();
      final statusFuture = widget.api.fetchCurrentStatus().catchError((e) => null);
      
      final results = await Future.wait([userInfoFuture, postsFuture, statusFuture]);
      
      setState(() {
        userInfo = results[0] as Map<String, dynamic>;
        posts = results[1] as List;
        currentStatus = results[2]; // 可能是null
        _baseUrl = widget.api.baseUrl;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  String _formatTime(String timeStr) {
    try {
      final time = DateTime.parse(timeStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分钟前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小时前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return DateFormat('MM月dd日 HH:mm').format(time);
      }
    } catch (e) {
      return timeStr;
    }
  }

  String? _getAvatarUrl() {
    if (userInfo == null || userInfo!['avatar'] == null || _baseUrl == null || _baseUrl!.isEmpty) return null;
    final avatarFileName = userInfo!['avatar'] as String;
    return '$_baseUrl/upload/$avatarFileName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('瞬间'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StatusListPage(widget.api)),
              );
            },
            tooltip: '状态历史',
          ),
          IconButton(
            icon: Icon(Icons.folder),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FileManagerPage(widget.api)),
              );
            },
            tooltip: '文件管理',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ConfigPage()),
              );
              if (result == true) {
                // 配置已更新，重新加载数据
                _loadData();
              }
            },
            tooltip: '设置',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('还没有动态，发布第一条吧！', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final tags = post.meta['tags'] as List<dynamic>? ?? [];
                        final isWeChat = tags.contains('微信');
                        
                        return _buildPostCard(post, isWeChat);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SendPostPage(widget.api)),
          );
          if (result == true) {
            _loadData(); // 刷新列表
          }
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic post, bool isWeChat) {
    final timeStr = post.meta['time'] ?? '';
    final avatarUrl = _getAvatarUrl();
    final nickname = userInfo?['nickname'] ?? '用户';
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(
                filename: post.filename,
                api: widget.api,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              CircleAvatar(
                radius: 24,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // 头像加载失败时的处理
                },
                child: avatarUrl == null
                    ? Icon(Icons.person, size: 24)
                    : null,
              ),
              SizedBox(width: 12),
              // 内容区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 昵称、状态图标和时间
                    Row(
                      children: [
                        Text(
                          nickname,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // 状态图标
                        if (currentStatus != null && 
                            currentStatus.meta != null &&
                            currentStatus.meta['icon'] != null &&
                            currentStatus.meta['icon'].toString().isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => StatusPage(widget.api)),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text(
                                currentStatus.meta['icon'].toString(),
                                style: getEmojiTextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatTime(timeStr),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 标签提示
                    if (isWeChat)
                      Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              '来自微信朋友圈',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 8),
                    // 内容
                    Html(
                      data: post.html ?? '',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
