import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteSegment {
  final LatLng start;
  final LatLng end;
  final double speedKph;
  final Color color;

  RouteSegment({
    required this.start,
    required this.end,
    required this.speedKph,
    required this.color,
  });
}
