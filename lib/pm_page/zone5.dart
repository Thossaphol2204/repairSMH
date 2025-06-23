import 'package:flutter/material.dart';
import 'pm_zone_widget.dart';

class PMzone5 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PMZoneWidget(
      zoneId: 'Z005',
      zoneNumber: '5',
      cacheTimeKey: 'last_pm_fetch_time_z5',
      cacheDataKey: 'cached_pm_data_z5',
      zoneTitle: 'PM โซน 5',
    );
  }
}