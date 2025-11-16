import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/post.dart';
import 'models/status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  String _baseUrl = '';
  String _apiKey = '';

  ApiClient();

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
}
