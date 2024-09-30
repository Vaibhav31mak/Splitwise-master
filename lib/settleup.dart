import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettleUpPage extends StatefulWidget {
  @override
  _SettleUpPageState createState() => _SettleUpPageState();
}

class _SettleUpPageState extends State<SettleUpPage> {
  List<Map<String, dynamic>> _friendBalances = [];

  @override
  void initState() {
    super.initState();
    _fetchFriendsAndBalances();
  }

  Future<void> _fetchFriendsAndBalances() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Fetch the user's username
      final currentUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUsername = currentUserSnapshot.data()?['username'] ?? 'Unknown';

      // Fetch the user's friends (by their UID)
      final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .doc(currentUser.uid)
          .get();
      final List<String> friendIds = List<String>.from((userSnapshot.data() as Map<String, dynamic>)['friends'] ?? []);

      List<Map<String, dynamic>> friendBalances = [];

      // For each friend, calculate the net balance
      for (final friendId in friendIds) {
        double netBalance = 0.0;

        // Fetch the friend's username
        final friendSnapshot = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
        final friendUsername = friendSnapshot.data()?['username'] ?? 'Unknown';

        // Fetch all split requests involving the current user and the friend
        final splitRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .where('to', isEqualTo: friendUsername) // Use friend's username for 'to'
            .get();

        // Calculate total amount the friend owes to the user
        for (var request in splitRequests.docs) {
          if (request.data()['status'] != 'cancelled') { // Filter out cancelled requests in code
            netBalance += (request.data()['amount'] ?? 0.0);
          }
        }

        // Fetch requests where the friend owes the current user
        final incomingRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUsername) // Use current user's username for 'to'
            .where('from', isEqualTo: friendId) // Use friend's UID for 'from'
            .get();

        // Calculate total amount the user owes to the friend
        for (var request in incomingRequests.docs) {
          if (request.data()['status'] != 'cancelled') { // Filter out cancelled requests in code
            netBalance -= (request.data()['amount'] ?? 0.0);
          }
        }

        // Add friend balance to the list
        friendBalances.add({
          'friendId': friendId,
          'friendName': friendUsername,
          'netBalance': netBalance,
        });
      }

      setState(() {
        _friendBalances = friendBalances;
      });
    } catch (e) {
      print('Error fetching friends or balances: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching balances')));
    }
  }

  Future<void> _cancelExpenses(String friendId, String friendName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Update the status of requests instead of deleting them
      final currentUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUsername = currentUserSnapshot.data()?['username'] ?? 'Unknown';

      // Updating 'from' requests (current user owes the friend)
      final fromRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: friendName) // Use friend's username for 'to'
          .get();

      for (var request in fromRequests.docs) {
        await request.reference.update({'status': 'cancelled'});
      }

      // Updating 'to' requests (friend owes the current user)
      final toRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('to', isEqualTo: currentUsername) // Use current user's username for 'to'
          .where('from', isEqualTo: friendId) // Use friend's UID for 'from'
          .get();

      for (var request in toRequests.docs) {
        await request.reference.update({'status': 'cancelled'});
      }

      // Refresh the balances
      setState(() {
        _friendBalances.removeWhere((balance) => balance['friendId'] == friendId);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expenses settled with $friendName')));
    } catch (e) {
      print('Error canceling expenses: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error settling expenses')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settle Up'),
      ),
      body: _friendBalances.isNotEmpty
          ? ListView.builder(
              itemCount: _friendBalances.length,
              itemBuilder: (context, index) {
                final friendBalance = _friendBalances[index];
                final netBalance = friendBalance['netBalance'];
                final friendName = friendBalance['friendName'];

                return ListTile(
                  title: Text(friendName),
                  subtitle: Text(netBalance > 0
                      ? 'Owes you: \$${netBalance.toStringAsFixed(2)}'
                      : 'You owe: \$${netBalance.abs().toStringAsFixed(2)}'),
                  trailing: netBalance > 0
                      ? ElevatedButton(
                          onPressed: () => _cancelExpenses(friendBalance['friendId'], friendName),
                          child: Text('Cancel'),
                        )
                      : null,
                );
              },
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
