import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigPage extends StatefulWidget {
  @override
  _ConfigPageState createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('host') ?? '127.0.0.1';
    _portController.text = prefs.getString('port') ?? '5000';
    _apiKeyController.text = prefs.getString('apiKey') ?? '';
  }

  void _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host', _hostController.text);
    await prefs.setString('port', _portController.text);
    await prefs.setString('apiKey', _apiKeyController.text);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('服务器配置')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _hostController,
              decoration: InputDecoration(labelText: '服务器地址'),
            ),
            TextField(
              controller: _portController,
              decoration: InputDecoration(labelText: '端口'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(labelText: 'API Key'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveConfig,
              child: Text('保存'),
            )
          ],
        ),
      ),
    );
  }
}
