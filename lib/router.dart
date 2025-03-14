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
import 'services/complaint_service.dart';
import 'models/complaint_model.dart';

class AppRouter {
  final AuthService authService;
  final ComplaintService complaintService = ComplaintService();
  
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
          
          // Check if we have complaint data passed as extra
          Map<String, dynamic>? complaintData = state.extra as Map<String, dynamic>?;
          
          if (complaintData != null) {
            // If we have data passed, use it directly
            return ComplaintDetailsScreen(
              complaintId: complaintId,
              title: complaintData['title'] as String,
              description: complaintData['description'] as String? ?? 'No description available',
              latitude: complaintData['latitude'] as double? ?? 0.0,
              longitude: complaintData['longitude'] as double? ?? 0.0,
              reportedBy: complaintData['reportedBy'] as String? ?? 'Unknown user',
              reportedAt: complaintData['reportedAt'] as String? ?? 'Unknown time',
              initialVotes: complaintData['votes'] as int? ?? 0,
              imageUrl: complaintData['imageUrl'] as String?,
            );
          } else {
            // If no data is passed, return a loading screen that fetches the complaint
            return FutureBuilder<ComplaintModel?>(
              future: complaintService.getComplaint(complaintId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                final complaint = snapshot.data;
                if (complaint == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Error')),
                    body: const Center(child: Text('Complaint not found')),
                  );
                }
                
                return ComplaintDetailsScreen(
                  complaintId: complaint.id ?? '',
                  title: complaint.title,
                  description: complaint.description,
                  latitude: complaint.latitude,
                  longitude: complaint.longitude,
                  reportedBy: complaint.userName,
                  reportedAt: complaint.timeAgo,
                  initialVotes: complaint.votes,
                  imageUrl: complaint.imageUrl,
                  tags: complaint.tags,
                );
              },
            );
          }
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
