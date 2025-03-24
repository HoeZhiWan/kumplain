import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

import '../router.dart';
import '../services/map_service.dart';
import '../services/location_service.dart';
import '../services/complaint_service.dart';
import '../controllers/map_controller_helper.dart';
import '../widgets/map/selection_mode_marker.dart';
import '../widgets/map/location_loading_indicator.dart';
import '../widgets/map/map_control_buttons.dart';
import '../widgets/map/selection_confirm_button.dart';
import '../widgets/map/drag_hint_overlay.dart';
import '../widgets/map/map_ui_builder.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  late AnimationController _dragHintController;
  late Animation<Offset> _dragHintAnimation;
  late MapControllerHelper _mapControllerHelper;

  // State variables
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  CameraPosition _currentCameraPosition = MapService.getInitialCameraPosition();
  bool _isLoadingLocation = false;
  LatLng? _userLocation;
  bool _showDefaultLocationMarker = false;

  // Selection mode state
  bool _isSelectionMode = false;
  LatLng _selectedLocation = MapService.defaultCenter;
  bool _showDragHint = false;
  bool _isCameraMoving = false;

  final LocationService _locationService = LocationService();

  // Define the border of Universiti Malaya
  final List<LatLng> _umBorder = [
    LatLng(3.11928, 101.64288),
    LatLng(3.11658, 101.64910),
    LatLng(3.10988, 101.65253),
    LatLng(3.11683, 101.66395),
    LatLng(3.13501, 101.66080),
    LatLng(3.13461, 101.65414),
    LatLng(3.13083, 101.64849),
    LatLng(3.12485, 101.64731),
    
    // Add more coordinates to define the border
  ];

  Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    // Initialize map controller helper
    _mapControllerHelper = MapControllerHelper(
      onCameraMovingChanged: (isMoving) {
        if (mounted) {
          setState(() {
            _isCameraMoving = isMoving;
          });
        }
      },
    );

    _loadMarkers();
    _initializeLocationServices();
    _initializeAnimations();
    _loadPolygons();
  }

  void _initializeLocationServices() {
    // Request location permission
    _locationService.requestLocationPermission(context).then((_) {
      if (mounted) _getCurrentLocation();
    });
  }

  void _initializeAnimations() {
    _dragHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _dragHintAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -10),
    ).animate(
      CurvedAnimation(parent: _dragHintController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadMarkers() async {
    try {
      // Use ComplaintService to fetch complaints
      final complaints = await ComplaintService().getAllComplaints().first;
      
      setState(() {
        _markers = complaints
            .where((complaint) => 
                complaint.status == null || 
                !complaint.status!.startsWith('deleted'))
            .map(
              (complaint) => Marker(
                markerId: MarkerId(complaint.id ?? ''),
                position: LatLng(complaint.latitude, complaint.longitude),
                infoWindow: InfoWindow(
                  title: complaint.title,
                  snippet: complaint.description,
                ),
                onTap: () {
                  context.push('/complaint/${complaint.id}');
                },
              ),
            )
            .toSet();
      });
    } catch (e) {
      debugPrint('Error loading markers: $e');
    }
  }

  // Load the polygon for UM border
  Future<void> _loadPolygons() async {
    setState(() {
      _polygons = {
        Polygon(
          polygonId: PolygonId('um_border'),
          points: _umBorder,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0),
        ),
      };
    });
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {   
        _isLoadingLocation = true;
      });
    }
    try {
      // Pass current zoom level to getUserLocation
      final locationData = await _locationService.getUserLocation(
        context,
        mapZoom: _currentCameraPosition.zoom,
      );
      if (locationData != null && mounted) {
        setState(() {
          _userLocation = locationData.location;
          _markers = _markers.union({locationData.marker});
          _circles = locationData.circles;
          _isLoadingLocation = false;
        });
        _moveToUserLocationWithDelay();
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

  // Add refresh map method to reload markers and refresh location
  Future<void> _refreshMap() async {
    if (_isLoadingLocation) return; // Avoid refreshing if already loading
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Reload markers first
      await _loadMarkers();
      
      // Then get current location
      // await _getCurrentLocation();
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map updated with latest data')),
        );

        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing map: $e')),
        );
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _moveToUserLocationWithDelay() {
    // Move camera to user location if it's the first time
    if (_mapControllerHelper.mapController != null && _userLocation != null) {
      // Use a slight delay to ensure the map is fully initialized
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _goToUserLocation();
        }
      });
    }
  }

  // Update circles based on zoom
  void _updateLocationCircles() {
    if (_userLocation == null) return;

    setState(() {
      // Let LocationService handle the scaling calculations
      _circles = _locationService.updateLocationCircles(
        _userLocation!,
        _currentCameraPosition.zoom,
      );
    });

    // Debug output
    // debugPrint('Updated circles with zoom: ${_currentCameraPosition.zoom}');
  }

  // Navigation methods
  Future<void> _navigateToLocation(LatLng location, double zoom) async {
    return _mapControllerHelper.moveToLocation(location, zoom);
  }

  Future<void> _goToUserLocation() async {
    if (_userLocation == null) {
      _getCurrentLocation();
      return;
    }
    return _mapControllerHelper.moveToLocationImmediately(
      _userLocation!,
      MapService.userLocationZoom,
    );
  }

  Future<void> _goToUM() async {
    return _mapControllerHelper.moveToLocationImmediately(
      MapService.defaultCenter,
      MapService.defaultZoom,
    );
  }

  void _zoomIn() {
    _mapControllerHelper.zoomIn();
  }

  void _zoomOut() {
    _mapControllerHelper.zoomOut();
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

  bool _isWithinUM(LatLng point) {
    // Implement point-in-polygon algorithm
    bool isInside = false;
    for (int i = 0, j = _umBorder.length - 1; i < _umBorder.length; j = i++) {
      if (((_umBorder[i].latitude > point.latitude) != (_umBorder[j].latitude > point.latitude)) &&
          (point.longitude < (_umBorder[j].longitude - _umBorder[i].longitude) * (point.latitude - _umBorder[i].latitude) / (_umBorder[j].latitude - _umBorder[i].latitude) + _umBorder[i].longitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  void _useSelectedLocation() {
    if (!_isWithinUM(_selectedLocation)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location within Universiti Malaya')),
      );
      return;
    }

    setState(() {
      _isSelectionMode = false;
      _showDragHint = false;
    });

    // Navigate to complaint submission screen with selected location
    context.push(
      '/submit',
      extra: {
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
      },
    );
  }

  // Map configuration
  void _configureMap(GoogleMapController controller) {
    _mapControllerHelper.setController(controller);

    // Move to user location if already available
    if (_userLocation != null) {
      _moveToUserLocationWithDelay();
    }
  }

  // Camera movement handler
  void _handleCameraMove(CameraPosition position) {
    setState(() {
      _currentCameraPosition = position;

      if (_isSelectionMode) {
        _selectedLocation = position.target;
        _showDragHint = false;
      }
    });
    _mapControllerHelper.handleCameraMove(position);

    // Update user location circles when zoom changes
    if (_userLocation != null) {
      _updateLocationCircles();
    }
  }

  // Build map UI components
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: _currentCameraPosition,
      onMapCreated: _configureMap,
      markers: _isSelectionMode ? {} : _markers,
      circles: _circles,
      polygons: _polygons,
      myLocationEnabled: _showDefaultLocationMarker,
      zoomControlsEnabled: MapService.defaultMapOptions.zoomControlsEnabled,
      mapToolbarEnabled: MapService.defaultMapOptions.mapToolbarEnabled,
      compassEnabled: MapService.defaultMapOptions.compassEnabled,
      onCameraMove: _handleCameraMove,
      onCameraIdle: _mapControllerHelper.handleCameraIdle,
      zoomGesturesEnabled: MapService.defaultMapOptions.zoomGesturesEnabled,
      rotateGesturesEnabled: MapService.defaultMapOptions.rotateGesturesEnabled,
      tiltGesturesEnabled: MapService.defaultMapOptions.tiltGesturesEnabled,
      scrollGesturesEnabled: MapService.defaultMapOptions.scrollGesturesEnabled,
      gestureRecognizers: MapService.getGestureRecognizers(),
    );
  }

  // Build UI stack elements
  List<Widget> _buildUIOverlays() {
    final List<Widget> overlays = [];

    // Add map as base layer
    overlays.add(_buildMap());

    // Selection mode marker
    if (_isSelectionMode) {
      overlays.add(
        MapUIBuilder.buildSelectionModeMarker(
          animation: _dragHintAnimation,
          selectedLocation: _selectedLocation,
        ),
      );
    }

    // Drag hint overlay
    if (_isSelectionMode && _showDragHint) {
      overlays.add(
        MapUIBuilder.buildDragHintOverlay(
          onGotIt: () {
            setState(() {
              _showDragHint = false;
            });
          },
        ),
      );
    }

    // Loading indicator with appropriate message
    if (_isLoadingLocation) {
      overlays.add(
        MapUIBuilder.buildLoadingIndicator(
          message: _userLocation == null 
              ? "Getting your location..." 
              : "Refreshing map data...",
        ),
      );
    }

    // Map control buttons
    overlays.add(
      MapUIBuilder.buildMapControls(
        userLocation: _userLocation,
        onLocationPressed: _goToUserLocation,
        onUMPressed: _goToUM,
        onZoomInPressed: _zoomIn,
        onZoomOutPressed: _zoomOut,
      ),
    );

    // Selection confirmation buttons
    if (_isSelectionMode) {
      overlays.add(
        MapUIBuilder.buildSelectionConfirmButton(
          showHint: !_showDragHint,
          onUseLocation: _useSelectedLocation,
        ),
      );
    }

    return overlays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingLocation ? null : _refreshMap,
            tooltip: 'Refresh map',
          ),
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
      body: Stack(children: _buildUIOverlays()),
      floatingActionButton: MapUIBuilder.buildFloatingActionButton(
        isSelectionMode: _isSelectionMode,
        isCameraMoving: _isCameraMoving,
        onPressed: _enterSelectionMode,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _dragHintController.dispose();
    _mapControllerHelper.dispose();
    super.dispose();
  }
}