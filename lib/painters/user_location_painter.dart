import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserLocationPainter extends CustomPainter {
  final GoogleMapController? mapController;
  final LatLng userLocation;
  
  UserLocationPainter(this.mapController, this.userLocation);
  
  @override
  bool hitTest(Offset position) {
    // Return false to ensure touch events pass through to the map
    // This is critical - returning true here would capture touch events
    return false;
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    // Only draw if we have a controller to convert coordinates
    if (mapController == null) return;
    
    try {
      // Calculate the center of the screen as our drawing point
      // Note: This is a simplified approach. For actual implementation,
      // you would need to project lat/lng to screen coordinates
      final center = Offset(size.width / 2, size.height / 2);
      
      // Draw the accuracy circle (pulse effect)
      final pulseRadius = 50.0;
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
      
      // Draw the user location dot
      final dotPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8, dotPaint);
      
      // Draw white border around the dot
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 8, borderPaint);
    } catch (e) {
      // Silently handle any errors during painting
      debugPrint('Error painting user location: $e');
    }
  }
  
  @override
  bool shouldRepaint(UserLocationPainter oldDelegate) {
    return oldDelegate.userLocation != userLocation;
  }
}
