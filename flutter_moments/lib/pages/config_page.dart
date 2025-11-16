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
    if (_hostController.text.trim().isEmpty || _portController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器地址和端口不能为空')),
      );
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('host', _hostController.text.trim());
      await prefs.setString('port', _portController.text.trim());
      await prefs.setString('apiKey', _apiKeyController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('配置已保存')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('服务器配置')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '服务器设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '配置服务器连接信息',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 127.0.0.1 或 example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: '端口',
                hintText: '例如: 5000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '输入API密钥',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('保存配置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
