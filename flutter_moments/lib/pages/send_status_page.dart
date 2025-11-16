import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SendStatusPage extends StatefulWidget {
  final ApiClient api;
  SendStatusPage(this.api);

  @override
  _SendStatusPageState createState() => _SendStatusPageState();
}

class _SendStatusPageState extends State<SendStatusPage> {
  final _contentController = TextEditingController();
  final _nameController = TextEditingController();
  final PageController _pageController = PageController();
  
  String _selectedIcon = '';
  DateTime _selectedDateTime = DateTime.now();
  bool _showPreview = false;
  String? _previewHtml;

  // 图标库分类
  final Map<String, List<String>> _iconCategories = {
    '工作学习': ['💻', '📚', '📝', '✍️', '💼', '📊', '📈', '🎓', '🔬', '⚗️'],
    '生活日常': ['☕', '🍜', '🍱', '🍔', '🍕', '🍰', '🍎', '🥤', '🍵', '🍻'],
    '运动健康': ['🏃', '🚴', '🏋️', '🧘', '🏊', '⚽', '🏀', '🎾', '🏸', '🧗'],
    '娱乐休闲': ['🎮', '🎬', '🎵', '🎸', '🎨', '📷', '🎭', '🎪', '🎯', '🎲'],
    '情感心情': ['😊', '😄', '😍', '🥰', '😎', '🤔', '😴', '😢', '😤', '😌'],
    '旅行交通': ['🚗', '✈️', '🚄', '🚢', '🚲', '🏖️', '🏔️', '🌊', '🏕️', '🗺️'],
    '天气季节': ['☀️', '🌙', '⭐', '☁️', '⛈️', '❄️', '🌸', '🍂', '🍁', '🌺'],
    '其他': ['❤️', '💬', '📱', '💡', '🔔', '🎉', '🎁', '🎊', '✨', '🌟'],
  };

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    // 这里可以添加Markdown转HTML的预览逻辑
    // 暂时使用简单的文本预览
    setState(() {
      _previewHtml = _contentController.text;
    });
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

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择图标',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _iconCategories.length,
                  itemBuilder: (context, index) {
                    final category = _iconCategories.keys.elementAt(index);
                    final icons = _iconCategories[category]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: icons.map((icon) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIcon = icon;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _selectedIcon == icon
                                        ? Colors.blue
                                        : Colors.grey[300]!,
                                    width: _selectedIcon == icon ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: _selectedIcon == icon
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.grey[50],
                                ),
                                child: Center(
                                  child: Text(
                                    icon,
                                    style: GoogleFonts.notoColorEmoji(fontSize: 28),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendStatus() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入内容')),
      );
      return;
    }

    try {
      final timeStr = _formatDateTime(_selectedDateTime);
      await widget.api.sendStatus(
        _contentController.text,
        _nameController.text.trim().isEmpty ? '状态' : _nameController.text.trim(),
        _selectedIcon,
        timeStr,
      );
      if (mounted) {
        Navigator.pop(context, true); // 返回true表示成功发送
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置状态'),
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.preview),
            onPressed: () {
              setState(() {
                _showPreview = !_showPreview;
              });
            },
            tooltip: _showPreview ? '编辑' : '预览',
          ),
        ],
      ),
      body: _showPreview ? _buildPreviewView() : _buildEditView(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _sendStatus,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('发送'),
          ),
        ),
      ),
    );
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标选择
          Text(
            '图标',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _showIconPicker,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_selectedIcon.isNotEmpty)
                    Text(
                      _selectedIcon,
                      style: GoogleFonts.notoColorEmoji(fontSize: 32),
                    )
                  else
                    Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedIcon.isEmpty ? '点击选择图标' : '点击更换图标',
                      style: TextStyle(
                        color: _selectedIcon.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          
          // 状态名称
          Text(
            '状态名称',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '例如：coding、study、relax',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 24),
          
          // 时间选择
          Text(
            '时间',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDateTime,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateTime),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          
          // 内容编辑
          Text(
            '内容（Markdown）',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: '输入Markdown格式的内容...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览头部信息
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_selectedIcon.isNotEmpty)
                        Text(
                          _selectedIcon,
                          style: GoogleFonts.notoColorEmoji(fontSize: 32),
                        ),
                      if (_selectedIcon.isNotEmpty) SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.trim().isEmpty
                                  ? '状态'
                                  : _nameController.text.trim(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateTime),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // 预览内容
          if (_contentController.text.trim().isNotEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: MarkdownBody(
                  data: _contentController.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '暂无内容',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

