import 'package:geolocator/geolocator.dart';

void getSpeed() {
  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    ),
  ).listen((Position position) {
    double speedInMps = position.speed; 
    double speedInKph = speedInMps * 3.6;
    print("Current speed: $speedInKph km/h");
  });
}
