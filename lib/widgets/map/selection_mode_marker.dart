import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelectionModeMarker extends StatelessWidget {
  final Animation<Offset> animation;
  final LatLng selectedLocation;

  const SelectionModeMarker({
    super.key,
    required this.animation,
    required this.selectedLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated pin in selection mode
          SlideTransition(
            position: animation,
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 42,
            ),
          ),
          // Offset for the pin's point
          const SizedBox(height: 20),
          
          // Coordinates display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'Lat: ${selectedLocation.latitude.toStringAsFixed(5)}, '
              'Lng: ${selectedLocation.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
