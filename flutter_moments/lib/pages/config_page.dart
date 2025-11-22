import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';

class ConfigPage extends StatefulWidget {
  @override
  _ConfigPageState createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isReloading = false;

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

  Future<void> _reloadConfig() async {
    if (_hostController.text.trim().isEmpty || _portController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先填写服务器地址和端口')),
      );
      return;
    }
    
    setState(() {
      _isReloading = true;
    });
    
    try {
      // 先保存当前配置到本地，以便 API 调用时使用
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('host', _hostController.text.trim());
      await prefs.setString('port', _portController.text.trim());
      await prefs.setString('apiKey', _apiKeyController.text.trim());
      
      // 调用刷新配置 API
      final result = await _apiClient.reloadConfig();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置已刷新'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新配置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
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
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isReloading ? null : _reloadConfig,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isReloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh),
                label: Text('刷新服务器配置'),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '刷新服务器配置会重新读取服务器端的配置文件',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
