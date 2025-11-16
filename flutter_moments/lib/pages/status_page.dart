import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class StatusPage extends StatefulWidget {
  final ApiClient api;
  StatusPage(this.api);

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  var status;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    widget.api.fetchCurrentStatus().then((value) {
      setState(() {
        status = value;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('当前状态')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Markdown(data: status.html),
            ),
    );
  }
}
