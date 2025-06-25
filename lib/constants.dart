import 'package:flutter/material.dart';

class AppConstants {
  // Colors
  static const Color primaryColor = Color(0xFF667eea);
  static const Color secondaryColor = Color(0xFF764ba2);
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color infoColor = Colors.blue;

  // Text Styles
  static const TextStyle titleStyle = TextStyle(
    fontFamily: 'Kanit',
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: 'Kanit',
    fontWeight: FontWeight.w500,
    fontSize: 14,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'Kanit',
    fontSize: 14,
  );

  static const TextStyle captionStyle = TextStyle(
    fontFamily: 'Kanit',
    fontSize: 12,
    color: Colors.grey,
  );

  // Dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Status Values
  static const List<String> repairStatuses = [
    'รอดำเนินการ',
    'กำลังดำเนินการ',
    'เสร็จสิ้น',
    'ยกเลิก',
  ];

  static const List<String> pmStatuses = [
    'ผ่าน',
    'ไม่ผ่าน',
    'รอตรวจ',
  ];

  static const List<String> urgencyLevels = [
    'ไม่ด่วน',
    'ด่วน',
    'ด่วนมาก',
  ];

  // Zone IDs
  static const List<String> zoneIds = ['1', '2', '3', '4', '5'];
  static const List<String> zoneNames = [
    'ซ่อมบำรุง โซน 1',
    'ซ่อมบำรุง โซน 2',
    'ซ่อมบำรุง โซน 3',
    'ซ่อมบำรุง โซน 4',
    'ซ่อมบำรุง โซน 5',
  ];

  // Work Types
  static const List<String> workTypes = [
    'งานแจ้ง',
    'PM',
    'งานทั่วไป',
    'BD',
  ];

  // Ticket Options
  static const List<String> ticketOptions = [
    'มี',
    'ไม่มี',
  ];
}

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
  );
}

class AppShadows {
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> navigationShadow = [
    BoxShadow(
      color: Colors.black26,
      spreadRadius: 2,
      blurRadius: 10,
      offset: Offset(0, -3),
    ),
  ];
} 