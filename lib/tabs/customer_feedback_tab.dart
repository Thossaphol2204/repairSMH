import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'work_report_tab.dart';

class CustomerFeedbackTab extends StatefulWidget {
  @override
  _CustomerFeedbackTabState createState() => _CustomerFeedbackTabState();
}

class _CustomerFeedbackTabState extends State<CustomerFeedbackTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late Future<List<dynamic>> _futureRepairs;
  final String _repairApiUrl =
      'https://script.google.com/macros/s/AKfycbxo4DJNNxidHRdd22TluoGZbI_-iNoRaFfwrBMoz04SEsAP5zEWlPkEIFYRcTobuNcf/exec';
  DateTime? _lastFetchTime;
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lastFetchTime = DateTime.now();
    _futureRepairs = _fetchRepairsWithCache();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchRepairsWithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString('last_customer_feedback_fetch_time');
    final cachedDataString = prefs.getString('cached_customer_feedback_data');

    if (lastFetchString != null) {
      _lastFetchTime = DateTime.parse(lastFetchString);
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);

      if (timeSinceLastFetch < Duration(hours: 24) && cachedDataString != null) {
        try {
          final cachedData = json.decode(cachedDataString);
          final List<dynamic> data =
              cachedData is List ? cachedData : (cachedData['data'] ?? []);
          return data.where((item) => item['สถานะ'] == 'รอประเมิน').toList();
        } catch (e) {
          print('Error using cached data: $e');
        }
      }
    }

    return _fetchRepairsFromAPI();
  }

  Future<List<dynamic>> _fetchRepairsFromAPI() async {
    try {
      final response = await http
          .get(Uri.parse(_repairApiUrl))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 302 && response.headers['location'] != null) {
        final redirectUrl = response.headers['location']!;
        final redirectedResponse = await http.get(Uri.parse(redirectUrl));
        return await _processRepairApiResponse(redirectedResponse);
      }
      return await _processRepairApiResponse(response);
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  Future<List<dynamic>> _processRepairApiResponse(http.Response response) async {
    if (response.statusCode == 200 || response.statusCode == 302) {
      final bodyTrim = response.body.trim();
      if (response.headers['content-type']?.contains('application/json') == true ||
          bodyTrim.startsWith('{') || bodyTrim.startsWith('[')) {
        final decoded = json.decode(response.body);
        final List<dynamic> data =
            decoded is List ? decoded : (decoded['data'] ?? []);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'last_customer_feedback_fetch_time',
          DateTime.now().toIso8601String(),
        );
        await prefs.setString(
          'cached_customer_feedback_data',
          json.encode(decoded),
        );

        setState(() {
          _lastFetchTime = DateTime.now();
        });

        return data.where((item) => item['สถานะ'] == 'รอประเมิน').toList();
      } else {
        throw Exception('API response is not JSON: ${bodyTrim.substring(0, bodyTrim.length > 100 ? 100 : bodyTrim.length)}');
      }
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastFetchTime = DateTime.now();
      _futureRepairs = _fetchRepairsFromAPI();
    });
  }

  Future<void> _updateStatus(String jobId, String newStatus) async {
    try {
      final response = await http.post(
        Uri.parse(_repairApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateRepair',
          'เลขที่ใบแจ้งซ่อม': jobId,
          'สถานะ': newStatus,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตสถานะสำเร็จ')),
        );
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            Tab(text: 'รอประเมิน'),
            Tab(text: 'รายงานช่าง'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildPendingEvaluationTab(), WorkReportTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingEvaluationTab() {
    return FutureBuilder<List<dynamic>>(
      future: _futureRepairs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'เกิดข้อผิดพลาด: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    top: 8,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
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
                          Text(
                            'รายการรอประเมิน',
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
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list_alt, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'ไม่มีรายการรอประเมิน',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          final repairs = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    top: 8,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
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
                          Text(
                            'รายการรอประเมิน',
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: repairs.length,
                  itemBuilder: (context, index) {
                    final repair = repairs[index];
                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.build, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'แจ้งซ่อม',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                  Text(
                                    repair['ความเร่งด่วน'] ?? 'ไม่ด่วน',
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
                          const SizedBox(height: 12),
                          Text(
                            repair['MachineName'] ?? 'ไม่มีชื่อรายการ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          if (repair['รายละเอียด'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                repair['รายละเอียด'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ),
                          if (repair['แผนก'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                repair['แผนก'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ),
                          if (repair['ผู้แจ้ง'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                repair['ผู้แจ้ง'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showRatingAndCompleteDialog(repair),
                                    icon: Icon(Icons.check_circle, size: 18),
                                    label: Text(
                                      'ผ่านประเมิน',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showRejectConfirmationDialog(repair),
                                    icon: Icon(Icons.cancel, size: 18),
                                    label: Text(
                                      'ไม่ผ่าน',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildStarRating(int rating, bool isReadOnly, Function(int)? onRatingChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          ),
          onPressed: isReadOnly ? null : () => onRatingChanged?.call(index + 1),
        );
      }),
    );
  }

  void _showRatingAndCompleteDialog(dynamic repair) {
    int currentRating = int.tryParse(repair['ดาวประเมิน']?.toString() ?? '0') ?? 0;
    int selectedRating = currentRating;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('ประเมินและเสร็จสิ้น'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ใบแจ้งซ่อม #${repair['เลขที่ใบแจ้งซ่อม']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'กรุณาให้ดาวประเมินการให้บริการ:',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: _buildStarRating(selectedRating, false, (rating) {
                      setState(() {
                        selectedRating = rating;
                      });
                    }),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      _getRatingText(selectedRating),
                      style: TextStyle(
                        color: Colors.amber[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('ยกเลิก'),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  child: Text('ยืนยัน'),
                  onPressed: () async {
                    if (selectedRating > 0) {
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
                              Text('กำลังบันทึกการประเมินและอัพเดตสถานะ...'),
                            ],
                          ),
                          backgroundColor: Colors.green[600],
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Perform API calls in background
                      _updateRatingAndStatus(repair, selectedRating);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('กรุณาให้ดาวประเมิน'),
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

  Future<void> _updateRatingAndStatus(dynamic repair, int rating) async {
    try {
      // อัพเดตดาวประเมิน
      final ratingResponse = await http.post(
        Uri.parse(_repairApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateRating',
          'เลขที่ใบแจ้งซ่อม': repair['เลขที่ใบแจ้งซ่อม'],
          'ดาวประเมิน': rating.toString(),
        }),
      );

      if (ratingResponse.statusCode == 200 || ratingResponse.statusCode == 302) {
        // อัพเดตสถานะเป็นเสร็จสิ้น
        final statusResponse = await http.post(
          Uri.parse(_repairApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'updateRepair',
            'เลขที่ใบแจ้งซ่อม': repair['เลขที่ใบแจ้งซ่อม'],
            'สถานะ': 'ดำเนินการเสร็จสิ้น',
          }),
        );

        if (statusResponse.statusCode == 200 || statusResponse.statusCode == 302) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกการประเมินและอัพเดตสถานะสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshData();
        } else {
          throw Exception('Failed to update status');
        }
      } else {
        throw Exception('Failed to update rating');
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

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'แย่มาก';
      case 2:
        return 'ไม่ดี';
      case 3:
        return 'ปานกลาง';
      case 4:
        return 'ดี';
      case 5:
        return 'ดีมาก';
      default:
        return 'กรุณาให้ดาวประเมิน';
    }
  }

  void _showRejectConfirmationDialog(dynamic repair) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ยืนยันการประเมิน'),
          content: Text('แจ้งซ่อมนี้จะถูกส่งกลับเข้าสู่ระบบการซ่อมอีกครั้งหากรีบโปรดติดต่อโดยด่วน'),
          actions: [
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('ยืนยัน'),
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(repair['เลขที่ใบแจ้งซ่อม'] ?? '', 'รอดำเนินการ');
              },
            ),
          ],
        );
      },
    );
  }
}