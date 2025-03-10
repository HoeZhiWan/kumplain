import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../router.dart';
import '../services/map_service.dart';
import '../services/location_service.dart';
import '../widgets/map/selection_mode_marker.dart';
import '../widgets/map/drag_hint_overlay.dart';
import '../widgets/map/location_loading_indicator.dart';
import '../widgets/map/map_control_buttons.dart';
import '../widgets/map/selection_confirm_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  // Controllers
  GoogleMapController? _mapController;
  late AnimationController _dragHintController;
  late Animation<Offset> _dragHintAnimation;
  
  // State variables
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  CameraPosition _currentCameraPosition = MapService.getInitialCameraPosition();
  bool _isLoadingLocation = false;
  LatLng? _userLocation;
  bool _showDefaultLocationMarker = false;
  final double _userLocationZoom = 17.0;
  
  // Add this method to update location circles when zoom changes
  void _updateLocationCircles() {
    if (_userLocation == null) return;
    
    setState(() {
      // Let LocationService handle the scaling calculations
      _circles = _locationService.updateLocationCircles(
        _userLocation!,
        _currentCameraPosition.zoom
      );
    });
    
    // Debug output
    debugPrint('Updated circles with zoom: ${_currentCameraPosition.zoom}');
  }
  
  // Selection mode state
  bool _isSelectionMode = false;
  LatLng _selectedLocation = MapService.defaultCenter;
  bool _showDragHint = false;
  bool _isCameraMoving = false;
  
  // Camera movement tracking
  Completer<void>? _mapAnimationCompleter;
  
  final LocationService _locationService = LocationService();
  
  @override
  void initState() {
    super.initState();
    _loadMarkers();
    // Request location permission
    _locationService.requestLocationPermission(context).then((_) {
      if (mounted) _getCurrentLocation();
    });
    
    // Initialize animation controller
    _dragHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _dragHintAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -10),
    ).animate(CurvedAnimation(
      parent: _dragHintController,
      curve: Curves.easeInOut,
    ));
  }
  
  void _loadMarkers() {
    setState(() {
      _markers = mockComplaints.map((complaint) => 
        MapService.createComplaintMarker(
          id: complaint['id'] as String,
          complaint: complaint,
          onTap: (complaint) {
            context.push('/complaint/${complaint['id']}', extra: complaint);
          },
        )
      ).toSet();
    });
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      final locationData = await _locationService.getUserLocation(context);

      if (locationData != null && mounted) {
        setState(() {
          _userLocation = locationData.location;
          _markers = _markers.union({locationData.marker});
          _isLoadingLocation = false;
        });
        
        // Update circles with appropriate scale
        _updateLocationCircles();
        
        // Move camera to user location if it's the first time
        if (_mapController != null && _userLocation != null) {
          _navigateToLocation(_userLocation!, _userLocationZoom);
        }
      } else if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get your location: $e')),
        );
      }
    }
  }

  // Move camera to specific location
  Future<void> _moveToLocation(LatLng location, double zoom) async {
    if (_mapController == null) return;
    
    _cancelMapAnimation();
    
    final cameraUpdate = CameraUpdate.newLatLngZoom(location, zoom);
    
    try {
      // Create a new completer to track this animation
      _mapAnimationCompleter = Completer<void>();
      
      // Set a timeout to ensure the animation completes eventually
      Timer(const Duration(seconds: 3), () {
        if (_mapAnimationCompleter != null && !_mapAnimationCompleter!.isCompleted) {
          debugPrint('Map animation timed out - resetting state');
          _mapAnimationCompleter!.complete();
          _mapAnimationCompleter = null;
          
          if (_isCameraMoving && mounted) {
            setState(() {
              _isCameraMoving = false;
            });
          }
        }
      });
      
      await _mapController!.animateCamera(cameraUpdate);
      
      // Complete the animation
      if (_mapAnimationCompleter?.isCompleted == false) {
        _mapAnimationCompleter?.complete();
        _mapAnimationCompleter = null; // Reset the completer
      }
    } catch (e) {
      debugPrint('Error moving camera: $e');
      if (_mapAnimationCompleter?.isCompleted == false) {
        _mapAnimationCompleter?.completeError(e);
        _mapAnimationCompleter = null; // Reset the completer on error too
      }
    } finally {
      // Ensure we reset the camera movement state
      if (_isCameraMoving && mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    }
  }
  
  void _cancelMapAnimation() {
    // Cancel any ongoing animation
    if (_mapAnimationCompleter != null && !_mapAnimationCompleter!.isCompleted) {
      _mapAnimationCompleter?.complete();
      _mapAnimationCompleter = null;
    }
    
    // Make sure to reset camera movement flag
    if (_isCameraMoving && mounted) {
      setState(() {
        _isCameraMoving = false;
      });
    }
  }

  // Navigation helpers
  Future<void> _navigateToLocation(LatLng location, double zoom) async {
    if (_mapController == null) {
      return Future.value();
    }
    try {
      await _moveToLocation(location, zoom);
    } finally {
      // Ensure animation state is reset even if there's an error
      _cancelMapAnimation();
    }
  }

  // Let's modify this to use moveCamera instead of animateCamera for more reliable behavior
  Future<void> _goToUserLocation() async {
    if (_userLocation == null) {
      _getCurrentLocation();
      return;
    }
    
    if (_mapController == null) return;
    
    try {
      _cancelMapAnimation();
      
      // Use moveCamera for immediate positioning without animation
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, _userLocationZoom)
      );
    } catch (e) {
      debugPrint('Error going to user location: $e');
    } finally {
      // Make sure camera state is reset
      if (_isCameraMoving && mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    }
  }
  
  // Make the UM navigation more reliable too
  Future<void> _goToUM() async {
    // UM coordinates (Universiti Malaya)
    final umLocation = const LatLng(3.1209, 101.6538);
    
    if (_mapController == null) return;
    
    try {
      _cancelMapAnimation();
      
      // Use moveCamera for immediate positioning without animation
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(umLocation, 15.0)
      );
    } catch (e) {
      debugPrint('Error going to UM: $e');
    } finally {
      // Make sure camera state is reset
      if (_isCameraMoving && mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    }
  }
  
  // Zoom controls
  void _zoomIn() async {
    if (_mapController == null) return;
    _cancelMapAnimation();
    try {
      await _mapController!.moveCamera(CameraUpdate.zoomIn());
    } catch (e) {
      debugPrint('Error during zoom in: $e');
    }
  }
  
  void _zoomOut() async {
    if (_mapController == null) return;
    _cancelMapAnimation();
    try {
      await _mapController!.moveCamera(CameraUpdate.zoomOut());
    } catch (e) {
      debugPrint('Error during zoom out: $e');
    }
  }
  
  // Selection mode methods
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedLocation = _currentCameraPosition.target;
      _showDragHint = true;
    });
    
    // Hide drag hint after a few seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showDragHint = false;
        });
      }
    });
  }
  
  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _showDragHint = false;
    });
  }
  
  void _useSelectedLocation() {
    setState(() {
      _isSelectionMode = false;
      _showDragHint = false;
    });
    
    // Navigate to complaint submission screen with selected location
    context.push('/submit', extra: {
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
    });
  }
  
  // Camera movement handler
  void _handleCameraMove(CameraPosition position) {
    setState(() {
      _currentCameraPosition = position;
      _isCameraMoving = true;
    
      if (_isSelectionMode) {
        _selectedLocation = position.target;
        _showDragHint = false;
      }
      if (_userLocation != null) {
        _circles = _locationService.updateLocationCircles(
          _userLocation!,
          _currentCameraPosition.zoom
        );
      }
    });
    
    // Update user location circles when zoom changes
    if (_userLocation != null && !_isSelectionMode) {
      _updateLocationCircles();
    }
  }
  
  void _onCameraIdle() {
    setState(() {
      _isCameraMoving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSelectionMode,
              tooltip: 'Cancel',
            )
          else
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => context.push('/profile'),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map component
          GoogleMap(
            initialCameraPosition: _currentCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Move to user location if already available
              if (_userLocation != null) {
                // Use a slight delay to ensure the map is fully initialized
                Future.delayed(const Duration(milliseconds: 300), () {
                  _goToUserLocation();
                });
              }
            },
            markers: _isSelectionMode ? {} : _markers,
            circles: _isSelectionMode ? {} : _circles,
            myLocationEnabled: _showDefaultLocationMarker, 
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onCameraMove: _handleCameraMove,
            onCameraIdle: _onCameraIdle,
            // Make sure gestures are enabled
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            scrollGesturesEnabled: true,
            // Use more reliable gesture recognizers
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
          
          // Selection mode marker
          if (_isSelectionMode)
            SelectionModeMarker(
              animation: _dragHintAnimation,
              selectedLocation: _selectedLocation,
            ),
          
          // Drag hint overlay
          if (_isSelectionMode && _showDragHint)
            DragHintOverlay(
              onGotIt: () {
                setState(() {
                  _showDragHint = false;
                });
              },
            ),
          
          // Loading indicator
          if (_isLoadingLocation)
            const LocationLoadingIndicator(),
          
          // Map control buttons
          MapControlButtons(
            userLocation: _userLocation,
            onLocationPressed: _goToUserLocation,
            onUMPressed: _goToUM,
            onZoomInPressed: _zoomIn,
            onZoomOutPressed: _zoomOut,
          ),
          
          // Selection confirmation button
          if (_isSelectionMode)
            SelectionConfirmButton(
              showHint: !_showDragHint,
              onUseLocation: _useSelectedLocation,
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _isCameraMoving ? null : _enterSelectionMode,
              child: const Icon(Icons.add_a_photo),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  @override
  void dispose() {
    _cancelMapAnimation();
    _dragHintController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
