import 'package:geolocator/geolocator.dart';

class SpeedTracker {
  void trackSpeed(Function(double speedKph) onSpeedUpdate) {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      double speedInMps = position.speed;
      double speedInKph = speedInMps * 3.6;
      onSpeedUpdate(speedInKph);
    });
  }
}
