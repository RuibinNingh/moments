import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';

class FileManagerPage extends StatefulWidget {
  final ApiClient api;
  FileManagerPage(this.api);

  @override
  _FileManagerPageState createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  List<Map<String, dynamic>> _files = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.api.fetchFiles();
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _uploadFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      setState(() {
        _loading = true;
      });
      
      // 根据平台选择文件对象
      dynamic fileToUpload;
      if (kIsWeb) {
        // Web平台，直接使用 XFile
        fileToUpload = image;
      } else {
        // 桌面/移动平台，转换为 File
        fileToUpload = File(image.path);
      }
      
      final result = await widget.api.uploadFile(fileToUpload);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件上传成功: ${result['filename']}')),
      );
      
      _loadFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteFile(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除文件 "$filename" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await widget.api.deleteFile(filename);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件已删除')),
      );
      _loadFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  bool _isImageFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  void _showImagePreview(String filename) {
    // 使用带API Key的URL（Web平台需要）
    final imageUrl = widget.api.getFileUrlWithKey(filename);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(filename),
              actions: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 8),
                          Text('加载图片失败'),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('文件管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading && _files.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _error != null && _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFiles,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('暂无文件', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final filename = file['name'] as String;
                            final size = file['size_human'] as String;
                            final modified = file['modified'] as String;
                            final isImage = _isImageFile(filename);
                            
                            return ListTile(
                              leading: isImage
                                  ? GestureDetector(
                                      onTap: () => _showImagePreview(filename),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            widget.api.getFileUrlWithKey(filename),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(Icons.image, color: Colors.grey);
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(child: CircularProgressIndicator(strokeWidth: 2));
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.insert_drive_file, size: 40),
                              title: Text(filename),
                              subtitle: Text('$size • $modified'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteFile(filename),
                                tooltip: '删除',
                              ),
                              onTap: isImage ? () => _showImagePreview(filename) : null,
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        child: Icon(Icons.upload),
        tooltip: '上传文件',
      ),
    );
  }
}

