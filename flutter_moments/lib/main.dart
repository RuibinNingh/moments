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
      home: FutureBuilder<bool>(
        future: _hasConfig(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          if (snapshot.data == false) return ConfigPage();
          return PostListPage(api);
        },
      ),
    );
  }
}
