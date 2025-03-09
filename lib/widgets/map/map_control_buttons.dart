import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapControlButtons extends StatelessWidget {
  final LatLng? userLocation;
  final VoidCallback onLocationPressed;
  final VoidCallback onUMPressed;
  final VoidCallback onZoomInPressed;
  final VoidCallback onZoomOutPressed;

  const MapControlButtons({
    super.key,
    required this.userLocation,
    required this.onLocationPressed,
    required this.onUMPressed,
    required this.onZoomInPressed,
    required this.onZoomOutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          // My Location button
          FloatingActionButton.small(
            heroTag: 'my_location',
            onPressed: onLocationPressed,
            backgroundColor: userLocation != null ? Colors.blue : Colors.grey,
            child: const Icon(Icons.my_location, size: 20),
          ),
          const SizedBox(height: 8),
          // UM button - go to Universiti Malaya
          FloatingActionButton.small(
            heroTag: 'go_to_um',
            onPressed: onUMPressed,
            backgroundColor: Colors.green,
            child: const Text('UM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          // Zoom in button
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: onZoomInPressed,
            child: const Icon(Icons.add, size: 20),
          ),
          const SizedBox(height: 8),
          // Zoom out button
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: onZoomOutPressed,
            child: const Icon(Icons.remove, size: 20),
          ),
        ],
      ),
    );
  }
}
