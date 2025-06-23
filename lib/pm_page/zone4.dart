import 'package:flutter/material.dart';
import 'pm_zone_widget.dart';

class PMzone4 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PMZoneWidget(
      zoneId: 'Z004',
      zoneNumber: '4',
      cacheTimeKey: 'last_pm_fetch_time_z4',
      cacheDataKey: 'cached_pm_data_z4',
      zoneTitle: 'PM โซน 4',
      );
  }
}