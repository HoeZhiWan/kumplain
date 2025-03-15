import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/complaint_service.dart';
import '../models/user_model.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ComplaintService _complaintService = ComplaintService();
  
  bool _isLoading = true;
  bool _isLoadingProfile = true;
  int _submittedComplaints = 0;
  int _activeComplaints = 0;
  int _resolvedComplaints = 0;
  UserModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // Load both stats and user profile data
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _isLoadingProfile = true;
    });
    
    // Load data in parallel
    await Future.wait([
      _loadUserStats(),
      _loadUserProfile(),
    ]);
  }
  
  // Load complaint statistics
  Future<void> _loadUserStats() async {
    try {
      final stats = await _complaintService.getDetailedUserStats();
      if (mounted) {
        setState(() {
          _submittedComplaints = stats['submitted'] ?? 0;
          _activeComplaints = stats['active'] ?? 0;
          _resolvedComplaints = stats['resolved'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user stats: ${e.toString()}')),
        );
      }
    }
  }
  
  // Load user profile from Firestore
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
      }
    }
  }
  
  // Navigate to profile edit screen
  Future<void> _navigateToEditProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    // Prioritize Firestore profile data if available
    final displayName = _userProfile?.displayName ?? user.displayName ?? 'User';
    final photoURL = _userProfile?.photoURL ?? user.photoURL;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(
          initialDisplayName: displayName,
          initialPhotoURL: photoURL,
        ),
      ),
    );
    
    // Reload profile data if changes were made
    if (result == true) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    
    // Prioritize Firestore profile data if available (UI Display Strategy)
    final displayName = _userProfile?.displayName ?? user?.displayName ?? 'User';
    final email = _userProfile?.email ?? user?.email ?? 'No email';
    final photoURL = _userProfile?.photoURL ?? user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Edit profile button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEditProfile,
            tooltip: 'Edit profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User info header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Center(
                child: Column(
                  children: [
                    // User avatar with loading indicator if needed
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: photoURL != null
                              ? NetworkImage(photoURL)
                              : null,
                          child: photoURL == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        if (_isLoadingProfile)
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // User name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // User email
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Last updated info if available
                    if (_userProfile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Last updated: ${_formatDate(_userProfile!.lastUpdated)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Stats section
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildStats(context),
            ),

            // Account settings
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('My Complaints'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/my-complaints');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings not implemented yet')),
                );
              },
            ),

            const Divider(),

            // Sign out button
            ListTile(
              leading: const Icon(
                Icons.exit_to_app,
                color: Colors.red,
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                await _authService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Submitted',
            _submittedComplaints.toString(),
            Icons.send,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            'Active',
            _activeComplaints.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
