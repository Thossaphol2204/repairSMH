import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../constants.dart';

class WorkReportTab extends StatefulWidget {
  @override
  _WorkReportTabState createState() => _WorkReportTabState();
}

class _WorkReportTabState extends State<WorkReportTab> {
  final String _workReportApiUrl =
      'https://script.google.com/macros/s/AKfycbzyclrA5n1u_lwBxods1udScuoDtebe4jrof3ClORCwuZ8IQGwYNdZwjiIyPpLsIsdplA/exec';
  final List<Map<String, dynamic>> _workReports = [];
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _workDescController = TextEditingController();
  final TextEditingController _technicianController = TextEditingController();
  final TextEditingController _reporterController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _completionTimeController = TextEditingController();
  final TextEditingController _workTypeController = TextEditingController();
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _pmController = TextEditingController();
  final TextEditingController _bdController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  Timer? _dateTimer;

  final List<String> _zoneOptions = ['1', '2', '3', '4', '5'];
  final List<String> _workTypeOptions = ['งานแจ้ง', 'PM','งานทั่วไป','BD'];
  final List<String> _ticketOptions = ['มี', 'ไม่มี'];

  @override
  void initState() {
    super.initState();
    _updateDate();
    _loadTechnicianName();
    
    _dateTimer = Timer.periodic(Duration(hours: 1), (timer) {
      final now = DateTime.now();
      if (now.hour == 0 && now.minute == 0) {
        _updateDate();
      }
    });
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    _dateController.dispose();
    _workDescController.dispose();
    _technicianController.dispose();
    _reporterController.dispose();
    _zoneController.dispose();
    _timeController.dispose();
    _completionTimeController.dispose();
    _workTypeController.dispose();
    _ticketController.dispose();
    _pmController.dispose();
    _bdController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicianName() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _technicianController.text = prefs.getString('technician_name') ?? '';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yy').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TextEditingController timeInputController = TextEditingController(text: _timeController.text);
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('เลือกเวลาแจ้ง'),
          content: TextField(
            controller: timeInputController,
            decoration: InputDecoration(
              labelText: 'เวลา (HH:MM)',
              hintText: 'เช่น 09:30',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(timeInputController.text),
              child: Text('ตกลง'),
            ),
          ],
        );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _timeController.text = result;
      });
    }
  }

  Future<void> _selectCompletionTime(BuildContext context) async {
    final TextEditingController timeInputController = TextEditingController(text: _completionTimeController.text);
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('เลือกเวลาซ่อมเสร็จ'),
          content: TextField(
            controller: timeInputController,
            decoration: InputDecoration(
              labelText: 'เวลา (HH:MM)',
              hintText: 'เช่น 15:45',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(timeInputController.text),
              child: Text('ตกลง'),
            ),
          ],
        );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _completionTimeController.text = result;
      });
    }
  }

  void _updateDate() {
    setState(() {
      _dateController.text = DateFormat('dd/MM/yy').format(DateTime.now());
    });
  }

  void _addWorkReport() {
    if (_workDescController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกงานที่ทำในแต่ละวัน และกดบันทึกรายงาน', style: AppConstants.bodyStyle),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    setState(() {
      _workReports.add({
        'วันที่': _dateController.text,
        'งานที่แจ้ง': _workDescController.text,
        'ผู้ซ่อม': _technicianController.text,
        'ผู้แจ้ง': _reporterController.text,
        'โซน': _zoneController.text,
        'เวลาแจ้ง': _timeController.text,
        'เวลาที่ซ่อมสำเร็จ': _completionTimeController.text,
        'ประเภทงานแจ้ง': _workTypeController.text,
        'ใบแจ้ง': _ticketController.text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _clearWorkReportForm();
    });

  }

  void _clearWorkReportForm() {
    _workDescController.clear();
    _reporterController.clear();
    _zoneController.clear();
    _timeController.clear();
    _completionTimeController.clear();
    _workTypeController.clear();
    _ticketController.clear();
  }

  void _removeWorkReport(int index) {
    setState(() {
      _workReports.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบรายการสำเร็จ', style: AppConstants.bodyStyle),
        backgroundColor: AppConstants.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitWorkReports() async {
    if (_workReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่มีรายการงานที่จะบันทึก', style: AppConstants.bodyStyle),
          backgroundColor: AppConstants.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(_workReportApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'saveWorkReport',
          'data': _workReports, 
          'technician': _technicianController.text, 
        }),
      );

      http.Response finalResponse = response;
      if (response.statusCode == 302 && response.headers['location'] != null) {
        final redirectUrl = response.headers['location']!;
        finalResponse = await http.get(Uri.parse(redirectUrl));
      }

      final bodyTrim = finalResponse.body.trim();
      if (finalResponse.headers['content-type']?.contains('application/json') == true ||
          bodyTrim.startsWith('{') || bodyTrim.startsWith('[')) {
        final res = json.decode(finalResponse.body);
        if (finalResponse.statusCode == 200 || finalResponse.statusCode == 302) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'บันทึกรายงานสำเร็จ', style: AppConstants.bodyStyle),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          setState(() {
            _workReports.clear();
          });
        } else {
          throw Exception(res['message'] ?? 'Failed to save reports');
        }
      } else {
        throw Exception('API response is not JSON: ${bodyTrim.substring(0, bodyTrim.length > 100 ? 100 : bodyTrim.length)}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกรายงาน: $e', style: AppConstants.bodyStyle),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
            ),
            SizedBox(height: AppConstants.defaultPadding),
            Text(
              'กำลังโหลดข้อมูล...',
              style: AppConstants.bodyStyle.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppConstants.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: AppConstants.smallPadding),
                        Text(
                          'บันทึกรายงานงานช่างประจำวัน',
                          style: AppConstants.titleStyle.copyWith(
                            color: AppConstants.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: AppConstants.smallPadding),
                        Text(
                          'กรอกข้อมูลงานที่ทำในแต่ละวัน และกดบันทึกรายงาน',
                          style: AppConstants.captionStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppConstants.defaultPadding),
                  
                  Text(
                    'ข้อมูลงาน',
                    style: AppConstants.subtitleStyle.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppConstants.defaultPadding),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _dateController,
                          label: 'วันที่',
                          icon: Icons.calendar_today,
                          onTap: () => _selectDate(context),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildInputField(
                          controller: _technicianController,
                          label: 'ผู้ซ่อม',
                          icon: Icons.person,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  _buildInputField(
                    controller: _workDescController,
                    label: 'งานที่ทำ',
                    maxLines: 3,
                    icon: Icons.description,
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildInputField(
                          controller: _reporterController,
                          label: 'ผู้แจ้ง',
                          icon: Icons.person_add,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: _buildDropdown(
                          value: _zoneController.text.isNotEmpty ? _zoneController.text : null,
                          items: _zoneOptions,
                          label: 'โซน',
                          prefix: 'โซน ',
                          onChanged: (value) => setState(() => _zoneController.text = value ?? ''),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(context),
                          child: AbsorbPointer(
                            child: _buildInputField(
                              controller: _timeController,
                              label: 'เวลาแจ้ง',
                              icon: Icons.access_time,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectCompletionTime(context),
                          child: AbsorbPointer(
                            child: _buildInputField(
                              controller: _completionTimeController,
                              label: 'เวลาซ่อมเสร็จ',
                              icon: Icons.schedule,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _workTypeController.text.isNotEmpty ? _workTypeController.text : null,
                          items: _workTypeOptions,
                          label: 'ประเภทงาน',
                          onChanged: (value) => setState(() => _workTypeController.text = value ?? ''),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildDropdown(
                          value: _ticketController.text.isNotEmpty ? _ticketController.text : null,
                          items: _ticketOptions,
                          label: 'ใบแจ้ง',
                          onChanged: (value) => setState(() => _ticketController.text = value ?? ''),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppConstants.defaultPadding),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addWorkReport,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        'เพิ่มรายการ',
                        style: AppConstants.bodyStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: AppConstants.defaultPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppConstants.defaultPadding),
          
          if (_workReports.isNotEmpty) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: AppConstants.primaryColor),
                        SizedBox(width: AppConstants.smallPadding),
                        Text(
                          'รายการงานวันนี้ (${_workReports.length})',
                          style: AppConstants.subtitleStyle.copyWith(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppConstants.smallPadding),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _workReports.length,
                      itemBuilder: (context, index) {
                        final report = _workReports[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: AppConstants.smallPadding),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(AppConstants.smallPadding),
                            leading: Icon(Icons.work, color: AppConstants.primaryColor),
                            title: Text(
                              report['งานที่แจ้ง'],
                              style: AppConstants.bodyStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  'ผู้ซ่อม: ${report['ผู้ซ่อม']}',
                                  style: AppConstants.captionStyle,
                                ),
                                if (report['โซน'] != null && report['โซน'].isNotEmpty)
                                  Text(
                                    'โซน: ${report['โซน']}',
                                    style: AppConstants.captionStyle,
                                  ),
                                if (report['เวลาแจ้ง'] != null && report['เวลาแจ้ง'].isNotEmpty)
                                  Text(
                                    'เวลาแจ้ง: ${report['เวลาแจ้ง']}',
                                    style: AppConstants.captionStyle,
                                  ),
                                if (report['เวลาที่ซ่อมเสร็จ'] != null && report['เวลาที่ซ่อมเสร็จ'].isNotEmpty)
                                  Text(
                                    'เวลาที่ซ่อมเสร็จ: ${report['เวลาที่ซ่อมเสร็จ']}',
                                    style: AppConstants.captionStyle,
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: AppConstants.errorColor,
                              ),
                              onPressed: () => _removeWorkReport(index),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitWorkReports,
                        icon: _isSubmitting 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSubmitting ? 'กำลังบันทึก...' : 'บันทึกรายงาน',
                          style: AppConstants.bodyStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.successColor,
                          padding: EdgeInsets.symmetric(vertical: AppConstants.defaultPadding),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
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
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    Widget textField = TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppConstants.captionStyle.copyWith(
          color: Colors.grey.shade700,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppConstants.primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        suffixIcon: icon != null
            ? Icon(
                icon,
                color: AppConstants.primaryColor,
                size: 18,
              )
            : null,
        isDense: true,
      ),
      readOnly: onTap != null,
      maxLines: maxLines,
      style: AppConstants.bodyStyle.copyWith(
        fontSize: 13,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: textField,
      );
    }

    return textField;
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    String prefix = '',
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  '$prefix$item',
                  style: AppConstants.bodyStyle.copyWith(fontSize: 13),
                ),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppConstants.captionStyle.copyWith(
          color: Colors.grey.shade700,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppConstants.primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        isDense: true,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
      style: AppConstants.bodyStyle.copyWith(
        color: Colors.grey.shade800,
        fontSize: 13,
      ),
      icon: Icon(
        Icons.arrow_drop_down,
        color: AppConstants.primaryColor,
        size: 18,
      ),
    );
  }
}