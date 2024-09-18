import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitRequestsPage extends StatefulWidget {
  @override
  _SplitRequestsPageState createState() => _SplitRequestsPageState();
}

class _SplitRequestsPageState extends State<SplitRequestsPage> {
  List<DocumentSnapshot> _receivedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final currentUsername = userSnapshot.data()?['username'];

        final receivedSnapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUsername)
            .get();

        setState(() {
          _receivedRequests = receivedSnapshot.docs;
          _isLoading = false;
        });
      } catch (e) {
        print('Failed to fetch split requests: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching split requests')));
      }
    }
  }

  Future<String?> _getUserNameById(String userId) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userSnapshot.data()?['username'];
    } catch (e) {
      print('Error fetching user name: $e');
      return null;
    }
  }

  Future<void> _approveRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final requestSnapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .doc(requestId)
            .get();

        // Check if the request document exists
        if (!requestSnapshot.exists) {
          print('Request not found');
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request not found')));
          return;
        }

        // Safely retrieve the amount from the request document
        final amount = requestSnapshot.data()?['amount'] as double?;
        if (amount == null) {
          print('Amount is null or invalid');
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid request data')));
          return;
        }

        // Update the status of the request
        await FirebaseFirestore.instance
            .collection('split_requests')
            .doc(requestId)
            .update({
          'status': 'approved',
        });


        setState(() {}); // Refresh the UI

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Split request approved')));
      } catch (e, stackTrace) {
        print('Failed to approve split request: $e');
        print(stackTrace); // Print the stack trace for debugging
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error approving split request')));
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('split_requests')
            .doc(requestId)
            .update({
          'status': 'rejected',
        });

        setState(() {}); // Refresh the UI

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Split request rejected')));
      } catch (e) {
        print('Failed to reject split request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting split request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Split Requests'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
          :_receivedRequests.isEmpty
          ? Center(child: Text('No split request receive', style: TextStyle(fontSize: 18, color: Colors.grey)))
          :  ListView.builder(
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          final fromUsername = _getUserNameById(request['from']);
          final amount = request['amount'].toStringAsFixed(2);
          final status = request['status'];

          return Card(
            child: ListTile(
              title: FutureBuilder<String?>(
                future: _getUserNameById(request['from']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text('Loading...'); // Display a loading indicator while the username is being fetched
                  } else if (snapshot.hasError) {
                    return Text('Error fetching name'); // Handle error
                  } else {
                    final fromUsername = snapshot.data ?? 'Unknown'; // Fallback in case the username is null
                    return Text('From: $fromUsername');
                  }
                },
              ),
              subtitle: Text('Amount: \$${amount}\nStatus: $status'),
              trailing: status == 'pending'
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveRequest(request.id),
                  ),
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.red),
                    onPressed: () => _rejectRequest(request.id),
                  ),
                ],
              )
                  : Text(
                status,
                style: TextStyle(
                  color: status == 'approved'
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
