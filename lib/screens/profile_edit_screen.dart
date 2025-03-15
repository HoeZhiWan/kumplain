import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firebase_storage_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final String initialDisplayName;
  final String? initialPhotoURL;

  const ProfileEditScreen({
    super.key,
    required this.initialDisplayName,
    this.initialPhotoURL,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  String? _currentPhotoURL;
  File? _newImageFile;
  bool _isLoading = false;
  bool _hasChanges = false;
  final AuthService _authService = AuthService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.initialDisplayName);
    _currentPhotoURL = widget.initialPhotoURL;

    // Listen for changes to track if form is dirty
    _displayNameController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_checkForChanges);
    _displayNameController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final hasTextChanges = _displayNameController.text != widget.initialDisplayName;
    final hasImageChanges = _newImageFile != null;
    
    if (mounted) {
      setState(() {
        _hasChanges = hasTextChanges || hasImageChanges;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (pickedImage != null) {
        setState(() {
          _newImageFile = File(pickedImage.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;
    
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? newPhotoURL;
      
      // If user selected a new profile photo, upload it
      if (_newImageFile != null) {
        newPhotoURL = await _storageService.uploadImage(
          XFile(_newImageFile!.path),
        );
      }
      
      // Update user profile with new display name and/or photo URL
      await _authService.updateUserProfile(
        displayName: _displayNameController.text.trim(),
        photoURL: newPhotoURL ?? _currentPhotoURL, // Keep current URL if no new image
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog if there are unsaved changes
        if (_hasChanges) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldDiscard ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                onPressed: _isLoading ? null : _saveProfile,
                tooltip: 'Save',
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile image
              Center(
                child: Stack(
                  children: [
                    // Profile image
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _newImageFile != null
                          ? FileImage(_newImageFile!)
                          : (_currentPhotoURL != null
                              ? NetworkImage(_currentPhotoURL!) as ImageProvider
                              : null),
                      child: (_newImageFile == null && _currentPhotoURL == null)
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    // Edit icon
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: InkWell(
                          onTap: _pickImage,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Display name field
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Display name explanation
              const Text(
                'Your display name will be shown to other users when you submit complaints or leave comments.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
