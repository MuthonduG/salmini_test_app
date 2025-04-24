import 'package:flutter/material.dart';
import 'package:salmini/features/map/map_display.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => MapDisplayScreen());
    default:
      return MaterialPageRoute(
        builder:
            (_) => Scaffold(body: Center(child: Text('404: Page Not Found'))),
      );
  }
}
