import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'image_viewer_screen.dart';
import '../services/complaint_service.dart';
import '../models/comment_model.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String reportedBy;
  final String reportedAt;
  final int initialVotes;
  final String? imageUrl; 
  final List<String>? tags; 
  final String? status; 
  final String? userPhotoURL; 

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
    this.tags = const [], 
    this.status, 
    this.userPhotoURL, 
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
  bool _isOwner = false;
  bool _isSubmittingComment = false;
  Stream<List<CommentModel>>? _commentsStream;
  int _commentCount = 0;
  bool _isDeleted = false; // Add this variable to track deleted status

  @override
  void initState() {
    super.initState();
    _voteCount = widget.initialVotes;
    _loadVoteStatus();
    _checkOwnership();
    _loadComments();
    _loadCommentCount();
    // Check if complaint is deleted based on status
    _isDeleted = _checkIfDeleted(widget.status);
  }

  // Add helper method to check if complaint is deleted
  bool _checkIfDeleted(String? status) {
    return status != null && status.startsWith('deleted');
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

  Future<void> _checkOwnership() async {
    bool isOwner = await _complaintService.isComplaintOwner(widget.complaintId);
    if (mounted) {
      setState(() {
        _isOwner = isOwner;
      });
    }
  }

  void _loadComments() {
    setState(() {
      _commentsStream = _complaintService.getComments(widget.complaintId);
    });
  }
  
  Future<void> _loadCommentCount() async {
    try {
      final count = await _complaintService.getCommentCount(widget.complaintId);
      if (mounted) {
        setState(() {
          _commentCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading comment count: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() {
      _isSubmittingComment = true;
    });

    try {
      // Add comment to Firestore
      await _complaintService.addComment(widget.complaintId, _commentController.text.trim());
      
      // Clear the input field
      _commentController.clear();
      
      // Update comment count
      _loadCommentCount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _handleUpvote() async {
    // Don't allow voting if complaint is deleted or voting is in progress
    if (_isVoting || _isDeleted) return;
    
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
    // Don't allow voting if complaint is deleted or voting is in progress
    if (_isVoting || _isDeleted) return;
    
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

  Widget _displayTags(){
    if (widget.tags == null || widget.tags!.isEmpty) return const SizedBox(height: 12);
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: widget.tags!.map((tag) => Chip(
        padding: const EdgeInsets.all(1),
        label: Text(tag),
        labelStyle: const TextStyle(fontSize: 12),
        backgroundColor: Colors.blue[100],
      )).toList(),
    );
  }

  Future<void> _handleDelete() async {
    try {
      await _complaintService.markComplaintAsDeleted(widget.complaintId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint marked as deleted')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDeleteComment(String commentId) async {
    try {
      await _complaintService.deleteComment(commentId, widget.complaintId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
        // Update comment count after deletion
        _loadCommentCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: ${e.toString()}')),
        );
      }
    }
  }

  // Method to determine status display properties
  Map<String, dynamic> _getStatusDisplay() {
    // Default values
    String displayStatus = widget.status ?? 'pending';
    Color statusColor = Colors.red;
    
    // Check for deleted status first
    if (displayStatus.startsWith('deleted')) {
      displayStatus = 'deleted';
      statusColor = Colors.grey;
    } else if (displayStatus == 'resolved') {
      statusColor = Colors.green;
    } else if (displayStatus == 'processing') {
      statusColor = Colors.amber;
    }
    
    return {
      'text': displayStatus,
      'color': statusColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusDisplay = _getStatusDisplay();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          // Show more options menu
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Complaint'),
                      content: const Text('Are you sure you want to delete this complaint?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _handleDelete();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            )
          else
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
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: widget.userPhotoURL != null 
                                  ? NetworkImage(widget.userPhotoURL!) 
                                  : null,
                              child: widget.userPhotoURL == null
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
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

                        // Display tags - moved here below description
                        _displayTags(),
                        
                        const SizedBox(height: 16),

                        // Voting buttons - modify to show disabled state when deleted
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                color: _isDeleted 
                                    ? Colors.grey[400] 
                                    : (_upvoted ? Colors.green : Colors.grey[600]),
                              ),
                              onPressed: _isVoting || _isDeleted ? null : _handleUpvote,
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _isDeleted ? Colors.grey[400] : Colors.black,
                                  ),
                                ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                color: _isDeleted 
                                    ? Colors.grey[400] 
                                    : (_downvoted ? Colors.red : Colors.grey[600]),
                              ),
                              onPressed: _isVoting || _isDeleted ? null : _handleDownvote,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusDisplay['color'].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusDisplay['text'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusDisplay['color'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.mode_comment_outlined, 
                                  color: _isDeleted ? Colors.grey[400] : Colors.grey[600]),
                              onPressed: _isDeleted ? null : () {
                                // Focus the comment field
                                FocusScope.of(context).requestFocus(FocusNode());
                                _commentController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _commentController.text.length),
                                );
                              },
                            ),
                            Text(
                              '$_commentCount',
                              style: TextStyle(
                                color: _isDeleted ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                        const Divider(thickness: 1),

                        // Comments section title with location info only (status removed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text(
                                'Comments',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              // Location info
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Comments list with stream builder
                        StreamBuilder<List<CommentModel>>(
                          stream: _commentsStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Error loading comments: ${snapshot.error}'),
                              );
                            }
                            
                            final comments = snapshot.data ?? [];
                            
                            if (comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No comments yet. Be the first to comment!'),
                              );
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: comments.map((comment) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage: comment.userPhotoURL != null
                                          ? NetworkImage(comment.userPhotoURL!)
                                          : null,
                                        child: comment.userPhotoURL == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
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
                                                  comment.userName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  comment.timeAgo,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                // Show delete button only for user's own comments
                                                if (comment.userId == _complaintService.currentUser?.uid)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 16),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    color: Colors.grey[600],
                                                    onPressed: () {
                                                      // Confirmation dialog
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text('Delete Comment'),
                                                          content: const Text('Are you sure you want to delete this comment?'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.of(context).pop(),
                                                              child: const Text('Cancel'),
                                                            ),
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.of(context).pop();
                                                                if (comment.id != null) {
                                                                  _handleDeleteComment(comment.id!);
                                                                }
                                                              },
                                                              child: const Text('Delete'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment.text,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            );
                          },
                        ),
                        
                        // Add some padding at the bottom of the scrollable area
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input field - show disabled version if complaint is deleted
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isDeleted ? Colors.grey[100] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: _isDeleted 
              // Show disabled message when complaint is deleted
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.comment_outlined, color: Colors.grey, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comments are disabled for deleted complaints',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                )
              // Show normal comment input when complaint is not deleted
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: _complaintService.currentUser?.photoURL != null
                        ? NetworkImage(_complaintService.currentUser!.photoURL!)
                        : null,
                      child: _complaintService.currentUser?.photoURL == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
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
                    _isSubmittingComment 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
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
