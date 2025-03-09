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
import '../painters/user_location_painter.dart';

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
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final userLocationData = await _locationService.getUserLocation(context);
      
      if (userLocationData != null && mounted) {
        final userLocation = userLocationData.location;
        
        setState(() {
          _userLocation = userLocation;
          _circles = userLocationData.circles;
          
          // Update markers with user location
          _markers = {..._markers};
          _markers.removeWhere((marker) => marker.markerId.value == 'user_location');
          _markers.add(userLocationData.marker);
        });
        
        // Move camera to user location
        await _moveToLocation(userLocation, _userLocationZoom);
        
        // Set loading to false after camera movement completes
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      } else {
        // Make sure to set loading to false if no location data
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  // Move camera to specific location
  Future<void> _moveToLocation(LatLng location, double zoom) async {
    if (_mapController == null) return;
    
    _cancelMapAnimation();
    _mapAnimationCompleter = Completer<void>();
    
    setState(() {
      _isCameraMoving = true;
    });
    
    try {
      // Use animateCamera instead of moveCamera for smoother transitions
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
        // duration: const Duration(milliseconds: 800),
      );
      
      // Longer delay to ensure animation fully completes and system stabilizes
      await Future.delayed(const Duration(milliseconds: 300));
      
    } catch (e) {
      debugPrint('Error moving camera: $e');
    } finally {
      // Always reset these states in finally block to ensure they're reset even on errors
      if (_mapAnimationCompleter != null && !_mapAnimationCompleter!.isCompleted) {
        _mapAnimationCompleter!.complete();
      }
      _mapAnimationCompleter = null;
      
      if (mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    }
  }
  
  void _cancelMapAnimation() {
    if (_mapAnimationCompleter != null) {
      if (!_mapAnimationCompleter!.isCompleted) {
        _mapAnimationCompleter!.complete();
      }
      _mapAnimationCompleter = null;
    }
    
    // Make sure to reset camera movement flag
    if (_isCameraMoving) {
      setState(() {
        _isCameraMoving = false;
      });
    }
  }

  // Navigation helpers
  void _goToUserLocation() {
    if (_userLocation != null) {
      _moveToLocation(_userLocation!, _userLocationZoom)
        .then((_) {
          // Force reset all camera movement states after animation
          if (mounted) {
            setState(() {
              _isCameraMoving = false;
            });
            
            // Add a small delay and then trigger an empty camera update
            // This helps "unstick" the map in some cases
            Future.delayed(const Duration(milliseconds: 100), () {
              _mapController?.moveCamera(CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _userLocation!,
                  zoom: _currentCameraPosition.zoom,
                )
              ));
            });
          }
        });
    } else {
      _getCurrentLocation();
    }
  }
  
  void _goToUM() {
    _moveToLocation(MapService.defaultCenter, 16.0);
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
    });
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
            initialCameraPosition: MapService.getInitialCameraPosition(),
            markers: _isSelectionMode ? {} : _markers,
            circles: _circles,
            myLocationEnabled: false,
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _getCurrentLocation();
            },
            onCameraMove: _handleCameraMove,
            onCameraIdle: _onCameraIdle,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            liteModeEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(1, 20),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            //   Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
            //   Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            //   Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            //   Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
            //   Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),           
            },
          ),
          
          // Custom user location indicator
          if (_userLocation != null && !_showDefaultLocationMarker && !_isSelectionMode) 
            Positioned.fill(
              child: CustomPaint(
                painter: UserLocationPainter(_mapController, _userLocation!),
              ),
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
