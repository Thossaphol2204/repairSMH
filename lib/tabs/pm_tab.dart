import 'package:flutter/material.dart';
import '../pm_page/zone1.dart';
import '../pm_page/zone2.dart';
import '../pm_page/zone3.dart';
import '../pm_page/zone4.dart';
import '../pm_page/zone5.dart';
import '../constants.dart';

class PMTab extends StatelessWidget {
  static const List<Map<String, dynamic>> _zones = [
    {
      'title': 'ซ่อมบำรุง โซน 1',
      'zone': 1,
      'isActive': true,
    },
    {
      'title': 'ซ่อมบำรุง โซน 2',
      'zone': 2,
      'isActive': true,
    },
    {
      'title': 'ซ่อมบำรุง โซน 3',
      'zone': 3,
      'isActive': true,
    },
    {
      'title': 'ซ่อมบำรุง โซน 4',
      'zone': 4,
      'isActive': true,
    },
    {
      'title': 'ซ่อมบำรุง โซน 5',
      'zone': 5,
      'isActive': true,
    },
    {
      'title': 'ซ่อมบำรุง โซน 6',
      'zone': 6,
      'isActive': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppConstants.defaultPadding, horizontal: AppConstants.defaultPadding),
      itemCount: _zones.length,
      itemBuilder: (context, index) {
        final zone = _zones[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          elevation: AppConstants.cardElevation,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding, vertical: AppConstants.smallPadding),
            leading: CircleAvatar(
              backgroundColor: zone['isActive'] ? AppConstants.primaryColor : Colors.grey,
              child: Icon(
                Icons.build,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              zone['title'],
              style: AppConstants.titleStyle.copyWith(
                color: zone['isActive'] ? Colors.black87 : Colors.grey[600],
              ),
            ),
            subtitle: Text(
              zone['isActive'] ? 'พร้อมใช้งาน' : 'อยู่ระหว่างการพัฒนา',
              style: AppConstants.captionStyle.copyWith(
                color: zone['isActive'] ? AppConstants.successColor : Colors.grey[500],
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: zone['isActive'] ? AppConstants.primaryColor : Colors.grey[400],
            ),
            onTap: zone['isActive'] ? () => _navigateToZone(context, zone['zone']) : null,
          ),
        );
      },
    );
  }

  void _navigateToZone(BuildContext context, int zoneNumber) {
    switch (zoneNumber) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PMzone1()),
        );
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PMzone2()),
        );
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PMzone3()),
        );
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PMzone4()),
        );
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PMzone5()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'โซน $zoneNumber อยู่ระหว่างการพัฒนา',
              style: AppConstants.bodyStyle,
            ),
            backgroundColor: AppConstants.warningColor,
          ),
        );
    }
  }
}