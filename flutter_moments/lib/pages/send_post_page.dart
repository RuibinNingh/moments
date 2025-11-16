import 'package:flutter/material.dart';
import '../api_client.dart';

class SendPostPage extends StatefulWidget {
  final ApiClient api;
  SendPostPage(this.api);

  @override
  _SendPostPageState createState() => _SendPostPageState();
}

class _SendPostPageState extends State<SendPostPage> {
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('发送动态')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(labelText: '内容'),
            ),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(labelText: '标签, 用逗号分隔'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final tags = _tagsController.text.split(',');
                await widget.api.sendPost(_contentController.text, tags, DateTime.now().toString());
                Navigator.pop(context);
              },
              child: Text('发送'),
            ),
          ],
        ),
      ),
    );
  }
}
