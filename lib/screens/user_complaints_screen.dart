import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_card.dart';

class UserComplaintsScreen extends StatelessWidget {
  const UserComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ComplaintService complaintService = ComplaintService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: complaintService.getCurrentUserComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            );
          }
          
          final complaints = snapshot.data ?? [];
          
          if (complaints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'You haven\'t submitted any complaints yet',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/submit'),
                    icon: const Icon(Icons.add),
                    label: const Text('Submit a Complaint'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              
              return ComplaintCard(
                complaint: complaint,
                onTap: () {
                  context.push('/complaint/${complaint.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
