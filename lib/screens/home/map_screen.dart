// lib/screens/home/map_screen.dart - COMPLETE FILE
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:step_rewards/services/steps_service.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  double _distance = 0.0; // in meters
  DateTime? _startTime;
  int _estimatedSteps = 0;
  
  @override
  void initState() {
    super.initState();
    _determinePosition();
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
  
  // Get current position and check permissions
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    } 

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      
      // Center map on current position
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 15.0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }
  
  // Start tracking the walk
  void _startTracking() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for location...')),
      );
      return;
    }
    
    setState(() {
      _isTracking = true;
      _routePoints = [_currentPosition!];
      _distance = 0.0;
      _estimatedSteps = 0;
      _startTime = DateTime.now();
    });
    
    // Set up location tracking
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // minimum distance (in meters) to trigger update
      ),
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      
      setState(() {
        // Add new point to route
        _routePoints.add(newPoint);
        _currentPosition = newPoint;
        
        // Calculate distance if we have at least two points
        if (_routePoints.length >= 2) {
          final lastIndex = _routePoints.length - 1;
          final lastPoint = _routePoints[lastIndex];
          final secondLastPoint = _routePoints[lastIndex - 1];
          
          // Add distance between last two points
          final distanceBetween = Geolocator.distanceBetween(
            secondLastPoint.latitude, secondLastPoint.longitude,
            lastPoint.latitude, lastPoint.longitude,
          );
          
          _distance += distanceBetween;
          
          // Update estimated steps (average step length is about 0.762 meters)
          _estimatedSteps = (_distance / 0.762).round();
        }
      });
      
      // Center map on current position
      _mapController.move(newPoint, _mapController.zoom);
    });
  }
  
  // Stop tracking the walk
  void _stopTracking() {
    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
    });
    
    // Save the route data
    _saveRoute();
  }
  
  // Save route and update steps
  void _saveRoute() {
    if (_routePoints.isEmpty) return;
    
    // Calculate duration
    final duration = DateTime.now().difference(_startTime!);
    
    // Update steps in StepsService
    final stepsService = Provider.of<StepsService>(context, listen: false);
    
    // Show summary dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Walk Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${(_distance / 1000).toStringAsFixed(2)} km'),
            Text('Duration: ${duration.inMinutes} minutes'),
            Text('Estimated Steps: $_estimatedSteps'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add the estimated steps to today's total
              // In a real app, this would sync with the health API
              stepsService.addSteps(_estimatedSteps);
              
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to home screen
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Steps added to your daily total!')),
              );
            },
            child: const Text('Add Steps'),
          ),
        ],
      ),
    );
    
    // In a real app, save the GPS route to Firebase
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Walk'),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(0, 0),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.burnbank.app',
              ),
              // Current location marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 30.0,
                      height: 30.0,
                      point: _currentPosition!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30.0,
                      ),
                    ),
                  ],
                ),
              // Route polyline
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
            ],
          ),
          
          // Stats overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distance:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${(_distance / 1000).toStringAsFixed(2)} km'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Est. Steps:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('$_estimatedSteps'),
                      ],
                    ),
                    if (_isTracking && _startTime != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Duration:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, snapshot) {
                              final duration = DateTime.now().difference(_startTime!);
                              return Text('${duration.inMinutes}m ${duration.inSeconds % 60}s');
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
        label: Text(_isTracking ? 'Stop' : 'Start Walk'),
        backgroundColor: _isTracking ? Colors.red : Theme.of(context).primaryColor,
      ),
    );
  }
}