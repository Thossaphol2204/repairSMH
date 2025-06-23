import 'package:flutter/material.dart';
import '../tabs/work_order_tab.dart';
import '../constants.dart';

class WorkOrderOverviewScreen extends StatelessWidget {
  const WorkOrderOverviewScreen({Key? key}) : super(key: key);

  void _goToTab(BuildContext context, int tabIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('งานช่าง', style: TextStyle(fontFamily: 'Kanit')),
            backgroundColor: Colors.blue[900],
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: WorkOrderTab(initialTabIndex: tabIndex, hideTabBar: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tabButtons = [
      {
        'label': 'จ่ายงานช่าง',
        'icon': Icons.assignment_ind,
        'color': AppConstants.primaryColor,
        'tabIndex': 0,
        'subtitle': 'เลือกและจ่ายงานให้ช่าง',
      },
      {
        'label': 'ช่างรับงาน',
        'icon': Icons.engineering,
        'color': Colors.green[700],
        'tabIndex': 1,
        'subtitle': 'ช่างรับงานที่ได้รับมอบหมาย',
      },
      {
        'label': 'กำลังดำเนินการ',
        'icon': Icons.play_arrow,
        'color': Colors.orange[800],
        'tabIndex': 2,
        'subtitle': 'งานที่กำลังดำเนินการอยู่',
      },
      {
        'label': 'เสร็จสิ้น',
        'icon': Icons.check_circle,
        'color': Colors.teal[700],
        'tabIndex': 3,
        'subtitle': 'งานที่ดำเนินการเสร็จสิ้น',
      },
    ];

    return Container(
      decoration: BoxDecoration(
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            vertical: AppConstants.defaultPadding,
            horizontal: AppConstants.defaultPadding,
          ),
          itemCount: tabButtons.length,
          itemBuilder: (context, index) {
            final tab = tabButtons[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              elevation: AppConstants.cardElevation,
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: AppConstants.smallPadding,
                ),
                leading: CircleAvatar(
                  backgroundColor: tab['color'],
                  child: Icon(
                    tab['icon'],
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  tab['label'],
                  style: AppConstants.titleStyle.copyWith(color: Colors.black87),
                ),
                subtitle: Text(
                  tab['subtitle'],
                  style: AppConstants.captionStyle.copyWith(color: Colors.grey[700]),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: tab['color'],
                ),
                onTap: () => _goToTab(context, tab['tabIndex']),
              ),
            );
          },
        ),
      ),
    );
  }
} 