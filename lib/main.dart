import 'package:flutter/material.dart';
import 'tabs/repair_tab.dart';
import 'tabs/customer_feedback_tab.dart';
import 'tabs/work_order_tab.dart';
import 'tabs/pm_tab.dart';
import 'tabs/repair_summary_tab.dart';
import 'tabs/pm_summary_tab.dart';
import 'screens/role_selection_screen.dart';
import 'screens/work_order_overview_screen.dart';
import 'screens/bug_report_screen.dart';
import 'screens/about_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Repair App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: RoleSelectionScreen(),
      routes: {
        '/role_select': (context) => RoleSelectionScreen(),
        '/home': (context) => MainTabScreen(),
        '/work_order_overview': (context) => WorkOrderOverviewScreen(),
        '/technician_home': (context) => MainTechnicianTabScreen(),
      },
    );
  }
}

class MainTabScreen extends StatefulWidget {
  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    RepairTab(),
    CustomerFeedbackTab(),
  ];

  final List<String> _titles = [
    'แจ้งซ่อม',
    'ประเมิน',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[800]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icon/logo_SMH.png', width: 64, height: 64),
                  SizedBox(height: 8),
                  Text('SMH Repair App', style: TextStyle(color: Colors.white, fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.blue),
              title: Text('เกี่ยวกับ/คู่มือ', style: TextStyle(fontFamily: 'Kanit')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem, color: Colors.orange),
              title: Text('แจ้งบัค', style: TextStyle(fontFamily: 'Kanit')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => BugReportScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back , color:Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/role_select');
          },
        ),
        title: Text(_titles[_currentIndex]),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: Colors.white.withOpacity(0.7),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.menu, size: 30, color: Colors.white),
                tooltip: 'เมนู',
                onSelected: (value) {
                  if (value == 'about') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AboutScreen()),
                    );
                  } else if (value == 'bug') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => BugReportScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'about', child: Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 8), Text('เกี่ยวกับ/คู่มือ')],)),
                  PopupMenuItem(value: 'bug', child: Row(children: [Icon(Icons.report_problem, color: Colors.orange), SizedBox(width: 8), Text('แจ้งบัค')],)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Color(0xFF667eea),
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            showUnselectedLabels: true,
            elevation: 10,
            onTap: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _currentIndex == 0 ? Color(0xFF667eea).withOpacity(0.2) : Colors.transparent,
                  ),
                  child: Icon(Icons.build_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF667eea).withOpacity(0.2),
                  ),
                  child: Icon(Icons.build),
                ),
                label: 'แจ้งซ่อม',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _currentIndex == 1 ? Color(0xFF667eea).withOpacity(0.2) : Colors.transparent,
                  ),
                  child: Icon(Icons.rate_review_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF667eea).withOpacity(0.2),
                  ),
                  child: Icon(Icons.rate_review),
                ),
                label: 'ประเมิน',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainTechnicianTabScreen extends StatefulWidget {
  @override
  _MainTechnicianTabScreenState createState() => _MainTechnicianTabScreenState();
}

class _MainTechnicianTabScreenState extends State<MainTechnicianTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    RepairTab(),
    CustomerFeedbackTab(),
    WorkOrderOverviewScreen(),
    PMTab(),
    RepairSummaryTab(),
    PMSummaryTab(),
  ];

  final List<String> _titles = [
    'แจ้งซ่อม',
    'ประเมิน',
    'งานช่าง',
    'PM',
    'สรุปการซ่อม',
    'สรุป PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[800]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icon/logo_SMH.png', width: 64, height: 64),
                  SizedBox(height: 8),
                  Text('SMH Repair App', style: TextStyle(color: Colors.white, fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.blue),
              title: Text('เกี่ยวกับ/คู่มือ', style: TextStyle(fontFamily: 'Kanit')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem, color: Colors.orange),
              title: Text('แจ้งบัค', style: TextStyle(fontFamily: 'Kanit')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => BugReportScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color:Colors.white,),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/role_select');
          },
        ),
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.blue[700],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: Colors.white.withOpacity(0.7),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.menu, size: 30, color: Colors.white),
                tooltip: 'เมนู',
                onSelected: (value) {
                  if (value == 'about') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AboutScreen()),
                    );
                  } else if (value == 'bug') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => BugReportScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'about', child: Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 8), Text('เกี่ยวกับ/คู่มือ')],)),
                  PopupMenuItem(value: 'bug', child: Row(children: [Icon(Icons.report_problem, color: Colors.orange), SizedBox(width: 8), Text('แจ้งบัค')],)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF667eea),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
        showUnselectedLabels: true,
        elevation: 10,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'แจ้งซ่อม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review_outlined),
            activeIcon: Icon(Icons.rate_review),
            label: 'ประเมิน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handyman_outlined),
            activeIcon: Icon(Icons.handyman),
            label: 'งานช่าง',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            activeIcon: Icon(Icons.schedule),
            label: 'PM',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'สรุปซ่อม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'สรุป PM',
          ),
        ],
      ),
    );
  }
}
