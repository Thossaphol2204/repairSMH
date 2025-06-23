import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BugReportScreen extends StatefulWidget {
  @override
  _BugReportScreenState createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  bool _isLoading = false;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  Future<void> _submitBug() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();
    
    _formKey.currentState!.save();
    setState(() { _isLoading = true; });
    
    try {
      final url = 'https://script.google.com/macros/s/AKfycby5qGKd5XfKAeXj_CjzrIJHEJURdnq3jxD9HeP7CII-aQ616_Q8h0EC_B_nWhwslsxZ/exec';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'bug',
          'title': _title,
          'description': _description,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ส่งรายงานปัญหาเรียบร้อย ขอบคุณสำหรับการช่วยเหลือ!', 
              style: TextStyle(fontFamily: 'Kanit')
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          )
        );
        Navigator.pop(context);
      } else {
        throw Exception('ส่งรายงานไม่สำเร็จ (รหัส ${response.statusCode})');
      }
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', 
            style: TextStyle(fontFamily: 'Kanit')
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        )
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แจ้งปัญหาหรือข้อผิดพลาด', 
          style: TextStyle(
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          )
        ),
        backgroundColor: Colors.red[700],
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(Icons.bug_report, size: 60, color: Colors.red[700]),
                    SizedBox(height: 8),
                    Text(
                      'พบปัญหาการใช้งานหรือไม่?', 
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      )
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ช่วยเราปรับปรุงแอปพลิเคชันด้วยการรายงานปัญหา',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: Colors.grey[600],
                      )
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              
              Text(
                'หัวข้อปัญหา*', 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontFamily: 'Kanit',
                  fontSize: 16,
                )
              ),
              SizedBox(height: 8),
              TextFormField(
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  hintText: 'เช่น ปุ่มกดไม่ทำงาน, ระบบล็อกอินมีปัญหา',
                  hintStyle: TextStyle(fontFamily: 'Kanit', color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[700]!, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุหัวข้อปัญหา' : null,
                onSaved: (v) => _title = v ?? '',
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_descriptionFocusNode);
                },
              ),
              SizedBox(height: 20),
              
              Text(
                'รายละเอียดปัญหา*', 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontFamily: 'Kanit',
                  fontSize: 16,
                )
              ),
              SizedBox(height: 8),
              TextFormField(
                focusNode: _descriptionFocusNode,
                decoration: InputDecoration(
                  hintText: 'อธิบายปัญหาที่พบให้ละเอียด รวมถึงขั้นตอนที่ทำให้เกิดปัญหา',
                  hintStyle: TextStyle(fontFamily: 'Kanit', color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[700]!, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 5,
                validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุรายละเอียดปัญหา' : null,
                onSaved: (v) => _description = v ?? '',
              ),
              SizedBox(height: 8),
              Text(
                'ยิ่งระบุรายละเอียดมาก เรายิ่งแก้ไขปัญหาได้เร็วขึ้น', 
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.grey[600],
                  fontSize: 13,
                )
              ),
              SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('ยืนยันการส่งบัค', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
                              content: Text('คุณต้องการส่งรายงานปัญหานี้ใช่หรือไม่?', style: TextStyle(fontFamily: 'Kanit')),
                              actions: [
                                TextButton(
                                  child: Text('ยกเลิก', style: TextStyle(fontFamily: 'Kanit')),
                                  onPressed: () => Navigator.of(context).pop(false),
                                ),
                                ElevatedButton(
                                  child: Text('ยืนยัน', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                                  onPressed: () => Navigator.of(context).pop(true),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _submitBug();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'ส่งรายงานปัญหา', 
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white
                            )
                          ),
                        ],
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