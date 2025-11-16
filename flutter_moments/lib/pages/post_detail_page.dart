import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PostDetailPage extends StatelessWidget {
  final Post post;
  PostDetailPage(this.post);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.filename)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Markdown(data: post.html),
      ),
    );
  }
}
