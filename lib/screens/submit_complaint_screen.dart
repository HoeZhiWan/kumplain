import  'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';
import '../services/complaint_service.dart';
import '../services/google_generative_ai_service.dart';

class SubmitComplaintScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final XFile? initialImage;
  
  const SubmitComplaintScreen({
    super.key, 
    this.latitude, 
    this.longitude,
    this.initialImage,
  });

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _selectedImage;
  List<String> _selectedTags = [];
  bool _isSubmitting = false;
  final ComplaintService _complaintService = ComplaintService();
  late final List<String> _availableTags;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    _availableTags = await FirestoreService().getTags();
    setState(() {});
    if (widget.initialImage != null) {
      _processInitialImage(widget.initialImage!); // Process the initial image
    }
  }

  void _selectTags() async {
    final List<String>? selectedTags = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final List<String> tempSelectedTags = List.from(_selectedTags);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Tags'),
              content: SingleChildScrollView(
                child: Column(
                  children: _availableTags.map((tag) {
                    return CheckboxListTile(
                      title: Text(tag),
                      value: tempSelectedTags.contains(tag),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelectedTags.add(tag);
                          } else {
                            tempSelectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(tempSelectedTags),
                  child: const Text('OK'),
                ),
              ],
            );
          }
        );
      },
    );

    if (selectedTags != null) {
      setState(() {
        _selectedTags = selectedTags;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _processInitialImage(XFile image) async {
    setState(() {
      _selectedImage = image;
    });

    print("Initial image path: ${image.path}");

    try {
      final response = await GoogleGenerativeAIService().analyzeImage(image, _availableTags);
      final String? aiTitle = response['title'];
      final String? aiDescription = response['description'];
      final String? aiTag = response['tag'];

      print("AI Title: $aiTitle");
      print("AI Description: $aiDescription");

      if(aiTag != null) {
        if (aiTag == 'Spam') {
          // If the AI tag is "Spam", show a warning message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The image was classified as spam. Please review it.'),
              backgroundColor: Colors.orange,
            ),
          );

          return;
        } else if (!_availableTags.contains(aiTag)) {
            // Add the AI-generated tag to the selected tags
          setState(() {
            _selectedTags.add(aiTag); // Add AI-generated tag to selected tags
          });
        }
      }

      setState(() {
        _titleController.text = aiTitle ?? ''; // Set AI-generated tag as title
        _descriptionController.text = aiDescription ?? ''; // Set AI-generated description
      });

    } catch (e) {
      print("Error analyzing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitComplaint() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    // For now, let's make the image optional
    if (_selectedImage == null) {
      // Show a confirmation dialog instead of an error
      bool continueWithoutImage = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Image Selected'),
          content: const Text('Do you want to continue without an image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!continueWithoutImage) {
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String? imageUrl;
      String? aiTag;
      String? aiDescription;
      if(_selectedImage != null){
        // Analyze image using Google Generative AI
        final response = await GoogleGenerativeAIService().analyzeImage(_selectedImage!, _availableTags);
        aiTag = response['tag'];
        aiDescription = response['description'];

        print("AI Tag: $aiTag");
        print("AI Description: $aiDescription");

        //Upload image to Firebase Storage
        imageUrl = await FirebaseStorageService().uploadImage( _selectedImage!);

      } else{
        imageUrl = null;
      }

      // Submit to Firestore using the service
      final complaintId = await _complaintService.submitComplaint(
        title: _titleController.text,
        description: _descriptionController.text,
        latitude: widget.latitude ?? 0.0,
        longitude: widget.longitude ?? 0.0,
        imageUrl: imageUrl,
        tags: _selectedTags,
        aiTag: aiTag,
        aiDescription: aiDescription,
      );
      
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        // Navigate to the complaint details screen
        context.go('/complaint/$complaintId');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting complaint: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  //Select image from gallery
  Future<void> _selectImage(ImageSource source) async {
    final XFile? pickedImage = await ImagePicker().pickImage(source: source);
    if(pickedImage != null && mounted){
      setState(() {
        _selectedImage = pickedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Complaint'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.latitude != null && widget.longitude != null
                          ? 'Location: ${widget.latitude!.toStringAsFixed(4)}, ${widget.longitude!.toStringAsFixed(4)}'
                          : 'Location not specified',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                hintText: 'Enter complaint title',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            
            // Description input
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                hintText: 'Describe the problem...',
              ),
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            
            // Tags selection
            GestureDetector(
              onTap: _selectTags,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tags',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _selectedTags.isEmpty
                        ? const Text('No tags selected')
                        : Wrap(
                            spacing: 8,
                            children: _selectedTags.map((tag) {
                              return Chip(
                                label: Text(tag),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Image selection
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Selecting an image'),
                    content: const Text('Choose an image source:'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _selectImage(ImageSource.camera);
                        },
                        child: const Text('Camera'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _selectImage(ImageSource.gallery);
                        },
                        child: const Text('Gallery'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: (_selectedImage != null)
                    ? Center(
                        child: Image.file(File(_selectedImage!.path))
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('Tap to add photo'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Submit button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitComplaint,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'SUBMIT COMPLAINT',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
