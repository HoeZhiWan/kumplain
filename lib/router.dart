import 'dart:async';  // Add this import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/auth_screen.dart';
import 'screens/map_screen.dart';
import 'screens/submit_complaint_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'screens/complaint_details_screen.dart';

// Mock data for complaints to be accessible app-wide
final List<Map<String, dynamic>> mockComplaints = [
  {
    'id': '1',
    'title': 'Broken street light',
    'description': 'The street light has been broken for weeks now. It\'s becoming a safety hazard at night.',
    'latitude': 1.3521,
    'longitude': 103.8198,
    'reportedBy': 'citizen123',
    'reportedAt': '3 hours ago',
    'imageUrl': null, // No actual image in mock data
    'votes': 15,
  },
  {
    'id': '2',
    'title': 'Pothole on road',
    'description': 'There\'s a large pothole that\'s damaging vehicles. It needs immediate repair.',
    'latitude': 1.3423,
    'longitude': 103.8353,
    'reportedBy': 'roaduser456',
    'reportedAt': '1 day ago',
    'imageUrl': null,
    'votes': 32,
  },
  {
    'id': '3', 
    'title': 'Garbage not collected',
    'description': 'The garbage has not been collected for over a week now. It\'s starting to smell and attract pests.',
    'latitude': 1.3644,
    'longitude': 103.9915,
    'reportedBy': 'resident789',
    'reportedAt': '2 days ago',
    'imageUrl': null,
    'votes': 8,
  },
  {
    'id': '4', 
    'title': 'Fallen tree blocking sidewalk',
    'description': 'A tree has fallen and is completely blocking the sidewalk. Pedestrians have to walk on the street which is dangerous.',
    'latitude': 1.3522,
    'longitude': 103.8765,
    'reportedBy': 'walker123',
    'reportedAt': '5 hours ago',
    'imageUrl': null,
    'votes': 27,
  },
  {
    'id': '5', 
    'title': 'Graffiti on public building',
    'description': 'Someone has vandalized the wall of the community center with inappropriate graffiti.',
    'latitude': 1.3101,
    'longitude': 103.8454,
    'reportedBy': 'civic_minded',
    'reportedAt': '1 week ago',
    'imageUrl': null,
    'votes': 12,
  },
];

class AppRouter {
  final AuthService authService;
  
  AppRouter(this.authService);
  
  late final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      
      // If not logged in and not on auth screen, redirect to auth
      if (!isLoggedIn && !isAuthRoute) return '/auth';
      
      // If logged in and on auth screen, redirect to home
      if (isLoggedIn && isAuthRoute) return '/';
      
      // No redirect needed
      return null;
    },
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/submit',
        builder: (context, state) {
          double? lat = state.extra != null 
              ? (state.extra as Map<String, dynamic>)['latitude'] as double? 
              : null;
          double? lng = state.extra != null 
              ? (state.extra as Map<String, dynamic>)['longitude'] as double? 
              : null;
          return SubmitComplaintScreen(latitude: lat, longitude: lng);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/complaint/:id',
        builder: (context, state) {
          // Get complaint ID from parameters
          final complaintId = state.pathParameters['id'] ?? '';
          
          // First check if we have complaint data passed as extra
          Map<String, dynamic>? complaintData = state.extra as Map<String, dynamic>?;
          
          // If not passed as extra, look up in the mock data
          if (complaintData == null) {
            complaintData = mockComplaints.firstWhere(
              (complaint) => complaint['id'] == complaintId,
              orElse: () => {
                'id': complaintId,
                'title': 'Unknown Complaint',
                'description': 'Details not available',
                'latitude': 0.0,
                'longitude': 0.0,
                'reportedBy': 'unknown',
                'reportedAt': 'unknown',
                'votes': 0,
              },
            );
          }
          
          // Return the complaint details screen with the data
          return ComplaintDetailsScreen(
            complaintId: complaintId,
            title: complaintData['title'] as String,
            description: complaintData['description'] as String? ?? 'No description available',
            latitude: complaintData['latitude'] as double? ?? 0.0,
            longitude: complaintData['longitude'] as double? ?? 0.0,
            reportedBy: complaintData['reportedBy'] as String? ?? 'Unknown user',
            reportedAt: complaintData['reportedAt'] as String? ?? 'Unknown time',
            initialVotes: complaintData['votes'] as int? ?? 0,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}

// A Listenable that notifies when the AuthState changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<User?> stream) {
    _subscription = stream.listen(
      (User? user) => notifyListeners(),
    );
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
