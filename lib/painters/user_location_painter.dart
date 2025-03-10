import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class UserLocationPainter extends CustomPainter {
  final GoogleMapController? mapController;
  final LatLng userLocation;
  final double mapZoom;
  
  // Fixed base sizes
  final double _dotBaseRadius = 15.0;
  final double _pulseBaseRadius = 50.0;
  
  UserLocationPainter(
    this.mapController, 
    this.userLocation, 
    {this.mapZoom = 16.0}
  );
  
  // Calculate screen radius that remains constant regardless of zoom
  double _getScreenRadius(double baseRadius) {
    // Base zoom is 16.0
    final double zoomFactor = pow(2.0, 16.0 - mapZoom) as double;
    return baseRadius * zoomFactor;
  }
  
  @override
  bool hitTest(Offset position) {
    // Return false to ensure touch events pass through to the map
    return false;
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    // Only draw if we have a controller to convert coordinates
    if (mapController == null) return;
    
    try {
      // We need to calculate the screen position of our location coordinates
      // For this example, we're using the center of the screen to match the map camera position
      // This assumes the userLocation is at the center of the map camera
      final center = Offset(size.width / 2, size.height / 2);
      
      // Calculate zoom-adjusted radius to maintain consistent screen size
      final pulseRadius = _getScreenRadius(_pulseBaseRadius);
      final dotRadius = _getScreenRadius(_dotBaseRadius);
      
      // Draw the accuracy circle (pulse effect) with zoom-adjusted size
      final pulsePaint = Paint()
        ..color = Colors.blue.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, pulseRadius, pulsePaint);
      
      // Draw the stroke for accuracy circle
      final pulseStrokePaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, pulseRadius, pulseStrokePaint);
      
      // Draw the user location dot - zoom-adjusted size
      final dotPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, dotRadius, dotPaint);
      
      // Draw white border around the dot
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, dotRadius, borderPaint);
    } catch (e) {
      // Silently handle any errors during painting
      debugPrint('Error painting user location: $e');
    }
  }
  
  @override
  bool shouldRepaint(UserLocationPainter oldDelegate) {
    return oldDelegate.userLocation != userLocation || oldDelegate.mapZoom != mapZoom;
  }
}
