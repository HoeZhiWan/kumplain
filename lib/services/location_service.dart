import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class UserLocationData {
  final LatLng location;
  final Set<Circle> circles;
  final Marker marker;
  final double dotRadius;
  final double pulseRadius;
  
  UserLocationData({
    required this.location,
    required this.circles,
    required this.marker,
    required this.dotRadius,
    required this.pulseRadius,
  });
}

class LocationService {
  // Fixed sizes for the user location display
  final double _dotRadius = 4.0;
  final double _pulseRadius = 25.0;
  
  // Request location permission
  Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      return true;
    } else {
      // Show a dialog explaining why location is needed
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Permission'),
            content: const Text(
              'Location permission is required to show your current location on the map and to accurately report complaints.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  // Get current location and return location data with fixed sizes
  Future<UserLocationData?> getUserLocation(BuildContext context, {double mapZoom = 16.0}) async {
    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
      }
      return null;
    }
    
    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return null;
      }
    }
    
    // If permission is denied forever, handle appropriately
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, please enable in settings'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
    
    // Get current location
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5), // Add a timeout to prevent hanging
    );
    final userLocation = LatLng(position.latitude, position.longitude);
    
    // Use fixed sizes
    final dotRadius = _dotRadius;
    final pulseRadius = _pulseRadius;
    
    // For initial display with fixed sizing
    final userLocationDot = Circle(
      circleId: const CircleId('user_location_dot'),
      center: userLocation,
      radius: dotRadius,
      fillColor: Colors.blue,
      strokeColor: Colors.white,
      strokeWidth: 2,
      zIndex: 2,
    );
    
    final userLocationPulse = Circle(
      circleId: const CircleId('user_location_pulse'),
      center: userLocation,
      radius: pulseRadius, 
      fillColor: Colors.blue.withOpacity(0.15),
      strokeColor: Colors.blue.withOpacity(0.3),
      strokeWidth: 2,
      zIndex: 1,
    );
    
    // Create user marker (hidden but with info window capability)
    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: userLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You are here'),
      visible: false,
    );
    
    return UserLocationData(
      location: userLocation,
      circles: {userLocationDot, userLocationPulse},
      marker: userMarker,
      dotRadius: dotRadius,
      pulseRadius: pulseRadius,
    );
  }
  
  // Method to update circles with fixed sizes
  Set<Circle> updateLocationCircles(LatLng userLocation, double mapZoom) {
    final userLocationDot = Circle(
      circleId: const CircleId('user_location_dot'),
      center: userLocation,
      radius: _dotRadius,
      fillColor: Colors.blue,
      strokeColor: Colors.white,
      strokeWidth: 2,
      zIndex: 2,
    );
    
    final userLocationPulse = Circle(
      circleId: const CircleId('user_location_pulse'),
      center: userLocation,
      radius: _pulseRadius,
      fillColor: Colors.blue.withOpacity(0.15),
      strokeColor: Colors.blue.withOpacity(0.3),
      strokeWidth: 2,
      zIndex: 1,
    );
    
    return {userLocationDot, userLocationPulse};
  }
}
