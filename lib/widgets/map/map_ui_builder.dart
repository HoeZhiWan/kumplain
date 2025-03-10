import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'selection_mode_marker.dart';
import 'location_loading_indicator.dart';
import 'map_control_buttons.dart';
import 'selection_confirm_button.dart';
import 'drag_hint_overlay.dart';

class MapUIBuilder {
  // Build selection mode marker
  static Widget buildSelectionModeMarker({
    required Animation<Offset> animation,
    required LatLng selectedLocation,
  }) {
    return SelectionModeMarker(
      animation: animation,
      selectedLocation: selectedLocation,
    );
  }
  
  // Build loading indicator
  static Widget buildLoadingIndicator() {
    return const LocationLoadingIndicator();
  }
  
  // Build map control buttons
  static Widget buildMapControls({
    required LatLng? userLocation,
    required VoidCallback onLocationPressed,
    required VoidCallback onUMPressed,
    required VoidCallback onZoomInPressed,
    required VoidCallback onZoomOutPressed,
  }) {
    return MapControlButtons(
      userLocation: userLocation,
      onLocationPressed: onLocationPressed,
      onUMPressed: onUMPressed,
      onZoomInPressed: onZoomInPressed,
      onZoomOutPressed: onZoomOutPressed,
    );
  }
  
  // Build selection confirm button
  static Widget buildSelectionConfirmButton({
    required bool showHint,
    required VoidCallback onUseLocation,
  }) {
    return SelectionConfirmButton(
      showHint: showHint,
      onUseLocation: onUseLocation,
    );
  }
  
  // Build drag hint overlay
  static Widget buildDragHintOverlay({
    required VoidCallback onGotIt,
  }) {
    return DragHintOverlay(
      onGotIt: onGotIt,
    );
  }
  
  // Build floating action button for adding a complaint
  static Widget? buildFloatingActionButton({
    required bool isSelectionMode,
    required bool isCameraMoving,
    required VoidCallback onPressed,
  }) {
    if (isSelectionMode) {
      return null;
    }
    
    return FloatingActionButton(
      onPressed: isCameraMoving ? null : onPressed,
      child: const Icon(Icons.add_a_photo),
    );
  }
}
