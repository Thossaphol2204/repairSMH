import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../screens/bug_report_screen.dart';

class WorkOrderTab extends StatefulWidget {
  final int initialTabIndex;
  final bool hideTabBar;
  WorkOrderTab({this.initialTabIndex = 0, this.hideTabBar = false});
  @override
  _WorkOrderTabState createState() => _WorkOrderTabState();
}

class _WorkOrderTabState extends State<WorkOrderTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _workOrders = [];
  String _error = '';
  String _urgentFilter = 'ทั้งหมด';
  final List<String> _urgentOptions = ['ทั้งหมด', 'ด่วนมาก', 'ไม่ด่วน'];
  String _technicianFilter = 'ทั้งหมด';
  List<String> _technicianOptions = ['ทั้งหมด'];
  List<Map<String, dynamic>> _allTechnicians = []; // [{name: 'สมสัก', position: 'ช่างซ่อม'}]
  List<Map<String, dynamic>> _allReceivers = []; // [{name: 'สมชาย', position: 'ผู้รับแจ้ง'}]
  late TabController _tabController;
  DateTime? _lastFetchTime;

  // Cache constants
  static const Duration _cacheDuration = Duration(hours: 24);
  static const String _workOrderApiUrl =
      'https://script.google.com/macros/s/AKfycbyf9Tun6tLW4miFxLXIMqGjUkolFA6Md_fcGJ_HdP_EUjIH_XMRiQYKIYMe4ROD_wNo/exec';
  static const String _staffApiUrl =
      'https://script.google.com/macros/s/AKfycbzm347sw9PYuQzMni5wq5HUC7NtG4xsZeOj0PPrULER_DjSnfT3Z38dHZZvD5pb6b7a/exec'; // ใส่ URL ของ Apps Script ช่าง

  // Technician cache
  static const String _technicianCacheKey = 'cached_technician_data';
  static const String _technicianCacheTimeKey = 'last_technician_fetch_time';
  static const Duration _technicianCacheDuration = Duration(hours: 24);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _loadWorkOrdersWithCache();
    _loadTechniciansAndReceivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkOrdersWithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString('last_work_order_fetch_time');
    final cachedDataString = prefs.getString('cached_work_order_data');

    if (lastFetchString != null) {
      _lastFetchTime = DateTime.parse(lastFetchString);
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);

      if (timeSinceLastFetch < _cacheDuration && cachedDataString != null) {
        try {
          final cachedData = json.decode(cachedDataString);
          if (cachedData['status'] == 'success') {
            setState(() {
              _workOrders = List<Map<String, dynamic>>.from(cachedData['data']);
              _isLoading = false;
              _error = '';
            });
            return;
          }
        } catch (e) {
        }
      }
    }

    await _loadWorkOrdersFromAPI();
  }

  Future<void> _loadWorkOrdersFromAPI() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http
          .get(Uri.parse(_workOrderApiUrl))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _workOrders = List<Map<String, dynamic>>.from(data['data']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'last_work_order_fetch_time',
            DateTime.now().toIso8601String(),
          );
          await prefs.setString('cached_work_order_data', json.encode(data));

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
  }

  Future<void> _refreshData() async {
    await _loadWorkOrdersFromAPI();
    final staffData = await _fetchTechniciansAndReceivers(forceRefresh: true);
    if (mounted) {
      setState(() {
        _allTechnicians = staffData['technicians'];
        _allReceivers = staffData['receivers'];
        _technicianOptions = [
          'ทั้งหมด',
          ..._allTechnicians.map((e) => e['name']?.toString() ?? '')
        ];
        _technicianFilter = 'ทั้งหมด';
      });
    }
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

  List<Map<String, dynamic>> _filterByStatus(String status) {
    if (status == 'ดำเนินการเสร็จสิ้น') {
      // รวมสถานะที่เสร็จสิ้นแล้ว
      return _workOrders.where((order) {
        String orderStatus = (order['สถานะ'] ?? '').trim();
        return orderStatus == 'ดำเนินการเสร็จสิ้น' ||
            orderStatus == 'รอประเมิน';
      }).toList();
    }
    return _workOrders
        .where((order) => (order['สถานะ'] ?? '').trim() == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideTabBar) {
      final statusList = [
        'รอดำเนินการ',
        'ยังไม่ดำเนินการ',
        'กำลังดำเนินการ',
        'ดำเนินการเสร็จสิ้น',
      ];
      return _buildWorkOrderList(statusList[widget.initialTabIndex]);
    }
    return Column(
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
            Tab(text: 'จ่ายงานช่าง'),
            Tab(text: 'ช่างรับงาน'),
            Tab(text: 'กำลังดำเนินการ'),
            Tab(text: 'เสร็จสิ้น'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWorkOrderList('รอดำเนินการ'),
              _buildWorkOrderList('ยังไม่ดำเนินการ'),
              _buildWorkOrderList('กำลังดำเนินการ'),
              _buildWorkOrderList('ดำเนินการเสร็จสิ้น'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkOrderList(String status) {
    Widget filterWidget;
    if (status == 'รอดำเนินการ') {
      filterWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ประเภทงาน:',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
              ),
              DropdownButton<String>(
                value: _urgentFilter,
                items:
                    _urgentOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, style: TextStyle(fontFamily: 'Kanit')),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _urgentFilter = value!;
                  });
                },
              ),
            ],
          ),
        ],
      );
    } else if (status == 'ยังไม่ดำเนินการ' ||
        status == 'กำลังดำเนินการ' ||
        status == 'ดำเนินการเสร็จสิ้น') {
      filterWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ช่างผู้ซ่อม:',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
              ),
              DropdownButton<String>(
                value: _technicianFilter,
                items:
                    _technicianOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, style: TextStyle(fontFamily: 'Kanit')),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _technicianFilter = value!;
                  });
                },
              ),
            ],
          ),
        ],
      );
    } else {
      filterWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [],
      );
    }

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
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Kanit',
                        ),
                        child: filterWidget,
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
          _buildWorkOrderListContent(status),
        ],
      ),
    );
  }

  Widget _buildWorkOrderListContent(String status) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }
    var filtered = _filterByStatus(status);
    if (status == 'รอดำเนินการ' && _urgentFilter != 'ทั้งหมด') {
      filtered =
          filtered
              .where(
                (order) => (order['ประเภทงาน'] ?? '').trim() == _urgentFilter,
              )
              .toList();
    }
    if (status == 'ยังไม่ดำเนินการ' && _technicianFilter != 'ทั้งหมด') {
      filtered =
          filtered.where((order) {
            String technicians = order['ช่างผู้ซ่อม']?.toString() ?? '';
            List<String> technicianList =
                technicians
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
            return technicianList.contains(_technicianFilter);
          }).toList();
    }
    if (status == 'กำลังดำเนินการ' && _technicianFilter != 'ทั้งหมด') {
      filtered =
          filtered.where((order) {
            String technicians = order['ช่างผู้ซ่อม']?.toString() ?? '';
            List<String> technicianList =
                technicians
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
            return technicianList.contains(_technicianFilter);
          }).toList();
    }
    if (status == 'ดำเนินการเสร็จสิ้น' && _technicianFilter != 'ทั้งหมด') {
      filtered =
          filtered.where((order) {
            String technicians = order['ช่างผู้ซ่อม']?.toString() ?? '';
            List<String> technicianList =
                technicians
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
            return technicianList.contains(_technicianFilter);
          }).toList();
    }
    if (filtered.isEmpty) {
      return Center(child: Text('ไม่พบข้อมูล'));
    }
    return Column(
      children:
          filtered
              .map(
                (order) => Card(
                  margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ใบแจ้งซ่อม #${order['เลขที่ใบแจ้งซ่อม']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.blue[900],
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'วันที่แจ้ง: ' + formatDate(order['วันที่แจ้ง']?.toString()),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildStatusChip(order['สถานะ']?.toString() ?? ''),
                                SizedBox(height: 8),
                                _buildTechnicianChip(order['ช่างผู้ซ่อม']?.toString() ?? '-'),
                              ],
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        _buildInfoRow(
                          'ชื่อเครื่อง',
                          order['MachineName']?.toString() ?? '',
                        ),
                        _buildInfoRow(
                          'รหัสเครื่อง',
                          order['MachineID']?.toString() ?? '',
                        ),
                        _buildInfoRow(
                          'ประเภทงาน',
                          order['ประเภทงาน']?.toString() ?? '',
                        ),
                        _buildInfoRow(
                          'ชื่อผู้แจ้ง',
                          order['ชื่อผู้แจ้ง']?.toString() ?? '',
                        ),
                        _buildInfoRow('แผนก', order['แผนก']?.toString() ?? ''),
                        _buildInfoRow(
                          'ผู้รับแจ้ง',
                          order['ผู้รับแจ้ง']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'ปัญหา',
                          order['รายละเอียด']?.toString() ?? '',
                        ),
                        if (status == 'รอดำเนินการ') ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[900]!],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.assignment_ind,
                                color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                'รับงานและกำหนดช่าง',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed:
                                  () => _showAssignTechnicianDialog(order),
                            ),
                          ),
                        ],
                        if (status == 'ยังไม่ดำเนินการ') ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green[600]!,
                                  Colors.green[800]!,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                'เริ่มทำงาน',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _showStartWorkDialog(order),
                            ),
                          ),
                        ],
                        if (status == 'กำลังดำเนินการ') ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange[600]!,
                                  Colors.orange[800]!,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                'เสร็จสิ้น',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _showCompleteWorkDialog(order),
                            ),
                          ),
                        ],
                        if ((order['สถานะ'] ?? '') == 'ดำเนินการเสร็จสิ้น' ||
                            (order['สถานะ'] ?? '') == 'รอประเมิน') ...[
                          SizedBox(height: 16),
                          Text(
                            'ช่างผู้ซ่อม:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildTechnicianChip(
                            order['ช่างผู้ซ่อม']?.toString() ?? '-',
                          ),
                          SizedBox(height: 16),
                          _buildInfoRow(
                            'อะไหล่ที่ใช้',
                            order['อะไหร่ที่ใช้ในการซ่อม']?.toString() ?? '-',
                          ),
                          _buildInfoRow(
                            'เวลาเริ่มซ่อม',
                            formatDate(order['เวลาเริ่มซ่อม']?.toString()),
                          ),
                          _buildInfoRow(
                            'เวลาเสร็จซ่อม',
                            formatDate(order['เวลาเสร็จซ่อม']?.toString()),
                          ),
                          SizedBox(height: 16),
                          // แสดงดาวประเมินที่มีอยู่
                          Row(
                            children: [
                              Text(
                                'การประเมิน: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              _buildStarRating(
                                int.tryParse(order['ดาวประเมิน']?.toString() ?? '0') ?? 0,
                                false,
                                null,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianChip(String technicians) {
    List<String> technicianList = technicians
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (technicianList.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Text(
          'ยังไม่กำหนด',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    int maxShow = 2;
    List<String> showList = technicianList.take(maxShow).toList();
    bool hasMore = technicianList.length > maxShow;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...showList.map(
          (tech) => Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              tech,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (hasMore)
          Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('รายชื่อช่างที่ทำงานนี้ทั้งหมด'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: technicianList
                          .map((tech) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  tech,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ))
                          .toList(),
                    ),
                    actions: [
                      TextButton(
                        child: Text('ปิด'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'และคนอื่นๆ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'รอรับแจ้ง':
        color = Colors.orange;
        break;
      case 'ยังไม่ดำเนินการ':
        color = Colors.deepOrange;
        break;
      case 'กำลังดำเนินการ':
        color = Colors.blue;
        break;
      case 'ดำเนินการเสร็จสิ้น':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAssignTechnicianDialog(Map<String, dynamic> order) async {
    String? selectedTechnician = '';
    String? selectedReceiver = '';
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('รับงานและกำหนดช่าง'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'ชื่อผู้รับแจ้ง',
                        prefixIcon: Icon(Icons.person_outline, color: Colors.blue[900]),
                        filled: true,
                        fillColor: Colors.blue[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      value: selectedReceiver?.isEmpty == true ? null : selectedReceiver,
                      items: _allReceivers.map((receiver) {
                        return DropdownMenuItem(
                          value: receiver['name']?.toString() ?? '',
                          child: Text(
                            receiver['name']?.toString() ?? '',
                            style: TextStyle(fontFamily: 'Kanit', fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReceiver = value ?? '';
                        });
                      },
                      dropdownColor: Colors.white,
                      style: TextStyle(color: Colors.blue[900], fontFamily: 'Kanit', fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'ช่างผู้ซ่อม',
                        prefixIcon: Icon(Icons.engineering, color: Colors.blue[900]),
                        filled: true,
                        fillColor: Colors.blue[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      value: selectedTechnician?.isEmpty == true ? null : selectedTechnician,
                      items: _allTechnicians.map((tech) {
                        return DropdownMenuItem(
                          value: tech['name']?.toString() ?? '',
                          child: Text(
                            tech['name']?.toString() ?? '',
                            style: TextStyle(fontFamily: 'Kanit', fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTechnician = value ?? '';
                        });
                      },
                      dropdownColor: Colors.white,
                      style: TextStyle(color: Colors.blue[900], fontFamily: 'Kanit', fontSize: 16),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('ยกเลิก'),
                  onPressed: () {
                    // ปิดคีย์บอร์ดก่อนปิด dialog
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  child: Text('ยืนยัน'),
                  onPressed: () async {
                    if ((selectedTechnician?.isNotEmpty ?? false) &&
                        (selectedReceiver?.isNotEmpty ?? false)) {
                      // Close dialog immediately
                      Navigator.pop(context);
                      
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('กำลังอัพเดตข้อมูล...'),
                            ],
                          ),
                          backgroundColor: Colors.blue[600],
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Perform API call in background
                      _updateWorkOrder(
                        order,
                        [selectedTechnician!],
                        selectedReceiver!,
                        '', // Empty machine ID since we removed it
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'กรุณาเลือกชื่อผู้รับแจ้งและช่างผู้ซ่อม',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateWorkOrder(
    Map<String, dynamic> order,
    List<String> technicians,
    String receiverName,
    String machineId, // Keep parameter for compatibility but don't use it
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          _workOrderApiUrl,
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateRepair',
          'เลขที่ใบแจ้งซ่อม': order['เลขที่ใบแจ้งซ่อม'],
          'สถานะ': 'ยังไม่ดำเนินการ',
          'ช่างผู้ซ่อม': technicians.join(', '),
          'ผู้รับแจ้ง': receiverName,
          // Removed machine ID from API call
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัพเดตข้อมูลสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshData();
        _tabController.animateTo(1);
        // log การเปลี่ยนแปลง
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('userName') ?? 'ไม่ระบุ';
        await logWorkOrderAction(
          workOrderId: order['เลขที่ใบแจ้งซ่อม']?.toString() ?? '',
          user: userName,
          action: 'update_status',
          oldStatus: order['สถานะ']?.toString() ?? '',
          newStatus: 'ยังไม่ดำเนินการ',
          comment: 'Assign: ${technicians.join(', ')} / Receiver: $receiverName',
        );
      } else {
        throw Exception('Failed to update work order');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStartWorkDialog(Map<String, dynamic> order) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('เริ่มทำงาน'),
          content: Text(
            'คุณต้องการเริ่มทำงานใบแจ้งซ่อม #${order['เลขที่ใบแจ้งซ่อม']} ใช่หรือไม่?',
          ),
          actions: [
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text('ยืนยัน'),
              onPressed: () async {
                // Close dialog immediately
                Navigator.pop(context);
                
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('กำลังเริ่มทำงาน...'),
                      ],
                    ),
                    backgroundColor: Colors.green[600],
                    duration: Duration(seconds: 2),
                  ),
                );
                
                // Perform API call in background
                _startWorkOrder(order);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startWorkOrder(Map<String, dynamic> order) async {
    try {
      final now = DateTime.now();
      final startTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse(
          _workOrderApiUrl,
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateRepair',
          'เลขที่ใบแจ้งซ่อม': order['เลขที่ใบแจ้งซ่อม'],
          'สถานะ': 'กำลังดำเนินการ',
          'เวลาเริ่มซ่อม': startTime,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เริ่มทำงานสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshData();
        _tabController.animateTo(2);
        // log การเปลี่ยนแปลง
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('userName') ?? 'ไม่ระบุ';
        await logWorkOrderAction(
          workOrderId: order['เลขที่ใบแจ้งซ่อม']?.toString() ?? '',
          user: userName,
          action: 'update_status',
          oldStatus: order['สถานะ']?.toString() ?? '',
          newStatus: 'กำลังดำเนินการ',
          comment: 'Start work',
        );
      } else {
        throw Exception('Failed to start work order');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompleteWorkDialog(Map<String, dynamic> order) async {
    // ดึงรายชื่อช่างที่ถูก assign ในงานนี้
    List<String> assignedTechnicians = (order['ช่างผู้ซ่อม']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    // ให้เลือกไว้ล่วงหน้า
    List<String> selectedTechnicians = List<String>.from(assignedTechnicians);
    String partsUsed = '';

    // สร้างรายชื่อช่างทั้งหมด (assigned + other)
    List<String> allTechNames = _allTechnicians.map((e) => e['name']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    List<String> otherTechnicians = allTechNames.where((name) => !assignedTechnicians.contains(name)).toList();
    List<MultiSelectItem<String>> otherTechItems = otherTechnicians.map((name) => MultiSelectItem<String>(name, name)).toList();

    List<Map<String, String>> partsList = [];
    final List<TextEditingController> partNameControllers = [];
    final List<TextEditingController> partQtyControllers = [];
    void addPartRow() {
      partNameControllers.add(TextEditingController());
      partQtyControllers.add(TextEditingController());
    }
    // เริ่มต้นมี 1 แถว
    if (partNameControllers.isEmpty) addPartRow();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('เสร็จงาน'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ใบแจ้งซ่อม #${order['เลขที่ใบแจ้งซ่อม']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[900],
                      ),
                    ),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ช่างที่ได้รับมอบหมาย', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: assignedTechnicians.map((techName) {
                        final isSelected = selectedTechnicians.contains(techName);
                        return FilterChip(
                          label: Text(techName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTechnicians.add(techName);
                              } else {
                                selectedTechnicians.remove(techName);
                              }
                            });
                          },
                          selectedColor: Colors.blue[100],
                          checkmarkColor: Colors.blue[900],
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('เลือกช่างคนอื่นที่เกี่ยวข้อง', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                    ),
                    SizedBox(height: 8),
                    MultiSelectDialogField<String>(
                      items: otherTechItems,
                      initialValue: selectedTechnicians.where((name) => otherTechnicians.contains(name)).toList(),
                      searchable: true,
                      title: Text('ช่างคนอื่น'),
                      buttonText: Text('เลือกช่างคนอื่น'),
                      selectedColor: Colors.blue[900],
                      chipDisplay: MultiSelectChipDisplay.none(),
                      listType: MultiSelectListType.LIST,
                      onConfirm: (values) {
                        setState(() {
                          // ลบช่างคนอื่นที่ไม่ได้เลือกออกจาก selectedTechnicians
                          selectedTechnicians.removeWhere((name) => otherTechnicians.contains(name));
                          // เพิ่มช่างคนอื่นที่เลือกใหม่
                          selectedTechnicians.addAll(List<String>.from(values));
                        });
                      },
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                    ),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'กรุณาระบุอะไหล่ที่ใช้ในการซ่อมหากมี',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Column(
                      children: List.generate(partNameControllers.length, (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: partNameControllers[i],
                                decoration: InputDecoration(
                                  labelText: 'ชื่ออะไหล่',
                                  labelStyle: TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: partNameControllers.length > 1
                                    ? IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            partNameControllers.removeAt(i);
                                            partQtyControllers.removeAt(i);
                                          });
                                        },
                                      )
                                    : null,
                                ),
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: partQtyControllers[i],
                                decoration: InputDecoration(
                                  labelText: 'จำนวน',
                                  labelStyle: TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('เพิ่มแถวอะไหล่'),
                        onPressed: () {
                          setState(() {
                            addPartRow();
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('ยกเลิก'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text('ยืนยัน'),
                  onPressed: () async {
                    if (selectedTechnicians.isNotEmpty) {
                      // รวมอะไหล่เป็นข้อความเดียว
                      String partsText = List.generate(partNameControllers.length, (i) {
                        final name = partNameControllers[i].text.trim();
                        final qty = partQtyControllers[i].text.trim();
                        if (name.isNotEmpty && qty.isNotEmpty) {
                          return '$name x$qty';
                        }
                        return '';
                      }).where((e) => e.isNotEmpty).join(', ');
                      // Close dialog immediately
                      Navigator.pop(context);
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('กำลังเสร็จงาน...'),
                            ],
                          ),
                          backgroundColor: Colors.orange[600],
                          duration: Duration(seconds: 2),
                        ),
                      );
                      // Perform API call in background
                      _completeWorkOrder(
                        order,
                        selectedTechnicians,
                        partsText,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('กรุณาเลือกช่างที่เกี่ยวข้อง'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeWorkOrder(
    Map<String, dynamic> order,
    List<String> technicians,
    String partsUsed,
  ) async {
    try {
      final now = DateTime.now();
      final endTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse(
          _workOrderApiUrl,
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateRepair',
          'เลขที่ใบแจ้งซ่อม': order['เลขที่ใบแจ้งซ่อม'],
          'สถานะ': 'รอประเมิน',
          'เวลาเสร็จซ่อม': endTime,
          'ช่างผู้ซ่อม': technicians.join(', '),
          'อะไหร่ที่ใช้ในการซ่อม': partsUsed,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เสร็จงานสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshData();
        _tabController.animateTo(3);
        // log การเปลี่ยนแปลง
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('userName') ?? 'ไม่ระบุ';
        await logWorkOrderAction(
          workOrderId: order['เลขที่ใบแจ้งซ่อม']?.toString() ?? '',
          user: userName,
          action: 'update_status',
          oldStatus: order['สถานะ']?.toString() ?? '',
          newStatus: 'รอประเมิน',
          comment: 'Complete work. Parts: $partsUsed',
        );
      } else {
        throw Exception('Failed to complete work order');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTechniciansAndReceivers() async {
    final staffData = await _fetchTechniciansAndReceivers();
    if (mounted) {
      setState(() {
        _allTechnicians = staffData['technicians'];
        _technicianOptions = [
          'ทั้งหมด',
          ..._allTechnicians.map((e) => e['name']?.toString() ?? '')
        ];
        _allReceivers = staffData['receivers'];
      });
    }
  }

  Future<Map<String, dynamic>> _fetchTechniciansAndReceivers(
      {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString(_technicianCacheTimeKey);
    final cachedDataString = prefs.getString(_technicianCacheKey);

    if (!forceRefresh && lastFetchString != null && cachedDataString != null) {
      final lastFetch = DateTime.tryParse(lastFetchString);
      if (lastFetch != null &&
          DateTime.now().difference(lastFetch) < _technicianCacheDuration) {
        try {
          final cachedData = json.decode(cachedDataString);
          if (cachedData['status'] == 'success') {
            return {
              'technicians':
                  List<Map<String, dynamic>>.from(cachedData['technicians']),
              'receivers':
                  List<Map<String, dynamic>>.from(cachedData['receivers']),
            };
          }
        } catch (_) {}
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse(_staffApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Flutter App',
            },
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await prefs.setString(
              _technicianCacheTimeKey, DateTime.now().toIso8601String());
          await prefs.setString(_technicianCacheKey, json.encode(data));
          return {
            'technicians':
                List<Map<String, dynamic>>.from(data['technicians']),
            'receivers': List<Map<String, dynamic>>.from(data['receivers']),
          };
        }
      }
    } catch (_) {}

    return {'technicians': [], 'receivers': []};
  }

  // ฟังก์ชันสร้างดาวประเมิน
  Widget _buildStarRating(int rating, bool isInteractive, Function(int)? onRatingChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: isInteractive && onRatingChanged != null
              ? () => onRatingChanged(index + 1)
              : null,
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: index < rating ? Colors.amber : Colors.grey[400],
            size: 24,
          ),
        );
      }),
    );
  }

  String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return isoString;
    }
  }

  // ฟังก์ชัน log ไป Google Sheet
  Future<void> logWorkOrderAction({
    required String workOrderId,
    required String user,
    required String action,
    String? oldStatus,
    String? newStatus,
    String? comment,
  }) async {
    final url = 'https://script.google.com/macros/s/AKfycby5qGKd5XfKAeXj_CjzrIJHEJURdnq3jxD9HeP7CII-aQ616_Q8h0EC_B_nWhwslsxZ/exec';
    await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'workOrderId': workOrderId,
        'timestamp': DateTime.now().toIso8601String(),
        'user': user,
        'action': action,
        'oldStatus': oldStatus ?? '',
        'newStatus': newStatus ?? '',
        'comment': comment ?? '',
      }),
    );
  }
}
