import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapService {
  // Updated default center coordinates to Universiti Malaya, Kuala Lumpur
  static const LatLng defaultCenter = LatLng(3.1209, 101.6538);
  static const double defaultZoom = 16.0; // Increased zoom level for closer view
  
  // Create a marker for a complaint
  static Marker createComplaintMarker({
    required String id,
    required Map<String, dynamic> complaint,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(
        complaint['latitude'] as double,
        complaint['longitude'] as double,
      ),
      infoWindow: InfoWindow(
        title: complaint['title'] as String,
        snippet: complaint['description'] as String,
        onTap: () => onTap(complaint),
      ),
      onTap: () => onTap(complaint),
    );
  }
  
  // Create an initial camera position
  static CameraPosition getInitialCameraPosition() {
    return const CameraPosition(
      target: defaultCenter,
      zoom: defaultZoom,
    );
  }
}
