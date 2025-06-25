import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PMSummaryTab extends StatefulWidget {
  @override
  _PMSummaryTabState createState() => _PMSummaryTabState();
}

class _PMSummaryTabState extends State<PMSummaryTab> {
  final String apiUrl = 'https://script.google.com/macros/s/AKfycbwMmTsDyeIMEezM5LLYj-cfmWNkeJyR54ZuXvAHqKzcogXxNA-cPmwHG28PslNRDmcb/exec';
  static const String cacheKey = 'pm_summary_cache';
  static const String cacheTimeKey = 'pm_summary_cache_time';
  
  Map<String, Map<String, int>> zoneStats = {
    'ซ่อมบำรุงโซน 1': {'pending': 0, 'thisWeek': 0, 'notDue': 0, 'total': 0},
    'ซ่อมบำรุงโซน 2': {'pending': 0, 'thisWeek': 0, 'notDue': 0, 'total': 0},
    'ซ่อมบำรุงโซน 3': {'pending': 0, 'thisWeek': 0, 'notDue': 0, 'total': 0},
    'ซ่อมบำรุงโซน 4': {'pending': 0, 'thisWeek': 0, 'notDue': 0, 'total': 0},
    'ซ่อมบำรุงโซน 5': {'pending': 0, 'thisWeek': 0, 'notDue': 0, 'total': 0},
  };
  
