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
      'description': 'The street light has been broken for weeks now. It\'s becoming a safety hazard at night.',
      'latitude': 1.3521,
      'longitude': 103.8198,
      'reportedBy': 'john_doe',
      'reportedAt': '2 hours ago',
    },
    {
      'id': '2',
      'title': 'Pothole on road',
      'description': 'There\'s a large pothole that\'s damaging vehicles. It needs immediate repair.',
      'latitude': 1.3423,
      'longitude': 103.8353,
      'reportedBy': 'amie_johnson',
      'reportedAt': '4 hours ago',
    },
    {
      'id': '3', 
      'title': 'Garbage not collected',
      'description': 'The garbage has not been collected for over a week now. It\'s starting to smell and attract pests.',
      'latitude': 1.3644,
      'longitude': 103.9915,
      'reportedBy': 'harry_potter',
      'reportedAt': '12 hours ago',
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
