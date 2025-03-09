import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Mock data for complaints on the map
  final List<Map<String, dynamic>> mockComplaints = [
    {
      'id': '1',
      'title': 'Broken street light',
      'latitude': 1.3521,
      'longitude': 103.8198,
    },
    {
      'id': '2',
      'title': 'Pothole on road',
      'latitude': 1.3423,
      'longitude': 103.8353,
    },
    {
      'id': '3', 
      'title': 'Garbage not collected',
      'latitude': 1.3644,
      'longitude': 103.9915,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Placeholder for the map
          Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Map View',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          
          // Mock complaint markers
          ...mockComplaints.map((complaint) => Positioned(
            left: (complaint['longitude'] - 103.8) * 500,
            top: (complaint['latitude'] - 1.3) * 500,
            child: GestureDetector(
              onTap: () {
                // Navigate to complaint details screen
                context.push('/complaint/${complaint['id']}', extra: complaint);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to complaint submission screen with current location
          context.push('/submit', extra: {
            'latitude': 1.3521,
            'longitude': 103.8198,
          });
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
