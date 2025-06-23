import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

// ย้าย class ออกมาไว้ด้านนอก
class _SummaryCardInfo {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  _SummaryCardInfo(this.title, this.count, this.icon, this.color);
}

class RepairSummaryTab extends StatefulWidget {
  @override
  State<RepairSummaryTab> createState() => _RepairSummaryTabState();
}

class _RepairSummaryTabState extends State<RepairSummaryTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Constants
  static const Duration _cacheDuration = Duration(hours: 24);
  static const String _apiUrl =
      'https://script.google.com/macros/s/AKfycbyf9Tun6tLW4miFxLXIMqGjUkolFA6Md_fcGJ_HdP_EUjIH_XMRiQYKIYMe4ROD_wNo/exec';

  // Variables
  late Future<List<dynamic>> _futureData;
  late TabController _tabController;
  DateTime? _lastFetchTime;
  String _selectedPeriod = 'ทั้งหมด';
  String _sortOrder = 'none'; // 'none', 'high_to_low', 'low_to_high'
  bool _isLoading = true;
  List<dynamic> _repairData = [];
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _futureData = _fetchDataWithCache();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Data fetching methods
  Future<List<dynamic>> _fetchDataWithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString('last_repair_summary_fetch_time');
    final cachedDataString = prefs.getString('cached_repair_summary_data');

    if (lastFetchString != null) {
      _lastFetchTime = DateTime.parse(lastFetchString);
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);

      if (timeSinceLastFetch < _cacheDuration && cachedDataString != null) {
        try {
          final cachedData = json.decode(cachedDataString);
          if (cachedData['status'] == 'success') {
            setState(() {
              _repairData = List<dynamic>.from(cachedData['data']);
              _isLoading = false;
              _error = '';
            });
            return _repairData;
          }
        } catch (e) {
          // If cached data is corrupted, fetch new data
        }
      }
    }

    return _fetchDataFromAPI();
  }

  Future<List<dynamic>> _fetchDataFromAPI() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _repairData = List<dynamic>.from(data['data']);

        // Cache the data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'last_repair_summary_fetch_time',
          DateTime.now().toIso8601String(),
        );
          await prefs.setString('cached_repair_summary_data', json.encode(data));

        setState(() {
          _lastFetchTime = DateTime.now();
            _error = '';
        });
      } else {
          setState(() {
            _error = data['message'] ?? 'เกิดข้อผิดพลาด';
          });
        }
      } else {
        setState(() {
          _error = 'โหลดข้อมูลไม่สำเร็จ (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาด: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    return _repairData;
  }

  void _refreshData() {
    setState(() {
      _futureData = _fetchDataFromAPI();
    });
  }

  // Data processing methods
  Map<String, int> _countByStatus(List<dynamic> data) {
    Map<String, int> statusMap = {};
    for (var repair in data) {
      String status = (repair['สถานะ'] ?? '').trim();
      statusMap[status] = (statusMap[status] ?? 0) + 1;
    }
    return statusMap;
  }

  Map<String, int> _countByMachine(List<dynamic> data) {
    Map<String, int> machineMap = {};
    for (var repair in data) {
      String machine = (repair['MachineName'] ?? 'ไม่ระบุ').trim();
      machineMap[machine] = (machineMap[machine] ?? 0) + 1;
    }
    return machineMap;
  }

  Map<String, int> _countByTechnician(List<dynamic> data) {
    Map<String, int> techMap = {};
    for (var repair in data) {
      String technicians = (repair['ช่างผู้ซ่อม'] ?? '').toString();
      if (technicians.isNotEmpty) {
        List<String> techList = technicians.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        for (String tech in techList) {
          techMap[tech] = (techMap[tech] ?? 0) + 1;
        }
      }
    }
    return techMap;
  }

  Map<String, int> _countByDepartment(List<dynamic> data) {
    final map = <String, int>{};
    for (var item in data) {
      final dept = item['แผนก']?.toString().trim();
      if (dept == null || dept.isEmpty || dept == 'null') continue;
      map[dept] = (map[dept] ?? 0) + 1;
    }
    return map;
  }

  // Sorting methods
  Map<String, int> _sortMapByValue(Map<String, int> map) {
    if (_sortOrder == 'none') return map;

    final entries = map.entries.toList();
    if (_sortOrder == 'high_to_low') {
      entries.sort((a, b) => b.value.compareTo(a.value));
    } else if (_sortOrder == 'low_to_high') {
      entries.sort((a, b) => a.value.compareTo(b.value));
    }

    return Map.fromEntries(entries);
  }

  void _setSortOrder(String order) {
    setState(() {
      _sortOrder = order;
    });
  }

  // Chart data methods
  List<PieChartSectionData> _buildPieChartSections(Map<String, int> statusMap) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
    ];

    return statusMap.entries.map((entry) {
      final index = statusMap.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Kanit',
        ),
      );
    }).toList();
  }

  List<PieChartSectionData> _getStatusPieData(Map<String, int> statusMap) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
    ];

    return statusMap.entries.map((entry) {
      final index = statusMap.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Kanit',
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _getMachineBarData(Map<String, int> machineMap) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.purple[400]!,
    ];

    return machineMap.entries.map((entry) {
      final index = machineMap.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: colors[index % colors.length],
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  List<BarChartGroupData> _getTechnicianBarData(Map<String, int> techMap) {
    final colors = [
      Colors.indigo[400]!,
      Colors.cyan[400]!,
      Colors.lime[400]!,
      Colors.amber[400]!,
      Colors.deepOrange[400]!,
    ];

    return techMap.entries.map((entry) {
      final index = techMap.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: colors[index % colors.length],
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  // Utility methods
  Map<String, Color> _getStatusColors() {
    return {
      'รอซ่อม': Colors.orange,
      'กำลังซ่อม': Colors.blue,
      'เสร็จสิ้น': Colors.green,
      'ยกเลิก': Colors.red,
    };
  }

  String _getLastUpdateText() {
    if (_lastFetchTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(_lastFetchTime!);
    if (diff.inMinutes < 1) {
      return 'อัปเดตล่าสุด: เมื่อสักครู่';
    } else if (diff.inMinutes < 60) {
      return 'อัปเดตล่าสุด: ${diff.inMinutes} นาทีที่แล้ว';
    } else if (diff.inHours < 24) {
      return 'อัปเดตล่าสุด: ${diff.inHours} ชั่วโมงที่แล้ว';
    } else {
      return 'อัปเดตล่าสุด: ${diff.inDays} วันที่แล้ว';
    }
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 4,
              child: Column(
                children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue[900],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue[900],
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Kanit',
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              fontFamily: 'Kanit',
            ),
            tabs: [
              Tab(text: 'ภาพรวม'),
              Tab(text: 'สถานะ'),
              Tab(text: 'เครื่องจักร'),
              Tab(text: 'ช่างซ่อม'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildStatusTab(),
                _buildMachineTab(),
                _buildTechnicianTab(),
              ],
            ),
              ),
            ],
          ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }

    final statusMap = _countByStatus(_repairData);
    final machineMap = _countByMachine(_repairData);
    final techMap = _countByTechnician(_repairData);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
            child: Text(
                        'สรุปภาพรวมการซ่อมบำรุง',
              style: TextStyle(
                          color: Colors.black87,
                fontWeight: FontWeight.bold,
                          fontSize: 16,
                fontFamily: 'Kanit',
              ),
            ),
          ),
                    Material(
                      color: Color(0xFFE3F0FF),
                      shape: CircleBorder(),
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: _refreshData,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.refresh,
                            color: Color(0xFF1976D2),
                            size: 20,
                          ),
                        ),
            ),
          ),
        ],
      ),
                SizedBox(height: 4),
                Text(
                  _getLastUpdateText(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey[400],
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          
          _buildSummaryCards(_repairData, statusMap),
          
          SizedBox(height: 12),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: InkWell(
                onTap: () => _tabController.animateTo(1),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'สถิติสถานะการซ่อม',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: _buildPieChartSections(statusMap),
                            centerSpaceRadius: 35,
                            sectionsSpace: 2,
                          ),
                        ),
              ),
            ],
          ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: InkWell(
                onTap: () => _tabController.animateTo(2),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'เครื่องจักรที่มีการซ่อมบ่อยที่สุด',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: machineMap.values.isNotEmpty ? machineMap.values.reduce((a, b) => a > b ? a : b).toDouble() : 10,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final machines = machineMap.keys.toList();
                                    if (value.toInt() < machines.length) {
                                      return Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          machines[value.toInt()].length > 8 
                                              ? '${machines[value.toInt()].substring(0, 8)}...'
                                              : machines[value.toInt()],
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontFamily: 'Kanit',
                                          ),
                                          textAlign: TextAlign.center,
          ),
    );
  }
                                    return Text('');
                                  },
                                  reservedSize: 35,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Kanit',
                                      ),
                  );
                },
              ),
            ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _getMachineBarData(machineMap),
                          ),
                        ),
              ),
            ],
          ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: InkWell(
                onTap: () => _tabController.animateTo(3),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                          Expanded(
                            child: Text(
                              'ช่างที่มีงานซ่อมมากที่สุด',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: techMap.values.isNotEmpty ? techMap.values.reduce((a, b) => a > b ? a : b).toDouble() : 10,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final techs = techMap.keys.toList();
                                    if (value.toInt() < techs.length) {
                                      return Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          techs[value.toInt()],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'Kanit',
                                          ),
                                          textAlign: TextAlign.center,
      ),
    );
  }
                                    return Text('');
                                  },
                                  reservedSize: 35,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 10,
          fontFamily: 'Kanit',
        ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _getTechnicianBarData(techMap),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<dynamic> data, Map<String, int> statusMap) {
    final totalRepairs = data.length;
    final completedRepairs = statusMap['ดำเนินการเสร็จสิ้น'] ?? 0;
    final inProgressRepairs = statusMap['กำลังดำเนินการ'] ?? 0;
    final pendingRepairs = statusMap['ยังไม่ดำเนินการ'] ?? 0;
    final waitingRepairs = statusMap['รอประเมิน'] ?? 0;

    final List<_SummaryCardInfo> cards = [
      _SummaryCardInfo('ทั้งหมด', totalRepairs, Icons.assignment, Colors.blue.shade700),
      _SummaryCardInfo('เสร็จสิ้น', completedRepairs, Icons.check_circle, Colors.green.shade700),
      _SummaryCardInfo('กำลังดำเนินการ', inProgressRepairs, Icons.pending, Colors.orange.shade700),
      _SummaryCardInfo('รอดำเนินการ', pendingRepairs, Icons.schedule, Colors.red.shade700),
      _SummaryCardInfo('รอประเมิน', waitingRepairs, Icons.rate_review, Colors.purple.shade700),
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: cards.map((c) => _buildSummaryCard(c)).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(_SummaryCardInfo info) {
    return InkWell(
      onTap: () {
        // Show detailed view based on card type
        Map<String, int> detailedData = {};
        String title = '';
        
        switch (info.title) {
          case 'ทั้งหมด':
            // Show all repairs grouped by status
            detailedData = _countByStatus(_repairData);
            title = 'งานซ่อมทั้งหมด';
            break;
          case 'เสร็จสิ้น':
            // Show completed repairs grouped by machine
            final completedRepairs = _repairData.where((repair) => 
              (repair['สถานะ'] ?? '').trim() == 'ดำเนินการเสร็จสิ้น' ||
              (repair['สถานะ'] ?? '').trim() == 'รอประเมิน'
            ).toList();
            detailedData = _countByMachine(completedRepairs);
            title = 'งานซ่อมที่เสร็จสิ้น';
            break;
          case 'กำลังดำเนินการ':
            // Show in-progress repairs grouped by technician
            final inProgressRepairs = _repairData.where((repair) => 
              (repair['สถานะ'] ?? '').trim() == 'กำลังดำเนินการ'
            ).toList();
            detailedData = _countByTechnician(inProgressRepairs);
            title = 'งานซ่อมที่กำลังดำเนินการ';
            break;
          case 'รอดำเนินการ':
            // Show pending repairs grouped by department
            final pendingRepairs = _repairData.where((repair) => 
              (repair['สถานะ'] ?? '').trim() == 'รอดำเนินการ' ||
              (repair['สถานะ'] ?? '').trim() == 'ยังไม่ดำเนินการ'
            ).toList();
            detailedData = _countByDepartment(pendingRepairs);
            title = 'งานซ่อมที่รอดำเนินการ';
            break;
          case 'รอประเมิน':
            // Show waiting for evaluation repairs grouped by machine
            final waitingRepairs = _repairData.where((repair) => 
              (repair['สถานะ'] ?? '').trim() == 'รอประเมิน'
            ).toList();
            detailedData = _countByMachine(waitingRepairs);
            title = 'งานซ่อมที่รอประเมิน';
            break;
        }
        
        if (detailedData.isNotEmpty) {
          _showDetailedView(title, detailedData, info.title);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: info.color.withOpacity(0.3),
        child: Padding(
          padding: EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
              Icon(
                info.icon,
                size: 28,
                color: info.color,
              ),
              SizedBox(height: 6),
          Text(
                info.count.toString(),
            style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: info.color,
              fontFamily: 'Kanit',
            ),
          ),
              SizedBox(height: 2),
          Text(
                info.title,
            style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
              fontFamily: 'Kanit',
            ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }

    final statusMap = _countByStatus(_repairData);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
              borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'สถิติตามสถานะ',
              style: TextStyle(
                color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                fontFamily: 'Kanit',
              ),
            ),
                    ),
                    Material(
                      color: Color(0xFFE3F0FF),
                      shape: CircleBorder(),
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: _refreshData,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.refresh,
                            color: Color(0xFF1976D2),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
            Text(
                  _getLastUpdateText(),
              style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey[400],
                    fontWeight: FontWeight.w500,
                fontFamily: 'Kanit',
              ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'แผนภูมิวงกลมสถานะ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
            ),
            SizedBox(height: 20),
                    Container(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: _getStatusPieData(statusMap),
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายละเอียดสถานะ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...statusMap.entries.map((entry) => _buildStatusListItem(entry.key, entry.value)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusListItem(String status, int count) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'ดำเนินการเสร็จสิ้น':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'กำลังดำเนินการ':
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        break;
      case 'ยังไม่ดำเนินการ':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'รอประเมิน':
        statusColor = Colors.purple;
        statusIcon = Icons.rate_review;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return InkWell(
      onTap: () {
        // Show detailed information for this status
        final repairsWithStatus = _repairData.where((repair) => 
          (repair['สถานะ'] ?? '').trim() == status
        ).toList();
        
        if (repairsWithStatus.isNotEmpty) {
          _showRepairDetailsDialog(status, repairsWithStatus);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Kanit',
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              color: statusColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }

    final machineMap = _countByMachine(_repairData);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
              borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'สถิติตามเครื่องจักร',
              style: TextStyle(
                color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                fontFamily: 'Kanit',
              ),
            ),
                    ),
                    Material(
                      color: Color(0xFFE3F0FF),
                      shape: CircleBorder(),
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: _refreshData,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.refresh,
                            color: Color(0xFF1976D2),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
            Text(
                  _getLastUpdateText(),
              style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey[400],
                    fontWeight: FontWeight.w500,
                fontFamily: 'Kanit',
              ),
                  textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      'เครื่องจักรที่มีการซ่อมบ่อยที่สุด',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: machineMap.values.isNotEmpty ? machineMap.values.reduce((a, b) => a > b ? a : b).toDouble() : 10,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final machines = machineMap.keys.toList();
                                  if (value.toInt() < machines.length) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        machines[value.toInt()].length > 8 
                                            ? '${machines[value.toInt()].substring(0, 8)}...'
                                            : machines[value.toInt()],
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'Kanit',
                                        ),
                                        textAlign: TextAlign.center,
      ),
    );
  }
                                  return Text('');
                                },
                                reservedSize: 35,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Kanit',
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _getMachineBarData(machineMap),
                        ),
                      ),
            ),
          ],
        ),
      ),
            ),
          ),
          
          SizedBox(height: 12),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      'รายละเอียดเครื่องจักร',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...machineMap.entries.map((entry) => _buildMachineListItem(entry.key, entry.value)),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMachineListItem(String machine, int count) {
    return InkWell(
      onTap: () {
        // Show detailed information for this machine
        final repairsWithMachine = _repairData.where((repair) => 
          (repair['MachineName'] ?? '').trim() == machine
        ).toList();
        
        if (repairsWithMachine.isNotEmpty) {
          _showRepairDetailsDialog('เครื่องจักร', repairsWithMachine);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.build,
              color: Colors.blue[600],
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                machine,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue[200]!,
                ),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }

    final techMap = _countByTechnician(_repairData);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
      width: double.infinity,
            margin: EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
              borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                    Expanded(
                      child: Text(
                        'สถิติตามช่างซ่อม',
                style: TextStyle(
                  color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                  fontFamily: 'Kanit',
                        ),
                ),
              ),
              Material(
                color: Color(0xFFE3F0FF),
                shape: CircleBorder(),
                child: InkWell(
                  customBorder: CircleBorder(),
                  onTap: _refreshData,
                  child: Padding(
                          padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh,
                      color: Color(0xFF1976D2),
                            size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
                SizedBox(height: 4),
          Text(
            _getLastUpdateText(),
            style: TextStyle(
                    fontSize: 11,
              color: Colors.blueGrey[400],
              fontWeight: FontWeight.w500,
              fontFamily: 'Kanit',
            ),
            textAlign: TextAlign.left,
          ),
              ],
            ),
          ),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'ช่างที่มีงานซ่อมมากที่สุด',
                  style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: techMap.values.isNotEmpty ? techMap.values.reduce((a, b) => a > b ? a : b).toDouble() : 10,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final techs = techMap.keys.toList();
                                  if (value.toInt() < techs.length) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        techs[value.toInt()],
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'Kanit',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return Text('');
                                },
                                reservedSize: 35,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                    style: TextStyle(
                                      fontSize: 10,
                      fontFamily: 'Kanit',
                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _getTechnicianBarData(techMap),
                        ),
                      ),
                    ),
                            ],
                          ),
                        ),
                      ),
          ),
          
          SizedBox(height: 12),
          
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.blue.shade100,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                    Text(
                      'รายละเอียดช่างซ่อม',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...techMap.entries.map((entry) => _buildTechnicianListItem(entry.key, entry.value)),
                            ],
                          ),
                        ),
                      ),
          ),
          
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTechnicianListItem(String technician, int count) {
    return InkWell(
      onTap: () {
        // Show detailed information for this technician
        final repairsWithTechnician = _repairData.where((repair) {
          String technicians = (repair['ช่างผู้ซ่อม'] ?? '').toString();
          List<String> techList = technicians.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          return techList.contains(technician);
        }).toList();
        
        if (repairsWithTechnician.isNotEmpty) {
          _showRepairDetailsDialog('ช่างซ่อม $technician', repairsWithTechnician);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: Colors.blue[600],
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                technician,
              style: TextStyle(
                fontSize: 16,
                  fontWeight: FontWeight.w600,
                fontFamily: 'Kanit',
              ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue[200]!,
                ),
              ),
              child: Text(
                count.toString(),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add detailed view dialog method
  void _showDetailedView(String title, Map<String, int> data, String type) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
      child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'รายละเอียด$title',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
            ),
          ],
        ),
                SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
        child: Column(
                      children: [
                        // Summary statistics
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                                'สรุปข้อมูล',
              style: TextStyle(
                                  fontSize: 14,
                fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
              ),
            ),
                              SizedBox(height: 6),
            Text(
                                'จำนวนรายการทั้งหมด: ${data.values.fold(0, (sum, count) => sum + count)} รายการ',
              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
              ),
            ),
            Text(
                                'ประเภทที่แตกต่างกัน: ${data.length} ประเภท',
              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
                        SizedBox(height: 12),
                        // Detailed list
                        ...data.entries.map((entry) {
                          final percentage = data.values.fold(0, (sum, count) => sum + count) > 0
                              ? (entry.value / data.values.fold(0, (sum, count) => sum + count) * 100).toStringAsFixed(1)
            : '0.0';

                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
            ),
          ],
        ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _getColorForIndex(data.keys.toList().indexOf(entry.key)),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
        child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                                        entry.key,
              style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                fontFamily: 'Kanit',
              ),
            ),
                                      SizedBox(height: 2),
            Text(
                                        '${entry.value} รายการ (${percentage}%)',
              style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                fontFamily: 'Kanit',
              ),
            ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getColorForIndex(data.keys.toList().indexOf(entry.key)).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getColorForIndex(data.keys.toList().indexOf(entry.key)),
                                    ),
                                  ),
                                  child: Text(
                                    entry.value.toString(),
              style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getColorForIndex(data.keys.toList().indexOf(entry.key)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.indigo[400]!,
      Colors.cyan[400]!,
      Colors.lime[400]!,
      Colors.amber[400]!,
    ];
    return colors[index % colors.length];
  }

  // Add repair details dialog method
  void _showRepairDetailsDialog(String status, List<dynamic> repairs) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'รายละเอียดงานซ่อม - $status',
          style: TextStyle(
                          fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Summary card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                                'สรุปข้อมูล',
              style: TextStyle(
                fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
              ),
            ),
                              SizedBox(height: 6),
            Text(
                                'จำนวนงานซ่อม: ${repairs.length} รายการ',
              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
              ),
            ),
          ],
        ),
                        ),
                        SizedBox(height: 12),
                        // Repair list
                        ...repairs.map((repair) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.build,
                                      color: Colors.blue[600],
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
          child: Text(
                                        'ใบแจ้งซ่อม #${repair['เลขที่ใบแจ้งซ่อม'] ?? 'ไม่ระบุ'}',
            style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
              fontFamily: 'Kanit',
            ),
          ),
        ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                _buildDetailRow('เครื่องจักร', repair['MachineName'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('รหัสเครื่อง', repair['MachineID'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('ชื่อผู้แจ้ง', repair['ชื่อผู้แจ้ง'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('แผนก', repair['แผนก'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('ผู้รับแจ้ง', repair['ผู้รับแจ้ง'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('ช่างผู้ซ่อม', repair['ช่างผู้ซ่อม'] ?? 'ไม่ระบุ'),
                                _buildDetailRow('วันที่แจ้ง', repair['วันที่แจ้ง'] ?? 'ไม่ระบุ'),
                                if (repair['รายละเอียด'] != null && repair['รายละเอียด'].toString().isNotEmpty)
                                  _buildDetailRow('รายละเอียด', repair['รายละเอียด']),
                                if (repair['เวลาเริ่มซ่อม'] != null && repair['เวลาเริ่มซ่อม'].toString().isNotEmpty)
                                  _buildDetailRow('เวลาเริ่มซ่อม', repair['เวลาเริ่มซ่อม']),
                                if (repair['เวลาเสร็จซ่อม'] != null && repair['เวลาเสร็จซ่อม'].toString().isNotEmpty)
                                  _buildDetailRow('เวลาเสร็จซ่อม', repair['เวลาเสร็จซ่อม']),
                                if (repair['อะไหร่ที่ใช้ในการซ่อม'] != null && repair['อะไหร่ที่ใช้ในการซ่อม'].toString().isNotEmpty)
                                  _buildDetailRow('อะไหล่ที่ใช้', repair['อะไหร่ที่ใช้ในการซ่อม']),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontFamily: 'Kanit',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