  bool isLoading = true;
  DateTime? lastUpdate;
  List<dynamic> cachedData = [];
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _loadCachedDataOrFetch();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(cacheKey);
    final cachedTime = prefs.getString(cacheTimeKey);
    if (cachedJson != null) {
      try {
        cachedData = json.decode(cachedJson);
        _processData(cachedData);
        if (cachedTime != null) {
          _lastFetchTime = DateTime.tryParse(cachedTime);
        }
      } catch (_) {}
    }
  }

  Future<void> _saveCache(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, json.encode(data));
    await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<void> _fetchData() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 302) {
        cachedData = json.decode(response.body);
        _processData(cachedData);
        _lastFetchTime = DateTime.now();
        await _saveCache(cachedData);
      }
    } catch (e) {} 
    finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 302) {
        cachedData = json.decode(response.body);
        _processData(cachedData);
        _lastFetchTime = DateTime.now();
        await _saveCache(cachedData);
      }
    } catch (e) {} 
    finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCachedDataOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(cacheKey);
    final cachedTime = prefs.getString(cacheTimeKey);
    bool needFetch = true;
    if (cachedJson != null && cachedTime != null) {
      final cacheTime = DateTime.tryParse(cachedTime);
      final now = DateTime.now();
      if (cacheTime != null && now.difference(cacheTime).inHours < 24) {
        try {
          cachedData = json.decode(cachedJson);
          _processData(cachedData);
          _lastFetchTime = cacheTime;
          needFetch = false;
        } catch (_) {
          needFetch = true;
        }
      }
    }
    if (needFetch) {
      await _fetchData();
    } else {
      setState(() => isLoading = false);
    }
  }

  void _processData(List<dynamic> data) {
    zoneStats.forEach((key, value) {
      value['pending'] = 0;
      value['thisWeek'] = 0;
      value['notDue'] = 0;
      value['total'] = 0;
    });
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    for (var machine in data) {
      final zoneId = machine['ZoneID']?.toString().toUpperCase();
      final zoneKey = _getZoneKey(zoneId);
      if (zoneKey != null) {
        zoneStats[zoneKey]!['total'] = (zoneStats[zoneKey]!['total'] ?? 0) + 1;
        final nextCheck = _parseDate(machine['NextCheckDate']);
        final result = machine['ผลการตรวจ']?.toString().trim();
        if (result == 'ผ่าน') {
        } else if (result == null || result.isEmpty ) {
          if (nextCheck != null) {
            if (nextCheck.isBefore(now)) {
              zoneStats[zoneKey]!['pending'] = (zoneStats[zoneKey]!['pending'] ?? 0) + 1;
            } else if (nextCheck.isAfter(now.subtract(Duration(days: 1))) && 
                       nextCheck.isBefore(weekEnd.add(Duration(days: 1)))) {
              zoneStats[zoneKey]!['thisWeek'] = (zoneStats[zoneKey]!['thisWeek'] ?? 0) + 1;
            } else if (nextCheck.isAfter(now)) {
              zoneStats[zoneKey]!['notDue'] = (zoneStats[zoneKey]!['notDue'] ?? 0) + 1;
            }
          }
        }
      }
    }
    setState(() {
      lastUpdate = DateTime.now();
    });
  }

  String? _getZoneKey(String? zoneId) {
    if (zoneId == null) return null;
    if (zoneId == 'Z001' || zoneId == '1') return 'ซ่อมบำรุงโซน 1';
    if (zoneId == 'Z002' || zoneId == '2') return 'ซ่อมบำรุงโซน 2';
    if (zoneId == 'Z003' || zoneId == '3') return 'ซ่อมบำรุงโซน 3';
    if (zoneId == 'Z004' || zoneId == '4') return 'ซ่อมบำรุงโซน 4';
    if (zoneId == 'Z005' || zoneId == '5') return 'ซ่อมบำรุงโซน 5';
    return null;
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
    } catch (e) {}
    return null;
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red.shade400;
      case 'thisWeek':
        return Colors.orange.shade400;
      case 'notDue':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'คงค้าง';
      case 'thisWeek':
        return 'สัปดาห์นี้';
      case 'notDue':
        return 'ยังไม่ถึง';
      default:
        return 'ไม่ทราบ';
    }
  }

  int _getCompletedCount(String zoneKey) {
    int completed = 0;
    for (var machine in cachedData) {
      final zoneId = machine['ZoneID']?.toString().toUpperCase();
      final currentZoneKey = _getZoneKey(zoneId);
      if (currentZoneKey == zoneKey) {
        final result = machine['ผลการตรวจ']?.toString().trim();
        if (result == 'ผ่าน') {
          completed++;
        }
      }
    }
    return completed;
  }

  List<dynamic> _getFailedMachines(String zoneKey) {
    List<dynamic> failedMachines = [];
    for (var machine in cachedData) {
      final zoneId = machine['ZoneID']?.toString().toUpperCase();
      final currentZoneKey = _getZoneKey(zoneId);
      if (currentZoneKey == zoneKey) {
        final result = machine['ผลการตรวจ']?.toString().trim();
        if (result == 'ไม่ผ่าน') {
          failedMachines.add(machine);
        }
      }
    }
    return failedMachines;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    try {
      DateTime dt;
      if (dateStr.contains('-')) {
        dt = DateTime.parse(dateStr);
      } else if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          dt = DateTime(year, month, day);
        } else {
          return dateStr;
        }
      } else {
        return dateStr;
      }
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}' ;
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(16),
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
                          children: [
                            Text(
                              'สรุปสถานะ PM ทั้งหมด',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Kanit',
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
                        Text(
                          _getLastUpdateText(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey[400],
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: zoneStats.length,
                    itemBuilder: (context, index) {
                      final zoneEntry = zoneStats.entries.elementAt(index);
                      final zoneName = zoneEntry.key;
                      final stats = zoneEntry.value;
                      final completedCount = _getCompletedCount(zoneName);
                      final progress = stats['total']! > 0 
                          ? (completedCount / stats['total']!)
                          : 0.0;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.all(16),
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
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade700,
                                  child: Icon(Icons.assignment_outlined, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      zoneName,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                    Text(
                                      'ทั้งหมด ${stats['total']} เครื่อง',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ยังไม่ได้ตรวจเช็ค',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                                fontFamily: 'Kanit',
                              ),
                            ),
                            Divider(color: Colors.grey.shade300, thickness: 1),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatusIndicator('pending', stats['pending'] ?? 0),
                                  _buildStatusIndicator('thisWeek', stats['thisWeek'] ?? 0),
                                  _buildStatusIndicator('notDue', stats['notDue'] ?? 0),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'ตรวจเช็คแล้ว',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontFamily: 'Kanit',
                              ),
                            ),
                            Divider(color: Colors.grey.shade300, thickness: 1),
                            Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ความคืบหน้า',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '$completedCount / ${stats['total']} เครื่องเสร็จสิ้น',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_getFailedMachines(zoneName).isNotEmpty) ...[
                              SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('เครื่องที่ไม่ผ่านทั้งหมด'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: ListView(
                                          shrinkWrap: true,
                                          children: _getFailedMachines(zoneName).map<Widget>((machine) =>
                                            Container(
                                              margin: EdgeInsets.symmetric(vertical: 6),
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.red[200]!),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '• ${machine['MachineName'] ?? 'ไม่มีชื่อเครื่อง'}',
                                                    style: TextStyle(fontSize: 13, color: Colors.red[700], fontFamily: 'Kanit', fontWeight: FontWeight.bold),
                                                  ),
                                                  Text('  รหัส: ${machine['MachineID'] ?? machine['Code'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'Kanit')),
                                                  Text('  วันที่ตรวจ: ${_formatDate(machine['LastCheckDate']?.toString())}', style: TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'Kanit')),
                                                  if (machine['ผู้ตรวจ'] != null && machine['ผู้ตรวจ'].toString().trim().isNotEmpty)
                                                    Text('  ผู้ตรวจ: ${machine['ผู้ตรวจ']}', style: TextStyle(fontSize: 12, color: Colors.blue[800], fontFamily: 'Kanit')),
                                                  if (machine['เวลาที่ตรวจ'] != null && machine['เวลาที่ตรวจ'].toString().trim().isNotEmpty)
                                                    Text('  เวลาที่ตรวจ: ${_formatDate(machine['เวลาที่ตรวจ']?.toString())}', style: TextStyle(fontSize: 12, color: Colors.blue[800], fontFamily: 'Kanit')),
                                                  if (machine['ผลการตรวจ'] != null && machine['ผลการตรวจ'].toString().trim().isNotEmpty)
                                                    Text('  ผลการตรวจ: ${machine['ผลการตรวจ']}', style: TextStyle(fontSize: 12, color: Colors.red[900], fontFamily: 'Kanit')),
                                                  if (machine['รายละเอียดการตรวจ'] != null && machine['รายละเอียดการตรวจ'].toString().trim().isNotEmpty)
                                                    Text('  รายละเอียดการตรวจ: ${machine['รายละเอียดการตรวจ']}', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontFamily: 'Kanit')),
                                                  if (machine['รายละเอียด / อะไหล่'] != null && machine['รายละเอียด / อะไหล่'].toString().trim().isNotEmpty)
                                                    Text('  รายละเอียด / อะไหล่: ${machine['รายละเอียด / อะไหล่']}', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontFamily: 'Kanit', fontStyle: FontStyle.italic)),
                                                  if (machine['หมายเหตุ'] != null && machine['หมายเหตุ'].toString().trim().isNotEmpty)
                                                    Text('  หมายเหตุ: ${machine['หมายเหตุ']}', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontFamily: 'Kanit', fontStyle: FontStyle.italic)),
                                                ],
                                              ),
                                            ),
                                          ).toList(),
                                        ),
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
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.red[600], size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'เครื่องที่ไม่ผ่าน (${_getFailedMachines(zoneName).length})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[600],
                                              fontFamily: 'Kanit',
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      ...(_getFailedMachines(zoneName).take(3).map((machine) =>
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '• ${machine['MachineName'] ?? 'ไม่มีชื่อเครื่อง'}',
                                            style: TextStyle(fontSize: 12, color: Colors.red[700], fontFamily: 'Kanit', fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      )),
                                      if (_getFailedMachines(zoneName).length > 3)
                                        Text(
                                          'และอีก ${_getFailedMachines(zoneName).length - 3} เครื่อง',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red[600],
                                            fontFamily: 'Kanit',
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusIndicator(String status, int count) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Kanit',
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}