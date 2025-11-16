import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/status.dart';
import 'status_page.dart';
import 'send_status_page.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusListPage extends StatefulWidget {
  final ApiClient api;
  StatusListPage(this.api);

  @override
  _StatusListPageState createState() => _StatusListPageState();
}

class _StatusListPageState extends State<StatusListPage> {
  List<Status> statuses = [];
  bool loading = true;
  bool isCalendarView = false; // 显示方式：false=平铺，true=日历

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        loading = true;
      });
      final statusList = await widget.api.fetchStatusHistory();
      setState(() {
        statuses = statusList;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _formatTime(String timeStr) {
    try {
      final time = DateTime.parse(timeStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分钟前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小时前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return DateFormat('MM月dd日 HH:mm').format(time);
      }
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('状态历史'),
        actions: [
          IconButton(
            icon: Icon(isCalendarView ? Icons.view_list : Icons.calendar_today),
            onPressed: () {
              setState(() {
                isCalendarView = !isCalendarView;
              });
            },
            tooltip: isCalendarView ? '平铺视图' : '日历视图',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SendStatusPage(widget.api)),
          );
          if (result == true) {
            _loadData(); // 刷新列表
          }
        },
        tooltip: '设置状态',
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: statuses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('还没有状态记录', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : isCalendarView
                      ? _buildCalendarView()
                      : _buildListView(),
            ),
    );
  }

  // 按日期分组状态
  Map<String, List<Status>> _groupStatusesByDate() {
    Map<String, List<Status>> grouped = {};
    for (var status in statuses) {
      try {
        final timeStr = status.meta['time'] ?? '';
        final dateTime = DateTime.parse(timeStr.replaceAll(' ', 'T'));
        final dateKey = DateFormat('yyyy-MM-dd').format(dateTime);
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(status);
      } catch (e) {
        // 忽略解析失败的记录
      }
    }
    return grouped;
  }

  // 平铺视图
  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: statuses.length,
      itemBuilder: (context, index) {
        final status = statuses[index];
        return _buildStatusCard(status);
      },
    );
  }

  // 日历视图
  Widget _buildCalendarView() {
    final grouped = _groupStatusesByDate();
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    
    if (sortedDates.isEmpty) {
      return Center(
        child: Text('还没有状态记录', style: TextStyle(color: Colors.grey)),
      );
    }

    // 获取日期范围
    final firstDate = DateTime.parse(sortedDates.last);
    final lastDate = DateTime.parse(sortedDates.first);
    
    // 生成所有需要显示的日期
    List<DateTime> allDates = [];
    DateTime current = DateTime(firstDate.year, firstDate.month, 1);
    final lastMonth = DateTime(lastDate.year, lastDate.month + 1, 0);
    
    while (current.isBefore(lastMonth) || current.isAtSameMomentAs(lastMonth)) {
      allDates.add(DateTime(current.year, current.month, current.day));
      current = current.add(Duration(days: 1));
    }

    // 按月份分组
    Map<String, List<DateTime>> monthsMap = {};
    for (var date in allDates) {
      final monthKey = DateFormat('yyyy-MM').format(date);
      if (!monthsMap.containsKey(monthKey)) {
        monthsMap[monthKey] = [];
      }
      monthsMap[monthKey]!.add(date);
    }

    final sortedMonths = monthsMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: sortedMonths.length,
      itemBuilder: (context, monthIndex) {
        final monthKey = sortedMonths[monthIndex];
        final dates = monthsMap[monthKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份标题
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                DateFormat('yyyy年MM月').format(dates.first),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 日历网格
            _buildMonthCalendar(dates, grouped),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // 构建月份日历
  Widget _buildMonthCalendar(List<DateTime> dates, Map<String, List<Status>> grouped) {
    // 找到这个月的第一天是星期几
    final firstDay = dates.first;
    final firstDayOfWeek = firstDay.weekday % 7; // 0=周日, 1=周一, ..., 6=周六
    
    // 生成完整网格（包括前面的空白）
    List<Widget> dayWidgets = [];
    
    // 添加星期标题行
    final weekDays = ['日', '一', '二', '三', '四', '五', '六'];
    for (var day in weekDays) {
      dayWidgets.add(
        Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    
    // 添加前面的空白
    for (int i = 0; i < firstDayOfWeek; i++) {
      dayWidgets.add(SizedBox.shrink());
    }
    
    // 添加日期
    for (var date in dates) {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dayStatuses = grouped[dateKey] ?? [];
      
      dayWidgets.add(_buildCalendarDay(date, dayStatuses));
    }
    
    // 计算需要的行数（向上取整）
    final rowCount = (dayWidgets.length / 7).ceil();
    
    // 构建网格
    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final index = rowIndex * 7 + colIndex;
            if (index < dayWidgets.length) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.all(2),
                  child: dayWidgets[index],
                ),
              );
            } else {
              return Expanded(child: SizedBox.shrink());
            }
          }),
        );
      }),
    );
  }

  // 构建单个日历日期
  Widget _buildCalendarDay(DateTime date, List<Status> dayStatuses) {
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    
    return GestureDetector(
      onTap: dayStatuses.isNotEmpty
          ? () => _showStatusDetailsForDay(date, dayStatuses)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isToday ? Colors.blue : Colors.grey[300]!,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 日期数字
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.blue : Colors.black87,
              ),
            ),
            // 状态图标（堆叠显示）
            if (dayStatuses.isNotEmpty) ...[
              SizedBox(height: 4),
              _buildStackedIcons(dayStatuses),
            ],
          ],
        ),
      ),
    );
  }

  // 构建堆叠图标
  Widget _buildStackedIcons(List<Status> statuses) {
    if (statuses.isEmpty) return SizedBox.shrink();
    if (statuses.length == 1) {
      final icon = statuses[0].meta['icon'] ?? '';
      if (icon.toString().isEmpty) return SizedBox.shrink();
      return Text(
        icon.toString(),
        style: GoogleFonts.notoColorEmoji(fontSize: 16),
      );
    }
    
    // 多个状态时堆叠显示
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 主图标
        if (statuses[0].meta['icon'] != null)
          Text(
            statuses[0].meta['icon'].toString(),
            style: GoogleFonts.notoColorEmoji(fontSize: 16),
          ),
        // 重叠的图标（稍微偏移）
        if (statuses.length > 1 && statuses[1].meta['icon'] != null)
          Positioned(
            left: 8,
            top: -2,
            child: Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statuses[1].meta['icon'].toString(),
                style: GoogleFonts.notoColorEmoji(fontSize: 12),
              ),
            ),
          ),
        // 数量徽章（如果有更多）
        if (statuses.length > 2)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(minWidth: 14, minHeight: 14),
              child: Center(
                child: Text(
                  '${statuses.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 显示某一天的状态详情
  void _showStatusDetailsForDay(DateTime date, List<Status> dayStatuses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy年MM月dd日').format(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // 状态列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(8),
                  itemCount: dayStatuses.length,
                  itemBuilder: (context, index) {
                    final status = dayStatuses[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: status.meta['icon'] != null
                            ? Text(
                                status.meta['icon'].toString(),
                                style: GoogleFonts.notoColorEmoji(fontSize: 24),
                              )
                            : null,
                        title: Text(status.meta['name'] ?? ''),
                        subtitle: Text(
                          DateFormat('HH:mm').format(
                            DateTime.parse((status.meta['time'] ?? '').replaceAll(' ', 'T')),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          // 跳转到状态详情页面，使用 filename 查询特定状态
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatusPage(
                                widget.api,
                                filename: status.filename,
                              ),
                            ),
                          );
                        },
                      ),
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

  Widget _buildStatusCard(Status status) {
    final timeStr = status.meta['time'] ?? '';
    final name = status.meta['name'] ?? '';
    final icon = status.meta['icon'] ?? '';
    final background = status.meta['background'] ?? '';
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StatusPage(
                widget.api,
                filename: status.filename,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标、名称和时间
              Row(
                children: [
                  if (icon.isNotEmpty)
                    Text(
                      icon,
                      style: GoogleFonts.notoColorEmoji(
                        fontSize: 24,
                      ),
                    ),
                  if (icon.isNotEmpty) SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name.isNotEmpty)
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          _formatTime(timeStr),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // 内容预览
              Html(
                data: status.html ?? '',
              ),
              // 背景图片预览（如果有）
              if (background.isNotEmpty && background != 'null')
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '${widget.api.baseUrl}$background',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox.shrink();
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

