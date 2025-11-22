import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/emoji_style.dart';

class SendStatusPage extends StatefulWidget {
  final ApiClient api;
  SendStatusPage(this.api);

  @override
  _SendStatusPageState createState() => _SendStatusPageState();
}

class _SendStatusPageState extends State<SendStatusPage> {
  final _contentController = TextEditingController();
  final _nameController = TextEditingController();
  final _backgroundController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  String _selectedIcon = '💻';
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    // 监听内容变化，实时更新预览
    _contentController.addListener(() {
      if (_showPreview && mounted) {
        setState(() {});
      }
    });
  }

  // 常用图标库
  final List<String> _iconLibrary = [
    '💻', '📚', '🎮', '🎵', '☕', '🍜', '🚗', '🏖️', '🏊', '💼',
    '🍱', '📅', '🎉', '📖', '🏃', '🍽️', '🎬', '💬', '🤔', '😴',
    '❤️', '🛒', '🎨', '📷', '✈️', '🏠', '🌙', '☀️', '⭐', '🎯',
    '🎪', '🎭', '🎤', '🎸', '🎹', '🎺', '🎻', '🥁', '🎲', '🎰',
    '🏀', '⚽', '🎾', '🏐', '🏓', '🏸', '🥊', '🏋️', '🧘', '🧗',
    '🚴', '🏇', '🏂', '⛷️', '🏄', '🚣', '⛵', '🏊', '🤽', '🤾',
    '🧗', '🚵', '🏌️', '🏹', '🎣', '🎪', '🎨', '🖌️', '🖍️', '✏️',
    '📝', '📄', '📃', '📑', '📊', '📈', '📉', '📌', '📍', '📎',
    '🔖', '📐', '📏', '✂️', '🔧', '🔨', '⚙️', '🔩', '⛏️', '🛠️',
  ];

  @override
  void dispose() {
    _contentController.dispose();
    _nameController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 400,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择图标',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _iconLibrary.length,
                itemBuilder: (context, index) {
                  final icon = _iconLibrary[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedIcon == icon
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedIcon == icon
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          icon,
                          style: getEmojiTextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> _sendStatus() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('内容不能为空')),
      );
      return;
    }

    try {
      final timeStr = _formatDateTime(_selectedDateTime);
      await widget.api.sendStatus(
        _contentController.text,
        _nameController.text.trim(),
        _selectedIcon,
        _backgroundController.text.trim(),
        timeStr,
      );
      Navigator.pop(context, true); // 返回true表示成功发送
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置状态'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(_showPreview ? Icons.preview : Icons.edit),
            onSelected: (value) {
              setState(() {
                if (value == 'edit') {
                  _showPreview = false;
                } else if (value == 'preview') {
                  _showPreview = true;
                } else {
                  _showPreview = false; // 默认编辑模式
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('编辑模式'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.preview, size: 20),
                    SizedBox(width: 8),
                    Text('预览模式'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 配置区域
          Expanded(
            flex: _showPreview ? 1 : 2,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标选择
                  Row(
                    children: [
                      Text('图标:', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 16),
                      GestureDetector(
                        onTap: _showIconPicker,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedIcon,
                            style: getEmojiTextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: _showIconPicker,
                        child: Text('选择图标'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 状态名称
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '状态名称（可选）',
                      hintText: '例如: coding(自定义)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 时间选择
                  InkWell(
                    onTap: _selectDateTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '时间',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateTime),
                            style: TextStyle(fontSize: 16),
                          ),
                          Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 背景图片
                  TextField(
                    controller: _backgroundController,
                    decoration: InputDecoration(
                      labelText: '背景图片路径（可选）',
                      hintText: '/upload/bg_xxx.png',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 内容编辑/预览
                  if (!_showPreview) ...[
                    Text('内容 (Markdown):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _contentController,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: '输入Markdown格式的内容...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text('预览:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      constraints: BoxConstraints(minHeight: 200),
                      child: _contentController.text.isEmpty
                          ? Center(
                              child: Text(
                                '输入内容后可以预览',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : MarkdownBody(data: _contentController.text),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 发送按钮
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendStatus,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('发送状态'),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

