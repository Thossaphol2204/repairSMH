import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เกี่ยวกับ/คู่มือ', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            Text('SMH Repair App', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue[900])),
            SizedBox(height: 8),
            Text('ระบบแจ้งซ่อม จัดการงานซ่อม และ PM', style: TextStyle(fontFamily: 'Kanit', color: Colors.grey[700], fontSize: 15)),
            Divider(height: 32, thickness: 1.2),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('คู่มือการใช้งาน', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[800])),
            ),
            SizedBox(height: 10),
            _buildGuideItem('1. แจ้งซ่อมหรือดูงานซ่อมที่ได้รับมอบหมาย'),
            _buildGuideItem('2. กดที่งานเพื่อดูรายละเอียดหรืออัปเดตสถานะ'),
            _buildGuideItem('3. ใช้ปุ่ม "แจ้งปัญหา" ที่มุมขวาบนเพื่อรายงานบัคหรือข้อเสนอแนะ'),
            _buildGuideItem('4. สามารถดูประวัติ/สรุปงานซ่อมและ PM ได้ในแต่ละแท็บ'),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('เกี่ยวกับแอป', style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[800])),
            ),
            SizedBox(height: 10),
            Text(
              'แอปนี้พัฒนาขึ้นเพื่อช่วยให้การจัดการงานซ่อมในโรงงานเป็นไปอย่างมีประสิทธิภาพมากขึ้น สามารถติดตามสถานะงาน แจ้งซ่อม ประเมินผล และดูสรุปงานได้ หากมีข้อผิดพลาดในการทำงาน โปรดแจ้ง และขออภัยเป็นอย่างสูง',
              style: TextStyle(fontFamily: 'Kanit', color: Colors.grey[800]),
            ),
            SizedBox(height: 24),
            Text('SMH © 2024', style: TextStyle(color: Colors.grey[500], fontFamily: 'Kanit')),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.blue[400], size: 20),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Kanit', fontSize: 15))),
        ],
      ),
    );
  }
} 
