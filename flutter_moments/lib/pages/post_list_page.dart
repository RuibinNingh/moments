import 'package:flutter/material.dart';
import '../api_client.dart';
import 'post_detail_page.dart';
import 'send_post_page.dart';

class PostListPage extends StatefulWidget {
  final ApiClient api;
  PostListPage(this.api);

  @override
  _PostListPageState createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List posts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    widget.api.fetchPosts().then((value) {
      setState(() {
        posts = value;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('动态列表')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return ListTile(
                  title: Text(post.filename),
                  subtitle: Text(post.meta['time']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostDetailPage(post)),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SendPostPage(widget.api)),
          );
        },
      ),
    );
  }
}
