import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class MapService {
  // Updated default center coordinates to Universiti Malaya, Kuala Lumpur
  static const LatLng defaultCenter = LatLng(3.1209, 101.6538);
  static const double defaultZoom = 16.0; // Increased zoom level for closer view
  static const double userLocationZoom = 17.0; // Zoom level when focusing on user location
  
  // Default map options
  static const MapOptions defaultMapOptions = MapOptions(
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    myLocationButtonEnabled: false,
    compassEnabled: true,
    zoomGesturesEnabled: true,
    rotateGesturesEnabled: true,
    tiltGesturesEnabled: true,
    scrollGesturesEnabled: true,
  );
  
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
  
  // Get gesture recognizers for more reliable map interactions
  static Set<Factory<OneSequenceGestureRecognizer>> getGestureRecognizers() {
    return {
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
      Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
      Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
      Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
    };
  }
}

// Map configuration options class
class MapOptions {
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final bool myLocationButtonEnabled;
  final bool compassEnabled;
  final bool zoomGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool scrollGesturesEnabled;
  
  const MapOptions({
    required this.zoomControlsEnabled,
    required this.mapToolbarEnabled,
    required this.myLocationButtonEnabled,
    required this.compassEnabled,
    required this.zoomGesturesEnabled,
    required this.rotateGesturesEnabled,
    required this.tiltGesturesEnabled,
    required this.scrollGesturesEnabled,
  });
}
