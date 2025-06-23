import 'package:flutter/material.dart';
import 'pm_zone_widget.dart';

class PMzone1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PMZoneWidget(
      zoneId: 'Z001',
      zoneNumber: '1',
      cacheTimeKey: 'last_pm_fetch_time_z1',
      cacheDataKey: 'cached_pm_data_z1',
      zoneTitle: 'PM โซน 1',
      );
  }
}