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

        // Fetch split requests where current user is "from"
        final fromRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .where('to', isEqualTo: friendId)
            .get();

        // Calculate total amount the friend owes to the user
        for (var request in fromRequests.docs) {
          netBalance += (request.data()['amount'] ?? 0.0);
        }

        // Fetch split requests where current user is "to"
        final toRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUser.uid)
            .where('from', isEqualTo: friendId)
            .get();

        // Calculate total amount the user owes to the friend
        for (var request in toRequests.docs) {
          netBalance -= (request.data()['amount'] ?? 0.0);
        }

        // Fetch friend's username
        final friendSnapshot = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
        final friendName = friendSnapshot.data()?['username'] ?? 'Unknown';

        friendBalances.add({
          'friendId': friendId,
          'friendName': friendName,
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

  Future<void> _cancelExpenses(String friendId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Delete all split requests where current user is either 'from' or 'to'
      final fromRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: friendId)
          .get();

      for (var request in fromRequests.docs) {
        await request.reference.delete();
      }

      final toRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('to', isEqualTo: currentUser.uid)
          .where('from', isEqualTo: friendId)
          .get();

      for (var request in toRequests.docs) {
        await request.reference.delete();
      }

      // Refresh the balances
      _fetchFriendsAndBalances();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expenses settled with $friendId')));
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
                          onPressed: () => _cancelExpenses(friendBalance['friendId']),
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
