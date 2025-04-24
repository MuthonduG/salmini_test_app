import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:salmini/features/map/polylines_handler.dart';
import 'package:salmini/features/map/user_location_handler.dart';

class MapDisplayScreen extends StatefulWidget {
  const MapDisplayScreen({super.key});

  @override
  State<MapDisplayScreen> createState() => _MapDisplayScreen();
}

class _MapDisplayScreen extends State<MapDisplayScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  Marker? _userMarker;
  Marker? _destinationMarker;
  Position? _currentPosition;
  bool _isLoading = false;
  final TextEditingController _destinationController = TextEditingController();
  Set<Polyline> _polylines = {};
  final Polypoints _polypoints = Polypoints();
  LatLng? _lastPosition;
  double _currentSpeedKph = 0.0;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _trackUserMovement();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoading = true);
    try {
      Position? position = await UserLocationHandler.getCurrentLocation();
      if (position != null) {
        LatLng userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = position;
          _userMarker = Marker(
            markerId: const MarkerId("userLocation"),
            position: userLatLng,
            infoWindow: const InfoWindow(title: "My Location"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
          _lastPosition = userLatLng;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userLatLng, 15),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _trackUserMovement() {
    UserLocationHandler.listenToLocationChanges().listen((Position position) {
      LatLng newLatLng = LatLng(position.latitude, position.longitude);

      double speedInMps = position.speed;
      double speedInKph = speedInMps * 3.6;

      if (_lastPosition != null) {
        _animateMarker(_lastPosition!, newLatLng);
      }

      setState(() {
        _lastPosition = newLatLng;
        _currentSpeedKph = speedInKph;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
    });
  }

  Future<void> _animateMarker(LatLng oldLatLng, LatLng newLatLng) async {
    double latDiff = newLatLng.latitude - oldLatLng.latitude;
    double lngDiff = newLatLng.longitude - oldLatLng.longitude;

    const int steps = 60;
    const Duration stepDuration = Duration(milliseconds: 16);

    for (int i = 0; i <= steps; i++) {
      final double progress = i / steps;
      final double lat = oldLatLng.latitude + (latDiff * progress);
      final double lng = oldLatLng.longitude + (lngDiff * progress);

      setState(() {
        _userMarker = Marker(
          markerId: const MarkerId("userLocation"),
          position: LatLng(lat, lng),
          infoWindow: const InfoWindow(title: "My Location"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });

      await Future.delayed(stepDuration);
    }
  }

  Future<void> _setDestination() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a destination address")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) {
        throw Exception("No location found for this address");
      }

      if (_currentPosition == null) {
        throw Exception("Current position not available");
      }

      final destinationLatLng = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      final originLatLng = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _destinationMarker = Marker(
          markerId: const MarkerId("destination"),
          position: destinationLatLng,
          infoWindow: InfoWindow(title: "Destination: $address"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      });

      final polylineCoordinates = await _polypoints.createPolylines(
        originLatLng,
        destinationLatLng,
      );

      if (polylineCoordinates.isEmpty) {
        throw Exception("Failed to generate route between locations");
      }

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 3,
            geodesic: true,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });

      await _fitToBounds(originLatLng, destinationLatLng, polylineCoordinates);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      print("Destination setting error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fitToBounds(
    LatLng origin,
    LatLng destination,
    List<LatLng> polyline,
  ) async {
    try {
      final bounds = _boundsFromLatLngList([origin, destination] + polyline);

      final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);

      if (_mapController != null) {
        await _mapController!.animateCamera(cameraUpdate);
      }
    } catch (e) {
      print("Error adjusting camera: $e");
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(origin, 12),
      );
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty, "List of LatLng cannot be empty");

    double x0 = list[0].latitude, x1 = list[0].latitude;
    double y0 = list[0].longitude, y1 = list[0].longitude;

    for (final latLng in list.skip(1)) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(
      northeast: LatLng(x1, y1),
      southwest: LatLng(x0, y0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(0, 0),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _currentMapType,
            markers: {
              if (_userMarker != null) _userMarker!,
              if (_destinationMarker != null) _destinationMarker!,
            },
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        hintText: "Enter destination address",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    onPressed: _isLoading ? null : _setDestination,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 16,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _getUserLocation,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.my_location, color: Colors.white),
              backgroundColor: Colors.blue,
            ),
          ),

          Positioned(
            bottom: 40,
            right: 16,
            child: FloatingActionButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _currentMapType = _currentMapType == MapType.normal
                            ? MapType.hybrid
                            : MapType.normal;
                      });
                    },
              child: const Icon(Icons.layers, color: Colors.white),
              backgroundColor: Colors.black,
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Speed: ${_currentSpeedKph.toStringAsFixed(1)} km/h",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}