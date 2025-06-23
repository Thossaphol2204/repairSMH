import 'package:flutter/material.dart';
import 'pm_zone_widget.dart';

class PMzone2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PMZoneWidget(
      zoneId: 'Z002',
      zoneNumber: '2',
      cacheTimeKey: 'last_pm_fetch_time_z2',
      cacheDataKey: 'cached_pm_data_z2',
      zoneTitle: 'PM โซน 2',
    );
  }
}