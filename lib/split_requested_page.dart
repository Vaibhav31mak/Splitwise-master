// split_requested_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitRequestedPage extends StatefulWidget {
  @override
  _SplitRequestedPageState createState() => _SplitRequestedPageState();
}

class _SplitRequestedPageState extends State<SplitRequestedPage> {
  List<DocumentSnapshot<Object?>> _sentRequests = [];
  bool _isLoading=true;
  @override
  void initState() {
    super.initState();
    _fetchSentRequests();
  }

  Future<void> _fetchSentRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .get();

        setState(() {
          _sentRequests = snapshot.docs;
          _isLoading=false;
        });
      } catch (e) {
        print('Failed to fetch split requests: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching split requests')));
      }
    }
  }

  // Future<void> _cancelRequest(String requestId) async {
  //   try {
  //     // Delete the request from Firestore
  //     await FirebaseFirestore.instance.collection('split_requests').doc(requestId).delete();

  //     setState(() {
  //       // Remove the request from the list displayed in the UI
  //       _sentRequests.removeWhere((doc) => doc.id == requestId);
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Split request cancelled')));
  //   } catch (e) {
  //     print('Failed to cancel split request: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to cancel request')));
  //   }
  // }
  Future<void> _cancelRequest(String requestId) async {
  try {
    // Update the request status to 'cancelled' instead of deleting the document
    await FirebaseFirestore.instance
        .collection('split_requests')
        .doc(requestId)
        .update({'status': 'cancelled'});

    setState(() {
      // Optionally, you can remove the request from the UI if needed, or just update the UI accordingly
      _sentRequests.removeWhere((doc) => doc.id == requestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Split request status updated to cancelled')));
  } catch (e) {
    print('Failed to update split request: $e');
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request')));
  }
}



  Future<void> _denyRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance.collection('split_requests').doc(requestId).update({
          'status': 'pending',
        });
        setState(() {
          _fetchSentRequests();
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Split request denied')));
      } catch (e) {
        print('Failed to deny split request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to deny request')));
      }
    }
  }

  @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('Split Requests'),
  //       backgroundColor: Colors.teal,
  //     ),
  //     body:  _isLoading
  //         ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
  //         :_sentRequests.isEmpty
  //         ? Center(child: Text('No split request sent', style: TextStyle(fontSize: 18, color: Colors.grey)))
  //         : ListView.builder(
  //       itemCount: _sentRequests.length,
  //       itemBuilder: (context, index) {
  //         final request = _sentRequests[index];
  //         final requestId = request.id;
  //         final requestData = request.data() as Map<String, dynamic>;

  //         return Card(
  //           margin: EdgeInsets.all(8.0),
  //           elevation: 5,
  //           child: ListTile(
  //             title: Text('Request ID: $requestId'),
  //             subtitle: Text('To: ${requestData['to']} \nAmount: ${requestData['amount']}'),
  //             trailing: Row(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 if (requestData?['status'] == 'approved')
  //                   ElevatedButton(
  //                     onPressed: () => _denyRequest(requestId),
  //                     child: Text('Deny'),
  //                   ),
  //                 SizedBox(width: 8),
  //                 ElevatedButton(
  //                   onPressed: () => _cancelRequest(requestId),
  //                   child: Text('Cancel'),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }
  Widget build(BuildContext context) {
  // Filter out requests with status 'cancelled'
  final activeRequests = _sentRequests.where((request) {
    final requestData = request.data() as Map<String, dynamic>;
    return requestData['status'] != 'cancelled'; // Only include non-cancelled requests
  }).toList();

  return Scaffold(
    appBar: AppBar(
      title: Text('Split Requests'),
      backgroundColor: Colors.teal,
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
        : activeRequests.isEmpty
            ? Center(child: Text('No active split requests', style: TextStyle(fontSize: 18, color: Colors.grey)))
            : ListView.builder(
                itemCount: activeRequests.length,
                itemBuilder: (context, index) {
                  final request = activeRequests[index];
                  final requestId = request.id;
                  final requestData = request.data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.all(8.0),
                    elevation: 5,
                    child: ListTile(
                      title: Text('Request ID: $requestId'),
                      subtitle: Text('To: ${requestData['to']} \nAmount: ${requestData['amount']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (requestData['status'] == 'approved')
                            ElevatedButton(
                              onPressed: () => _denyRequest(requestId),
                              child: Text('Deny'),
                            ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _cancelRequest(requestId),
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
  );
}

}
