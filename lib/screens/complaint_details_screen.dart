import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String reportedBy;
  final String reportedAt;
  final int initialVotes;

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
  });

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  late int _voteCount;
  bool _upvoted = false;
  bool _downvoted = false;

  @override
  void initState() {
    super.initState();
    _voteCount = widget.initialVotes;
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

  void _handleUpvote() {
    setState(() {
      if (_upvoted) {
        _upvoted = false;
        _voteCount--;
      } else {
        _upvoted = true;
        _voteCount++;
        if (_downvoted) {
          _downvoted = false;
          _voteCount++;
        }
      }
    });
  }

  void _handleDownvote() {
    setState(() {
      if (_downvoted) {
        _downvoted = false;
        _voteCount++;
      } else {
        _downvoted = true;
        _voteCount--;
        if (_upvoted) {
          _upvoted = false;
          _voteCount--;
        }
      }
    });
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
                  // Complaint image
                  Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey[400],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 100,
                        color: Colors.white,
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
                              onPressed: _handleUpvote,
                            ),
                            Text(
                              '$_voteCount',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                color: _downvoted ? Colors.red : Colors.grey[600],
                              ),
                              onPressed: _handleDownvote,
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
                                    RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(context).style,
                                        children: [
                                          TextSpan(
                                            text: comment['username'],
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const TextSpan(text: ' '),
                                          TextSpan(text: comment['text']),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['timeAgo'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
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
