import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Add import for the new image viewer screen
import 'image_viewer_screen.dart';
import '../services/complaint_service.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String reportedBy;
  final String reportedAt;
  final int initialVotes;
  final String? imageUrl; // Could be a network URL or asset path

  const ComplaintDetailsScreen({
    super.key,
    required this.complaintId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.reportedBy,
    required this.reportedAt,
    this.initialVotes = 0,
    this.imageUrl,
  });

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  late int _voteCount;
  bool _upvoted = false;
  bool _downvoted = false;
  final ComplaintService _complaintService = ComplaintService();
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _voteCount = widget.initialVotes;
    // Load the user's current vote status
    _loadVoteStatus();
  }

  Future<void> _loadVoteStatus() async {
    try {
      final voteStatus = await _complaintService.getVoteStatus(widget.complaintId);
      setState(() {
        _voteCount = voteStatus['totalVotes'];
        _upvoted = voteStatus['userVote'] == 1;
        _downvoted = voteStatus['userVote'] == -1;
      });
    } catch (e) {
      // Handle error silently
      debugPrint('Error loading vote status: $e');
    }
  }

  // Mock data for comments
  final List<Map<String, dynamic>> _comments = [
    {
      'username': 'john_doe',
      'text': 'I saw this too! It needs to be fixed ASAP.',
      'timeAgo': '2h ago',
    },
    {
      'username': 'city_maintenance',
      'text': 'Thanks for reporting. We\'ve scheduled a team to look at this issue.',
      'timeAgo': '1h ago',
    },
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _comments.add({
        'username': 'current_user',
        'text': _commentController.text,
        'timeAgo': 'Just now',
      });
      _commentController.clear();
    });
  }

  Future<void> _handleUpvote() async {
    if (_isVoting) return;
    
    setState(() {
      _isVoting = true;
    });
    
    try {
      final result = await _complaintService.updateVote(widget.complaintId, true);
      
      setState(() {
        _voteCount = result['totalVotes'];
        _upvoted = result['newVote'] == 1;
        _downvoted = result['newVote'] == -1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating vote: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<void> _handleDownvote() async {
    if (_isVoting) return;
    
    setState(() {
      _isVoting = true;
    });
    
    try {
      final result = await _complaintService.updateVote(widget.complaintId, false);
      
      setState(() {
        _voteCount = result['totalVotes'];
        _upvoted = result['newVote'] == 1;
        _downvoted = result['newVote'] == -1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating vote: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  // Helper method to check if a string is a network URL - improved implementation
  bool _isNetworkImage(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('More options coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modified Complaint image with tap to zoom
                  GestureDetector(
                    onTap: () {
                      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageViewerScreen(
                              imageUrl: widget.imageUrl!,
                              isNetworkImage: _isNetworkImage(widget.imageUrl),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.grey[400],
                      child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                _isNetworkImage(widget.imageUrl)
                                    ? Image.network(
                                        widget.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint('Error loading image: $error');
                                          return const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 60,
                                                  color: Colors.white70,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Could not load image',
                                                  style: TextStyle(color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded / 
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        widget.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Error loading asset: $error');
                                          return const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 60,
                                                  color: Colors.white70,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Could not load image',
                                                  style: TextStyle(color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                // Overlay hint to indicate zoom capability
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),

                  // Complaint details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info and timestamp
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              child: Icon(Icons.person, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.reportedBy,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.reportedAt,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          widget.description,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),

                        // Location info
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Location: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Voting buttons
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                color: _upvoted ? Colors.green : Colors.grey[600],
                              ),
                              onPressed: _isVoting ? null : _handleUpvote,
                            ),
                            _isVoting 
                              ? SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey[600]!
                                    ),
                                  )
                                )
                              : Text(
                                  '$_voteCount',
                                  style: const TextStyle(fontSize: 16),
                                ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                color: _downvoted ? Colors.red : Colors.grey[600],
                              ),
                              onPressed: _isVoting ? null : _handleDownvote,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.mode_comment_outlined, color: Colors.grey[600]),
                              onPressed: () {
                                // Focus the comment field
                                FocusScope.of(context).requestFocus(FocusNode());
                                _commentController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _commentController.text.length),
                                );
                              },
                            ),
                            Text(
                              '${_comments.length}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                        const Divider(thickness: 1),

                        // Comments section title
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Comments list
                        ..._comments.map((comment) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                child: Icon(Icons.person, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          comment['username'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          comment['timeAgo'],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['text'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _addComment,
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
