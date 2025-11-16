import 'package:flutter/material.dart';
import 'api_client.dart';
import 'pages/post_list_page.dart';
import 'pages/config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ApiClient api = ApiClient();

  Future<bool> _hasConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('host') && prefs.containsKey('port') && prefs.containsKey('apiKey');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '瞬间客户端',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(api: api),
    );
  }
}

class HomePage extends StatefulWidget {
  final ApiClient api;
  HomePage({required this.api});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<bool>? _configFuture;
  bool _hasNavigatedToConfig = false;

  Future<bool> _hasConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('host') && prefs.containsKey('port') && prefs.containsKey('apiKey');
  }

  void _checkConfig() {
    setState(() {
      _configFuture = _hasConfig();
      _hasNavigatedToConfig = false; // 重置标志
    });
  }

  void _navigateToConfig() async {
    if (_hasNavigatedToConfig) return; // 避免重复导航
    _hasNavigatedToConfig = true;
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ConfigPage()),
    );
    // 配置保存后重新检查
    if (result == true && mounted) {
      _checkConfig(); // 重新检查配置
    }
  }

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == false) {
          // 延迟导航，确保 context 可用
          if (!_hasNavigatedToConfig) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToConfig();
            });
          }
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return PostListPage(widget.api);
      },
    );
  }
}
