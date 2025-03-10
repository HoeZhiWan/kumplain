import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapControllerHelper {
  GoogleMapController? mapController;
  Completer<void>? mapAnimationCompleter;
  bool isCameraMoving = false;
  
  // Function to be called when camera state changes
  final void Function(bool) onCameraMovingChanged;
  
  MapControllerHelper({required this.onCameraMovingChanged});
  
  void setController(GoogleMapController controller) {
    mapController = controller;
  }
  
  Future<void> moveToLocation(LatLng location, double zoom) async {
    if (mapController == null) return;
    
    cancelMapAnimation();
    
    final cameraUpdate = CameraUpdate.newLatLngZoom(location, zoom);
    
    try {
      // Create a new completer to track this animation
      mapAnimationCompleter = Completer<void>();
      
      // Set a timeout to ensure the animation completes eventually
      Timer(const Duration(seconds: 3), () {
        if (mapAnimationCompleter != null && !mapAnimationCompleter!.isCompleted) {
          debugPrint('Map animation timed out - resetting state');
          mapAnimationCompleter!.complete();
          mapAnimationCompleter = null;
          
          if (isCameraMoving) {
            isCameraMoving = false;
            onCameraMovingChanged(false);
          }
        }
      });
      
      await mapController!.animateCamera(cameraUpdate);
      
      // Complete the animation
      if (mapAnimationCompleter?.isCompleted == false) {
        mapAnimationCompleter?.complete();
        mapAnimationCompleter = null;
      }
    } catch (e) {
      debugPrint('Error moving camera: $e');
      if (mapAnimationCompleter?.isCompleted == false) {
        mapAnimationCompleter?.completeError(e);
        mapAnimationCompleter = null;
      }
    } finally {
      // Ensure we reset the camera movement state
      if (isCameraMoving) {
        isCameraMoving = false;
        onCameraMovingChanged(false);
      }
    }
  }
  
  void cancelMapAnimation() {
    if (mapAnimationCompleter != null && !mapAnimationCompleter!.isCompleted) {
      mapAnimationCompleter?.complete();
      mapAnimationCompleter = null;
    }
    
    if (isCameraMoving) {
      isCameraMoving = false;
      onCameraMovingChanged(false);
    }
  }
  
  // More reliable navigation without animation
  Future<void> moveToLocationImmediately(LatLng location, double zoom) async {
    if (mapController == null) return;
    
    cancelMapAnimation();
    
    try {
      await mapController!.moveCamera(CameraUpdate.newLatLngZoom(location, zoom));
    } catch (e) {
      debugPrint('Error during immediate camera move: $e');
    } finally {
      if (isCameraMoving) {
        isCameraMoving = false;
        onCameraMovingChanged(false);
      }
    }
  }
  
  void zoomIn() async {
    if (mapController == null) return;
    cancelMapAnimation();
    try {
      await mapController!.moveCamera(CameraUpdate.zoomIn());
    } catch (e) {
      debugPrint('Error during zoom in: $e');
    }
  }
  
  void zoomOut() async {
    if (mapController == null) return;
    cancelMapAnimation();
    try {
      await mapController!.moveCamera(CameraUpdate.zoomOut());
    } catch (e) {
      debugPrint('Error during zoom out: $e');
    }
  }
  
  // Handle camera movement
  void handleCameraMove(CameraPosition position) {
    isCameraMoving = true;
    onCameraMovingChanged(true);
  }
  
  void handleCameraIdle() {
    isCameraMoving = false;
    onCameraMovingChanged(false);
  }
  
  void dispose() {
    cancelMapAnimation();
    mapController?.dispose();
    mapController = null;
  }
}
