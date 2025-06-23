import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PMZoneWidget extends StatefulWidget {
  final String zoneId;
  final String zoneNumber;
  final String cacheTimeKey;
  final String cacheDataKey;
  final String zoneTitle;

  const PMZoneWidget({
    Key? key,
    required this.zoneId,
    required this.zoneNumber,
    required this.cacheTimeKey,
    required this.cacheDataKey,
    required this.zoneTitle,
  }) : super(key: key);

  @override
  State<PMZoneWidget> createState() => _PMZoneWidgetState();
}

class _PMZoneWidgetState extends State<PMZoneWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> machines = [];
  bool isLoading = false;
  bool isInitialLoad = true;
  DateTime? lastUpdate;
  String currentFilter = 'ทั้งหมด';
  
  final Duration _cacheDuration = Duration(hours: 1);
  DateTime? _lastFetchTime;
  SharedPreferences? _prefs;

  final List<String> filters = [
    'ทั้งหมด',
    'คงค้าง',
    'สัปดาห์นี้',
    'ยังไม่ถึง'
  ];

  final String apiUrl = 'https://script.google.com/macros/s/AKfycbwvfUY_5R2RNz9VrQYn-vaaH5vpVsbPBPA_h-Q0qQEwyQ_ErOjLjdS_bg3SFXo4N87a/exec';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPreferencesAndLoadData();
  }

  Future<void> _initPreferencesAndLoadData() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadDataWithCache();
  }

  Future<void> _loadDataWithCache() async {
    final lastFetchString = _prefs?.getString(widget.cacheTimeKey);
    final cachedDataString = _prefs?.getString(widget.cacheDataKey);

    if (lastFetchString != null) {
      _lastFetchTime = DateTime.parse(lastFetchString);
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);

      if (timeSinceLastFetch < _cacheDuration && cachedDataString != null) {

        try {
          final cachedData = json.decode(cachedDataString) as List;
          final parsedData = cachedData.cast<Map<String, dynamic>>();
          
          setState(() {
            machines = parsedData
                .where((m) => m['ZoneID']?.toString().toUpperCase() == widget.zoneId || 
                              m['ZoneID']?.toString() == widget.zoneNumber)
                .toList();
            lastUpdate = _lastFetchTime;
            isInitialLoad = false;
          });
          return;
        } catch (e) {

        }
      }
    }
    
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (isLoading) return;
    
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final List<dynamic> data = json.decode(response.body);
        final newMachines = data
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => m['ZoneID']?.toString().toUpperCase() == widget.zoneId || 
                          m['ZoneID']?.toString() == widget.zoneNumber)
            .toList();
        
        await _saveToCache(newMachines);
        
        setState(() {
          machines = newMachines;
          lastUpdate = DateTime.now();
          isInitialLoad = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการดึงข้อมูล', style: TextStyle(fontFamily: 'Kanit')),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> data) async {
    try {
      final now = DateTime.now();
      await _prefs?.setString(widget.cacheTimeKey, now.toString());
      await _prefs?.setString(widget.cacheDataKey, json.encode(data));
      _lastFetchTime = now;
    } catch (e) {
    }
  }

  String _getLastUpdateText() {
    if (lastUpdate == null) return 'ยังไม่เคยอัปเดต';
    final now = DateTime.now();
    final diff = now.difference(lastUpdate!);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }

  List<Map<String, dynamic>> getPassed() {
    return machines.where((m) {
      final result = m['ผลการตรวจ']?.toString().trim();
      return result == 'ผ่าน';
    }).toList();
  }

  List<Map<String, dynamic>> getFailed() {
    return machines.where((m) {
      final result = m['ผลการตรวจ']?.toString().trim();
      return result == 'ไม่ผ่าน';
    }).toList();
  }

  List<Map<String, dynamic>> getNotInspected() {
    return machines.where((m) {
      final result = m['ผลการตรวจ']?.toString().trim();
      return result == null || result.isEmpty;
    }).toList();
  }

  List<Map<String, dynamic>> getPending(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    return list.where((m) {
      final nextCheck = _parseDate(m['NextCheckDate']);
      return nextCheck != null && nextCheck.isBefore(now);
    }).toList();
  }

  List<Map<String, dynamic>> getThisWeek(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    return list.where((m) {
      final nextCheck = _parseDate(m['NextCheckDate']);
      return nextCheck != null &&
          nextCheck.isAfter(now) &&
          nextCheck.isBefore(weekEnd.add(Duration(days: 1)));
    }).toList();
  }

  List<Map<String, dynamic>> getNotDue(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    return list.where((m) {
      final nextCheck = _parseDate(m['NextCheckDate']);
      return nextCheck != null && nextCheck.isAfter(now);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredMachines(List<Map<String, dynamic>> list) {
    switch (currentFilter) {
      case 'คงค้าง':
        return getPending(list);
      case 'สัปดาห์นี้':
        return getThisWeek(list);
      case 'ยังไม่ถึง':
        return getNotDue(list);
      default:
        return list;
    }
  }

  String _getDueStatus(Map<String, dynamic> machine) {
    final nextCheck = _parseDate(machine['NextCheckDate']);
    if (nextCheck == null) return 'ไม่ระบุ';
    
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    
    if (nextCheck.isBefore(now)) return 'คงค้าง';
    if (nextCheck.isAfter(now) && nextCheck.isBefore(weekEnd.add(Duration(days: 1)))) return 'สัปดาห์นี้';
    return 'ยังไม่ถึง';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        if (value.contains('-')) return DateTime.parse(value);
        if (value.contains('/')) {
          final parts = value.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;
            return DateTime(year, month, day);
          }
        }
        final timestamp = int.tryParse(value);
        if (timestamp != null) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = getPassed().length;
    final failedCount = getFailed().length;
    final notInspectedCount = getNotInspected().length;
    final progress = machines.isNotEmpty ? passedCount / machines.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zoneTitle, style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        )),
        backgroundColor: Colors.blue.shade800,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'ยังไม่ตรวจ ($notInspectedCount)'),
            Tab(text: 'ผ่าน ($passedCount)'),
            Tab(text: 'ไม่ผ่าน ($failedCount)'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white30,
          indicatorColor: Colors.green,
          labelStyle: TextStyle(fontFamily: 'Kanit', fontSize: 14),
          unselectedLabelStyle: TextStyle(fontFamily: 'Kanit', fontSize: 14),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScrollableTab(_getFilteredMachines(getNotInspected()), Colors.blue.shade100, progress, passedCount, failedCount),
                _buildScrollableTab(_getFilteredMachines(getPassed()), Colors.green.shade100, progress, passedCount, failedCount),
                _buildScrollableTab(_getFilteredMachines(getFailed()), Colors.red.shade100, progress, passedCount, failedCount),
              ],
            ),
    );
  }

  Widget _buildScrollableTab(List<Map<String, dynamic>> machines, Color bgColor, double progress, int passedCount, int failedCount) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeaderBox(progress, passedCount, failedCount),
        if (machines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 50, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'ไม่พบข้อมูลเครื่องจักร',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...machines.map((m) => _buildMachineCard(m, bgColor)).toList(),
      ],
    );
  }

  Widget _buildHeaderBox(double progress, int passedCount, int failedCount) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.zoneTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                  color: Colors.blue.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${machines.length} เครื่อง',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    _getLastUpdateText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Kanit',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: Colors.blue),
                onPressed: _refreshData,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: 8),
          Stack(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              if (failedCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    width: (1 - progress) * MediaQuery.of(context).size.width * 0.8,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ผ่าน $passedCount',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Kanit',
                  color: Colors.green,
                ),
              ),
              Text(
                'ไม่ผ่าน $failedCount',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Kanit',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                return Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: FilterChip(
                    label: Text(filter, style: TextStyle(fontFamily: 'Kanit')),
                    selected: currentFilter == filter,
                    onSelected: (selected) {
                      setState(() {
                        currentFilter = filter;
                      });
                    },
                    selectedColor: Colors.blue.shade200,
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: currentFilter == filter ? Colors.blue.shade800 : Colors.grey.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineCard(Map<String, dynamic> m, Color bgColor) {
    final dueStatus = _getDueStatus(m);
    return Card(
      margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMachineDetail(context, m),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${m['MachineID'] ?? 'ไม่มีรหัส'}',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(dueStatus),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dueStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '${m['MachineName'] ?? 'ไม่มีชื่อเครื่อง'}',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 12),
              _buildInfoRow(Icons.location_on, 'สถานที่ตั้ง', m['สถานที่ตั้ง']),
              _buildInfoRow(Icons.category, 'ประเภท', m['ประเภทเครื่องจักร']),
              _buildInfoRow(
                Icons.date_range, 
                'ตรวจครั้งต่อไป', 
                _parseDate(m['NextCheckDate']) != null ? 
                  '${_parseDate(m['NextCheckDate'])!.day}/${_parseDate(m['NextCheckDate'])!.month}/${_parseDate(m['NextCheckDate'])!.year}' : 
                  'ไม่ระบุ'
              ),
              if (m['ผลการตรวจ'] != null && m['ผลการตรวจ'].toString().isNotEmpty)
                _buildInfoRow(
                  m['ผลการตรวจ'] == 'ผ่าน' ? Icons.check_circle : Icons.warning,
                  'ผลการตรวจ',
                  '${m['ผู้ตรวจ'] ?? 'ไม่ระบุผู้ตรวจ'})',
                  color: m['ผลการตรวจ'] == 'ผ่าน' ? Colors.green : Colors.red,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'คงค้าง':
        return Colors.red;
      case 'สัปดาห์นี้':
        return Colors.orange;
      case 'ยังไม่ถึง':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value ?? 'ไม่ระบุ',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMachineDetail(BuildContext context, Map<String, dynamic> machine) {
    final dueStatus = _getDueStatus(machine);
    final inspectionTime = _parseDate(machine['เวลาที่ตรวจ']);
    final formattedInspectionTime = inspectionTime != null
        ? '${inspectionTime.year}-${inspectionTime.month.toString().padLeft(2, '0')}-${inspectionTime.day.toString().padLeft(2, '0')}'
        : 'ไม่ระบุ';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${machine['MachineID']} - ${machine['MachineName']}',
          style: TextStyle(fontFamily: 'Kanit'),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('สถานะ:', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(dueStatus),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dueStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildDetailRow('โซน', machine['ZoneID']?.toString()),
              _buildDetailRow('สถานที่ตั้ง', machine['สถานที่ตั้ง']),
              _buildDetailRow('ประเภทเครื่องจักร', machine['ประเภทเครื่องจักร']),
              _buildDetailRow('แผนก', machine['Department']),
              _buildDetailRow(
                'ตรวจครั้งต่อไป', 
                _parseDate(machine['NextCheckDate']) != null ? 
                  '${_parseDate(machine['NextCheckDate'])!.day}/${_parseDate(machine['NextCheckDate'])!.month}/${_parseDate(machine['NextCheckDate'])!.year}' : 
                  'ไม่ระบุวันที่'
              ),
              if (machine['ผลการตรวจ'] != null && machine['ผลการตรวจ'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(height: 24),
                    Text('ผลการตรวจล่าสุด', style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    )),
                    _buildDetailRow('ผู้ตรวจ', machine['ผู้ตรวจ']),
                    _buildDetailRow('เวลาที่ตรวจ', formattedInspectionTime),
                    _buildDetailRow('ผลการตรวจ', machine['ผลการตรวจ']),
                    _buildDetailRow('รายละเอียดการตรวจ', machine['รายละเอียดการตรวจ']),
                    _buildDetailRow('รายละเอียด/อะไหล่', machine['รายละเอียด / อะไหล่']),
                  ],
                ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToAssessmentScreen(context, machine);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  'ประเมิน PM',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Kanit',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'ไม่ระบุ',
              style: TextStyle(
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAssessmentScreen(BuildContext context, Map<String, dynamic> machine) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(machine: machine),
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class AssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> machine;

  const AssessmentScreen({required this.machine});

  @override
  _AssessmentScreenState createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  Map<String, String?> answers = {};
  bool isSubmitting = false;
  String inspectorName = '';
  String partsUsed = '';
  TextEditingController noteController = TextEditingController();
  TextEditingController partsUsedController = TextEditingController();
  TextEditingController inspectorNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ดึงค่าที่เคยกรอกไว้ (ถ้ามี)
    for (int i = 1; i <= 20; i++) {
      final val = widget.machine['ผลการตรวจ $i'];
      if (val != null) {
        answers['$i'] = val.toString();
      }
    }
    final noteVal = widget.machine['รายละเอียดการตรวจ'];
    answers['note'] = noteVal != null ? noteVal.toString() : '';
    final inspectorVal = widget.machine['ผู้ตรวจ'];
    inspectorName = inspectorVal != null ? inspectorVal.toString() : '';
    answers['inspector'] = inspectorName;
    final partsVal = widget.machine['รายละเอียด / อะไหล่'];
    partsUsed = partsVal != null ? partsVal.toString() : '';
    noteController.text = answers['note'] ?? '';
    partsUsedController.text = partsUsed;
    inspectorNameController.text = inspectorName;
  }

  @override
  void dispose() {
    noteController.dispose();
    partsUsedController.dispose();
    inspectorNameController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getQuestions() {
    List<Map<String, dynamic>> questions = [];
    for (int i = 1; i <= 20; i++) {
      if (widget.machine['QuestionText $i'] != null && 
          widget.machine['QuestionText $i'].toString().trim().isNotEmpty) {
        questions.add({
          'id': '$i',
          'text': widget.machine['QuestionText $i'],
          'type': 'radio',
          'options': ['ผ่าน', 'ไม่ผ่าน']
        });
      }
    }
    return questions;
  }

  @override
  Widget build(BuildContext context) {
    final questions = getQuestions();

    return Scaffold(
      appBar: AppBar(
        title: Text('ประเมิน PM', style: TextStyle(fontFamily: 'Kanit')),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.machine['MachineID']} - ${widget.machine['MachineName']}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            SizedBox(height: 24),
            ...questions.map((question) => Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _buildQuestion(question),
              ),
            )),
            SizedBox(height: 24),
            Text('หมายเหตุเพิ่มเติม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800], fontFamily: 'Kanit')),
            SizedBox(height: 8),
            TextFormField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'เช่น ข้อสังเกตเพิ่มเติม หรือปัญหาที่พบ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                labelStyle: TextStyle(fontFamily: 'Kanit'),
              ),
              style: TextStyle(fontSize: 16, fontFamily: 'Kanit'),
              maxLines: 3,
              keyboardType: TextInputType.text,
              onChanged: (value) {
                answers['note'] = value;
              },
            ),
            SizedBox(height: 24),
            Text('อะไหล่ที่ใช้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800], fontFamily: 'Kanit')),
            SizedBox(height: 8),
            TextFormField(
              controller: partsUsedController,
              decoration: InputDecoration(
                hintText: 'ระบุอะไหล่หรือวัสดุที่ใช้ในการซ่อม/บำรุง ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                labelStyle: TextStyle(fontFamily: 'Kanit'),
              ),
              style: TextStyle(fontSize: 16, fontFamily: 'Kanit'),
              maxLines: 2,
              onChanged: (value) {
                partsUsed = value;
              },
            ),
            SizedBox(height: 24),
            Text('ชื่อผู้ตรวจ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800], fontFamily: 'Kanit')),
            SizedBox(height: 8),
            TextFormField(
              controller: inspectorNameController,
              decoration: InputDecoration(
                hintText: 'กรอกชื่อช่างผู้ตรวจสอบ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                labelStyle: TextStyle(fontFamily: 'Kanit'),
              ),
              style: TextStyle(fontSize: 16, fontFamily: 'Kanit'),
              onChanged: (value) {
                inspectorName = value;
              },
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: isSubmitting ? null : _submitAssessment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'บันทึกผลการตรวจ',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Kanit',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${question['id']}. ${question['text']}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: (question['options'] as List).map<Widget>((option) {
            return Expanded(
              child: RadioListTile<String>(
                title: Text(option, style: TextStyle(fontFamily: 'Kanit', fontSize: 20, fontWeight: FontWeight.bold)),
                value: option,
                groupValue: answers[question['id']],
                onChanged: (value) {
                  setState(() {
                    answers[question['id']] = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submitAssessment() async {
    final questions = getQuestions();
    if (inspectorName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกชื่อผู้ตรวจ', style: TextStyle(fontFamily: 'Kanit')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (answers.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณาตอบคำถามให้ครบทุกข้อ', style: TextStyle(fontFamily: 'Kanit')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final allPassed = questions.every((q) => answers[q['id']] == 'ผ่าน');
      final result = {
        'action': 'update',
        'MachineID': widget.machine['MachineID'],
        'ผลการตรวจ': allPassed ? 'ผ่าน' : 'ไม่ผ่าน',
        'ผู้ตรวจ': inspectorName,
        'เวลาที่ตรวจ': DateTime.now().toString(),
        'รายละเอียดการตรวจ': answers['note'] ?? '',
        'รายละเอียด / อะไหล่': partsUsed,
      };
      if (allPassed) {
        final nextCheckDate = DateTime.now().add(Duration(days: 14));
        result['NextCheckDate'] = nextCheckDate.toIso8601String();
      }
      for (int i = 1; i <= 20; i++) {
        if (answers['$i'] != null) {
          result['ผลการตรวจ $i'] = answers['$i']!;
        }
      }
      final url = 'https://script.google.com/macros/s/AKfycbwN2FR1HCF-RbUF9FZUYQrtr3RcMSK8W-zrDJmcEU3AdmB7SlDcfM_NwjPhfCI1x-f4/exec';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(result),
      );
      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('บันทึกผลการตรวจเรียบร้อย', style: TextStyle(fontFamily: 'Kanit')),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
            return;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกผลการตรวจเรียบร้อย', style: TextStyle(fontFamily: 'Kanit')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      }
      try {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: \\${responseData['message'] ?? 'ไม่สามารถบันทึกข้อมูลได้'}', style: TextStyle(fontFamily: 'Kanit')),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการประมวลผลผลลัพธ์', style: TextStyle(fontFamily: 'Kanit')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: \\${e.toString()}', style: TextStyle(fontFamily: 'Kanit')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }
} 