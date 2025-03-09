import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../router.dart';
import '../services/map_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  CameraPosition _currentCameraPosition = MapService.getInitialCameraPosition();
  bool _isLoadingLocation = false;
  LatLng? _userLocation;
  bool _showDefaultLocationMarker = false; // Define the variable
  // Increased zoom level for closer view
  final double _userLocationZoom = 17.0; 
  
  // Selection mode state
  bool _isSelectionMode = false;
  LatLng _selectedLocation = MapService.defaultCenter;
  
  // Animation controller for drag hint
  late AnimationController _dragHintController;
  late Animation<Offset> _dragHintAnimation;
  bool _showDragHint = false;
  
  // Track if camera is currently moving programmatically
  bool _isCameraMoving = false;
  
  @override
  void initState() {
    super.initState();
    _loadMarkers();
    // Request location permission when the screen initializes
    _requestLocationPermission();
    
    // Initialize animation controller for drag hint
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
            // Navigate to complaint details screen
            context.push('/complaint/${complaint['id']}', extra: complaint);
          },
        )
      ).toSet();
    });
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      // Show a dialog explaining why location is needed
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Permission'),
            content: const Text(
              'Location permission is required to show your current location on the map and to accurately report complaints.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Get current location and update user location marker
  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }
      
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }
      
      // If permission is denied forever, handle appropriately
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied, please enable in settings'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        final userLocation = LatLng(position.latitude, position.longitude);
        
        // Create user location dot (small blue circle)
        final userLocationDot = Circle(
          circleId: const CircleId('user_location_dot'),
          center: userLocation,
          radius: 8, // Small dot size
          fillColor: Colors.blue,
          strokeColor: Colors.white,
          strokeWidth: 2,
          zIndex: 2, // Above other elements
        );
        
        // Create outer pulse circle
        final userLocationPulse = Circle(
          circleId: const CircleId('user_location_pulse'),
          center: userLocation,
          radius: 50, // Larger pulse radius
          fillColor: Colors.blue.withOpacity(0.15),
          strokeColor: Colors.blue.withOpacity(0.3),
          strokeWidth: 2,
          zIndex: 1,
        );

        setState(() {
          _userLocation = userLocation;
          _isLoadingLocation = false;
          
          // Update circles
          _circles = {userLocationDot, userLocationPulse};
          
          // Optional: Create a marker at user location if you want a label
          final userMarker = Marker(
            markerId: const MarkerId('user_location'),
            position: userLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'You are here'),
            visible: false, // Hide marker but keep info window capability
          );
          
          // Add user marker to the set of markers
          _markers = {..._markers}; // Create a new set
          _markers.removeWhere((marker) => marker.markerId.value == 'user_location');
          _markers.add(userMarker);
        });
        
        // Move camera to user location with increased zoom
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _userLocation!,
              zoom: _userLocationZoom,
            ),
          ),
        );
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

  // Go to user location with increased zoom
  void _goToUserLocation() {
    if (_userLocation != null) {
      // Set flag that we're moving camera programmatically
      _isCameraMoving = true;
      
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _userLocation!,
            zoom: _userLocationZoom,
          ),
        ),
      ).then((_) {
        // Reset flag after animation completes
        if (mounted) {
          setState(() {
            _isCameraMoving = false;
          });
        }
      });
    } else {
      _getCurrentLocation();
    }
  }
  
  // Go to UM location
  void _goToUM() {
    // Set flag that we're moving camera programmatically
    _isCameraMoving = true;
    
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(3.1209, 101.6538),
          zoom: 16.0,
        ),
      ),
    ).then((_) {
      // Reset flag after animation completes
      if (mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    });
  }
  
  // Handle zoom in
  void _zoomIn() {
    _isCameraMoving = true;
    _mapController?.animateCamera(CameraUpdate.zoomIn()).then((_) {
      if (mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    });
  }
  
  // Handle zoom out
  void _zoomOut() {
    _isCameraMoving = true;
    _mapController?.animateCamera(CameraUpdate.zoomOut()).then((_) {
      if (mounted) {
        setState(() {
          _isCameraMoving = false;
        });
      }
    });
  }
  
  // Enter location selection mode
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedLocation = _currentCameraPosition.target;
      _showDragHint = true;
    });
    
    // Show instruction snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Move the map by dragging to position the marker at your desired location'),
        duration: Duration(seconds: 4),
      ),
    );
    
    // Hide drag hint after a few seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showDragHint = false;
        });
      }
    });
  }
  
  // Cancel selection mode
  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _showDragHint = false;
    });
  }
  
  // Use the selected location and navigate to submit form
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
  
  // Update selected location when camera moves
  void _handleCameraMove(CameraPosition position) {
    _currentCameraPosition = position;
    
    if (_isSelectionMode) {
      setState(() {
        _selectedLocation = position.target;
        // Hide drag hint when user starts moving the map
        _showDragHint = false;
      });
    }
  }
  
  // Called when camera movement is complete
  void _onCameraIdle() {
    // Reset any camera movement flags
    if (_isCameraMoving && mounted) {
      setState(() {
        _isCameraMoving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? const Text('Select Complaint Location')
            : const Text('Complaints Map'),
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
          GoogleMap(
            initialCameraPosition: MapService.getInitialCameraPosition(),
            markers: _isSelectionMode ? {} : _markers, // Hide regular markers in selection mode
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
            // Ensure map is always draggable
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            liteModeEnabled: false,
          ),
          
          // Custom user location indicator
          if (_userLocation != null && !_showDefaultLocationMarker && !_isSelectionMode) 
            Positioned.fill(
              child: CustomPaint(
                painter: UserLocationPainter(_mapController, _userLocation!),
              ),
            ),
            
          // Selection mode marker in center of screen
          if (_isSelectionMode)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pin in selection mode
                  SlideTransition(
                    position: _dragHintAnimation,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 42,
                    ),
                  ),
                  // Offset for the pin's point
                  const SizedBox(height: 20),
                  
                  // Coordinates display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, '
                      'Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          // Drag hint in selection mode
          if (_isSelectionMode && _showDragHint)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.touch_app, size: 48, color: Colors.blue),
                          const SizedBox(height: 16),
                          const Text(
                            'Drag the map to move',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Position the pin at your complaint location',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showDragHint = false;
                              });
                            },
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Loading indicator
          if (_isLoadingLocation)
            const Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("Getting your location..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Custom controls in the top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                // My Location button
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: _isCameraMoving ? null : _goToUserLocation,
                  backgroundColor: _userLocation != null 
                      ? (_isCameraMoving ? Colors.grey : Colors.blue) 
                      : Colors.grey,
                  child: const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 8),
                // UM button - go to Universiti Malaya
                FloatingActionButton.small(
                  heroTag: 'go_to_um',
                  onPressed: _isCameraMoving ? null : _goToUM,
                  backgroundColor: _isCameraMoving ? Colors.grey.shade400 : Colors.green,
                  child: const Text('UM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                // Zoom in button
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: _isCameraMoving ? null : _zoomIn,
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                // Zoom out button
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: _isCameraMoving ? null : _zoomOut,
                  child: const Icon(Icons.remove, size: 20),
                ),
              ],
            ),
          ),
          
          // Selection mode confirm button at bottom
          if (_isSelectionMode)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    // Instruction text
                    if (!_showDragHint) // Don't show this when drag hint is visible
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text('Drag the map to move the pin'),
                          ],
                        ),
                      ),
                    // Confirm button
                    ElevatedButton.icon(
                      onPressed: _useSelectedLocation,
                      icon: const Icon(Icons.check),
                      label: const Text('Use This Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Keep the original FAB but change its behavior
      floatingActionButton: _isSelectionMode
          ? null // Hide FAB in selection mode
          : FloatingActionButton(
              onPressed: _isCameraMoving ? null : _enterSelectionMode, // Now enters selection mode instead
              child: const Icon(Icons.add_a_photo),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  @override
  void dispose() {
    _dragHintController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

// Custom painter to draw user location with pulsing effect
class UserLocationPainter extends CustomPainter {
  final GoogleMapController? mapController;
  final LatLng userLocation;
  
  UserLocationPainter(this.mapController, this.userLocation);

  @override
  void paint(Canvas canvas, Size size) {
    if (mapController == null) return;
    
    // This is a simplified approach - for proper implementation,
    // we would need to convert geo coordinates to screen coordinates
    // which requires more complex calculations
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
