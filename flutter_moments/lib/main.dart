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
  bool _isNavigating = false; // 正在导航的标志

  Future<bool> _hasConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('host') && prefs.containsKey('port') && prefs.containsKey('apiKey');
  }

  void _checkConfig() {
    setState(() {
      _configFuture = _hasConfig();
      // 只有在配置检查完成后才重置导航标志
    });
  }

  void _navigateToConfig() async {
    // 如果正在导航或已经导航过，直接返回
    if (_isNavigating || _hasNavigatedToConfig || !mounted) return;
    
    _isNavigating = true;
    _hasNavigatedToConfig = true;
    
    // 等待下一帧，确保widget树已构建完成
    await Future.delayed(Duration(milliseconds: 100));
    
    if (!mounted) {
      _isNavigating = false;
      _hasNavigatedToConfig = false;
      return;
    }
    
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ConfigPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 200),
      ),
    );
    
    _isNavigating = false;
    
    // 配置保存后重新检查
    if (result == true && mounted) {
      // 立即重新检查配置，这会触发FutureBuilder重新构建
      _checkConfig();
      // 注意：不重置 _hasNavigatedToConfig，因为如果配置检查失败，不应该再次导航
    } else if (mounted) {
      // 如果用户取消了配置，重置标志，允许下次再次导航
      setState(() {
        _hasNavigatedToConfig = false;
      });
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
          if (!_hasNavigatedToConfig && !_isNavigating) {
            // 使用 SchedulerBinding 确保在下一帧执行
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasNavigatedToConfig && !_isNavigating) {
                _navigateToConfig();
              }
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
