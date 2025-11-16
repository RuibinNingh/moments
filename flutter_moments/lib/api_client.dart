import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/post.dart';
import 'models/status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  String _baseUrl = '';
  String _apiKey = '';

  ApiClient();
  
  String get baseUrl => _baseUrl;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('host') ?? '127.0.0.1';
    final port = prefs.getString('port') ?? '5000';
    _apiKey = prefs.getString('apiKey') ?? '';
    _baseUrl = 'http://$host:$port';
  }

  Future<List<Post>> fetchPosts() async {
    await loadConfig();
    final resp = await http.get(Uri.parse('$_baseUrl/api/posts'), headers: {'X-API-KEY': _apiKey});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['posts'] as List).map((e) => Post(
        filename: e['filename'],
        html: e['html'],
        meta: e['meta'],
      )).toList();
    } else {
      throw Exception('请求失败');
    }
  }

  Future<void> sendPost(String content, List<String> tags, String time) async {
    await loadConfig();
    final body = jsonEncode({'content': content, 'tags': tags, 'time': time});
    final resp = await http.post(Uri.parse('$_baseUrl/api/post/new'),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey}, body: body);
    if (resp.statusCode != 200) throw Exception('发送失败');
  }

  Future<Status> fetchCurrentStatus() async {
    await loadConfig();
    final resp = await http.get(Uri.parse('$_baseUrl/api/status/current'), headers: {'X-API-KEY': _apiKey});
    if (resp.statusCode == 200) {
      final e = jsonDecode(resp.body);
      return Status(filename: e['filename'], html: e['html'], meta: e['meta']);
    } else {
      throw Exception('请求失败');
    }
  }

  Future<Map<String, dynamic>> fetchUserInfo() async {
    await loadConfig();
    final resp = await http.get(Uri.parse('$_baseUrl/api/user/info'), headers: {'X-API-KEY': _apiKey});
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception('请求失败');
    }
  }

  Future<List<Status>> fetchStatusHistory() async {
    await loadConfig();
    final resp = await http.get(Uri.parse('$_baseUrl/api/status/history'), headers: {'X-API-KEY': _apiKey});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['statuses'] as List).map((e) => Status(
        filename: e['filename'],
        html: e['html'],
        meta: e['meta'],
      )).toList();
    } else {
      throw Exception('请求失败');
    }
  }

  Future<Post> queryPost({String? date, String? filename, int? limit, int? offset}) async {
    await loadConfig();
    
    if (filename == null && date == null) {
      throw Exception('至少需要提供 date 或 filename 参数');
    }
    
    final uri = Uri.parse('$_baseUrl/api/post/query').replace(queryParameters: {
      if (date != null) 'date': date,
      if (filename != null) 'filename': filename,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    });
    
    final resp = await http.get(uri, headers: {'X-API-KEY': _apiKey});
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      
      // 如果提供 filename，返回单个 Post
      if (filename != null) {
        return Post(
          filename: data['filename'],
          html: data['html'],
          meta: data['meta'],
        );
      }
      
      // 如果只提供 date，返回列表（取第一个，或根据需求处理）
      // 这里假设调用者知道如何处理列表
      if (data['posts'] != null && (data['posts'] as List).isNotEmpty) {
        final post = data['posts'][0];
        return Post(
          filename: post['filename'],
          html: post['html'],
          meta: post['meta'],
        );
      }
      
      throw Exception('未找到动态');
    } else if (resp.statusCode == 404) {
      throw Exception('动态不存在');
    } else {
      throw Exception('请求失败');
    }
  }

  Future<Post?> queryPostByFilename(String filename) async {
    try {
      return await queryPost(filename: filename);
    } catch (e) {
      return null;
    }
  }

  Future<Status> queryStatus({String? date, String? filename, int? limit, int? offset}) async {
    await loadConfig();
    
    if (filename == null && date == null) {
      throw Exception('至少需要提供 date 或 filename 参数');
    }
    
    final uri = Uri.parse('$_baseUrl/api/status/query').replace(queryParameters: {
      if (date != null) 'date': date,
      if (filename != null) 'filename': filename,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    });
    
    final resp = await http.get(uri, headers: {'X-API-KEY': _apiKey});
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      
      // 如果提供 filename，返回单个 Status
      if (filename != null) {
        return Status(
          filename: data['filename'],
          html: data['html'],
          meta: data['meta'],
        );
      }
      
      // 如果只提供 date，返回列表（取第一个）
      if (data['statuses'] != null && (data['statuses'] as List).isNotEmpty) {
        final status = data['statuses'][0];
        return Status(
          filename: status['filename'],
          html: status['html'],
          meta: status['meta'],
        );
      }
      
      throw Exception('未找到状态');
    } else if (resp.statusCode == 404) {
      throw Exception('状态不存在');
    } else {
      throw Exception('请求失败');
    }
  }

  Future<Status?> queryStatusByFilename(String filename) async {
    try {
      return await queryStatus(filename: filename);
    } catch (e) {
      return null;
    }
  }

  Future<void> sendStatus(String content, String name, String icon, String time, {String? background}) async {
    await loadConfig();
    final body = jsonEncode({
      'content': content,
      'name': name,
      'icon': icon,
      'time': time,
      if (background != null && background.isNotEmpty) 'background': background,
    });
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/status/new'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
      body: body,
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('发送失败: ${resp.body}');
    }
  }
}
