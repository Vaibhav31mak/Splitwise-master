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
      // Fetch the user's friends
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

        // Fetch split requests where current user is "from"
        final fromRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .where('to', isEqualTo: friendUsername) // Use the username here
            .get();

        print('From requests for friendId $friendId: ${fromRequests.docs.length}');

        // Calculate total amount the friend owes to the user
        for (var request in fromRequests.docs) {
          netBalance += (request.data()['amount'] ?? 0.0);
        }

        // Fetch split requests where current user is "to" (using UID to username mapping)
        final toRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUser.displayName) // Use the current user's username
            .where('from', isEqualTo: friendId) // Use UID for 'from'
            .get();

        print('To requests for friendId $friendId: ${toRequests.docs.length}');

        // Calculate total amount the user owes to the friend
        for (var request in toRequests.docs) {
          netBalance -= (request.data()['amount'] ?? 0.0);
        }

        friendBalances.add({
          'friendId': friendId,
          'friendName': friendUsername,
          'netBalance': netBalance,
        });

        print('Net balance for friendId $friendId: $netBalance');
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
      print('Current User ID: ${currentUser.uid}');
      print('Attempting to delete requests for Friend ID: $friendId');

      // Deleting 'from' requests
      final fromRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: friendName) // Use the friend's username
          .get();

      print('From requests for friendId $friendId: ${fromRequests.docs.length}');

      for (var request in fromRequests.docs) {
        await request.reference.delete();
        print('Deleted request: ${request.id}');
      }

      // Deleting 'to' requests
      final toRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('to', isEqualTo: currentUser.displayName)
          .where('from', isEqualTo: friendId) // Use friendId (user ID)
          .get();

      print('To requests for friendId $friendId: ${toRequests.docs.length}');

      for (var request in toRequests.docs) {
        await request.reference.delete();
        print('Deleted request: ${request.id}');
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
