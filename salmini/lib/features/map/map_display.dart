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
  Polyline? _originalRoutePolyline;
  final Polypoints _polypoints = Polypoints();
  LatLng? _lastPosition;
  double _currentSpeedKph = 0.0;
  StreamSubscription<Position>? _positionStream;

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
    _positionStream?.cancel();
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
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
          _lastPosition = userLatLng;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 15));
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
    _positionStream = UserLocationHandler.listenToLocationChanges().listen((Position position) {
      LatLng newLatLng = LatLng(position.latitude, position.longitude);
      double speedInMps = position.speed >= 0 ? position.speed : 0.0; // handle possible -1
      double speedInKph = speedInMps * 3.6;

      if (_lastPosition != null && newLatLng != _lastPosition) {
        _animateMarker(_lastPosition!, newLatLng);
        _updateColoredPolyline(_lastPosition!, newLatLng, speedInKph);
      }

      setState(() {
        _lastPosition = newLatLng;
        _currentSpeedKph = speedInKph;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
    });
  }

  Future<void> _animateMarker(LatLng oldLatLng, LatLng newLatLng) async {
    const int steps = 60;
    const Duration stepDuration = Duration(milliseconds: 16);

    for (int i = 0; i <= steps; i++) {
      double lat = oldLatLng.latitude + ((newLatLng.latitude - oldLatLng.latitude) * i / steps);
      double lng = oldLatLng.longitude + ((newLatLng.longitude - oldLatLng.longitude) * i / steps);

      setState(() {
        _userMarker = Marker(
          markerId: const MarkerId("userLocation"),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });

      await Future.delayed(stepDuration);
    }
  }

  void _updateColoredPolyline(LatLng from, LatLng to, double speedKph) {
    Color color;
    if (speedKph < 60) {
      color = Colors.green;
    } else if (speedKph <= 80) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    final segmentId = "segment_${DateTime.now().millisecondsSinceEpoch}";
    final polyline = Polyline(
      polylineId: PolylineId(segmentId),
      points: [from, to],
      color: color,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
    );

    setState(() {
      _polylines.add(polyline);
    });
  }

  Future<void> _setDestination() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty || _currentPosition == null) return;

      final destLatLng = LatLng(locations.first.latitude, locations.first.longitude);
      final originLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      setState(() {
        _destinationMarker = Marker(
          markerId: const MarkerId("destination"),
          position: destLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      });

      final coordinates = await _polypoints.createPolylines(originLatLng, destLatLng);

      final routePolyline = Polyline(
        polylineId: const PolylineId("original_route"),
        points: coordinates,
        color: Colors.grey.shade800,
        width: 4,
      );

      setState(() {
        _originalRoutePolyline = routePolyline;
        _polylines = {routePolyline};
      });

      await _fitToBounds(originLatLng, destLatLng, coordinates);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fitToBounds(LatLng origin, LatLng destination, List<LatLng> path) async {
    final bounds = _boundsFromLatLngList([origin, destination, ...path]);
    final update = CameraUpdate.newLatLngBounds(bounds, 100);
    _mapController?.animateCamera(update);
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude, maxLat = list.first.latitude;
    double minLng = list.first.longitude, maxLng = list.first.longitude;

    for (final point in list) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 14),
            mapType: _currentMapType,
            markers: {
              if (_userMarker != null) _userMarker!,
              if (_destinationMarker != null) _destinationMarker!,
            },
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),
          _buildTopInput(),
          _buildBottomButtons(),
          _buildSpeedIndicator(),
        ],
      ),
    );
  }

  Widget _buildTopInput() => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                onPressed: _isLoading ? null : _setDestination,
              ),
            ],
          ),
        ),
      );

  Widget _buildBottomButtons() => Positioned(
        bottom: 40,
        left: 16,
        right: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: "locate",
              onPressed: _isLoading ? null : _getUserLocation,
              child: const Icon(Icons.my_location, color: Colors.white),
              backgroundColor: Colors.blue,
            ),
            FloatingActionButton(
              heroTag: "mapType",
              onPressed: () {
                setState(() {
                  _currentMapType =
                      _currentMapType == MapType.normal ? MapType.hybrid : MapType.normal;
                });
              },
              child: const Icon(Icons.layers, color: Colors.white),
              backgroundColor: Colors.black,
            ),
          ],
        ),
      );

  Widget _buildSpeedIndicator() => Positioned(
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
      );
}