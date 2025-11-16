import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:flutter_html/flutter_html.dart';

class PostDetailPage extends StatelessWidget {
  final Post post;
  PostDetailPage(this.post);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.filename)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Html(data: post.html ?? ''),
      ),
    );
  }
}
