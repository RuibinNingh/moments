import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models/post.dart';
import 'models/status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  String _baseUrl = '';
  String _apiKey = '';

  ApiClient();
  
  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

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
        raw: e['raw'],
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
      return Status(filename: e['filename'], html: e['html'], meta: e['meta'], raw: e['raw']);
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
        raw: e['raw'],
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
          raw: data['raw'],
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
          raw: post['raw'],
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
          raw: data['raw'],
        );
      }
      
      // 如果只提供 date，返回列表（取第一个）
      if (data['statuses'] != null && (data['statuses'] as List).isNotEmpty) {
        final status = data['statuses'][0];
        return Status(
          filename: status['filename'],
          html: status['html'],
          meta: status['meta'],
          raw: status['raw'],
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

  Future<void> sendStatus(String content, String name, String icon, String background, String time) async {
    await loadConfig();
    final body = jsonEncode({
      'content': content,
      'name': name,
      'icon': icon,
      'background': background,
      'time': time,
    });
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/status/new'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
      body: body,
    );
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('发送失败: ${resp.statusCode}');
    }
  }

  // 文件管理相关方法
  Future<List<Map<String, dynamic>>> fetchFiles() async {
    await loadConfig();
    final resp = await http.get(
      Uri.parse('$_baseUrl/files'),
      headers: {'X-API-KEY': _apiKey},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return List<Map<String, dynamic>>.from(data['files'] ?? []);
    } else {
      throw Exception('获取文件列表失败: ${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>> uploadFile(dynamic file) async {
    await loadConfig();
    
    final uri = Uri.parse('$_baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-KEY'] = _apiKey;
    
    // 添加文件 - 支持 File 和 XFile
    http.MultipartFile multipartFile;
    
    if (kIsWeb) {
      // Web平台：使用 XFile 的 bytes
      final bytes = await file.readAsBytes();
      final filename = file.name;
      multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      );
    } else {
      // 桌面/移动平台：使用 File
      final fileStream = (file as File).openRead();
      final length = await (file as File).length();
      multipartFile = http.MultipartFile(
        'file',
        fileStream,
        length,
        filename: (file as File).path.split('/').last,
      );
    }
    
    request.files.add(multipartFile);
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? '上传失败: ${response.statusCode}');
    }
  }

  Future<void> deleteFile(String filename) async {
    await loadConfig();
    final resp = await http.delete(
      Uri.parse('$_baseUrl/files/$filename'),
      headers: {'X-API-KEY': _apiKey},
    );
    if (resp.statusCode != 200) {
      final error = jsonDecode(resp.body);
      throw Exception(error['error'] ?? '删除失败: ${resp.statusCode}');
    }
  }

  String getFileUrl(String filename) {
    // 文件URL（公开访问，不需要API Key）
    return '$_baseUrl/upload/$filename';
  }
  
  String getFileUrlWithKey(String filename) {
    // 为了兼容性保留，但实际不需要key
    return getFileUrl(filename);
  }

  /// 下载文件到本地
  /// 返回下载后的文件路径
  Future<String> downloadFile(String filename, String savePath) async {
    await loadConfig();
    final url = getFileUrl(filename);
    final resp = await http.get(
      Uri.parse(url),
      headers: {'X-API-KEY': _apiKey},
    );
    
    if (resp.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(resp.bodyBytes);
      return savePath;
    } else {
      throw Exception('下载失败: ${resp.statusCode}');
    }
  }

  /// 删除动态或状态
  /// type: 'posts' 或 'status'
  /// file: 文件名（不需要 .md 后缀）
  Future<void> removeItem(String type, String file) async {
    await loadConfig();
    final body = jsonEncode({'type': type, 'file': file});
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/remove'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
      body: body,
    );
    if (resp.statusCode != 200) {
      final error = jsonDecode(resp.body);
      throw Exception(error['error'] ?? '删除失败: ${resp.statusCode}');
    }
  }

  /// 编辑动态
  /// postFile: 文件名（必填）
  /// content: 内容（可选）
  /// tags: 标签列表（可选）
  /// time: 时间（可选）
  Future<Post> editPost({
    required String postFile,
    String? content,
    List<String>? tags,
    String? time,
  }) async {
    await loadConfig();
    final body = <String, dynamic>{
      'post_file': postFile,
    };
    if (content != null) body['content'] = content;
    if (tags != null) body['tags'] = tags;
    if (time != null) body['time'] = time;

    final resp = await http.post(
      Uri.parse('$_baseUrl/api/post/edit'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return Post(
        filename: data['filename'],
        html: data['html'],
        meta: data['meta'],
      );
    } else {
      final error = jsonDecode(resp.body);
      throw Exception(error['error'] ?? '编辑失败: ${resp.statusCode}');
    }
  }

  /// 编辑状态
  /// statusFile: 文件名（必填）
  /// content: 内容（可选）
  /// name: 名称（可选）
  /// icon: 图标（可选）
  /// background: 背景图路径（可选）
  /// time: 时间（可选）
  Future<Status> editStatus({
    required String statusFile,
    String? content,
    String? name,
    String? icon,
    String? background,
    String? time,
  }) async {
    await loadConfig();
    final body = <String, dynamic>{
      'status_file': statusFile,
    };
    if (content != null) body['content'] = content;
    if (name != null) body['name'] = name;
    if (icon != null) body['icon'] = icon;
    if (background != null) body['background'] = background;
    if (time != null) body['time'] = time;

    final resp = await http.put(
      Uri.parse('$_baseUrl/api/status/edit'),
      headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return Status(
        filename: data['filename'],
        html: data['html'],
        meta: data['meta'],
        raw: data['raw'],
      );
    } else {
      final error = jsonDecode(resp.body);
      throw Exception(error['error'] ?? '编辑失败: ${resp.statusCode}');
    }
  }

  /// 刷新服务器配置
  Future<Map<String, dynamic>> reloadConfig() async {
    await loadConfig();
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/reload'),
      headers: {'X-API-KEY': _apiKey},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      final error = jsonDecode(resp.body);
      throw Exception(error['error'] ?? '刷新配置失败: ${resp.statusCode}');
    }
  }
}
