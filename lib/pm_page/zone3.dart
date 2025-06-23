import 'package:flutter/material.dart';
import 'pm_zone_widget.dart';

class PMzone3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PMZoneWidget(
      zoneId: 'Z003',
      zoneNumber: '3',
      cacheTimeKey: 'last_pm_fetch_time_z3',
      cacheDataKey: 'cached_pm_data_z3',
      zoneTitle: 'PM โซน 3',
    );
  }
}