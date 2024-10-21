import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettleUpPage extends StatefulWidget {
  @override
  _SettleUpPageState createState() => _SettleUpPageState();
}

class _SettleUpPageState extends State<SettleUpPage> {
  List<Map<String, dynamic>> _friendBalances = [];
  Map<String, TextEditingController> _amountControllers = {};

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

      // Fetch the user's friends
      final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .doc(currentUser.uid)
          .get();
      final List<String> friendIds = List<String>.from((userSnapshot.data() as Map<String, dynamic>)['friends'] ?? []);

      List<Map<String, dynamic>> friendBalances = [];

      for (final friendId in friendIds) {
        double netBalance = 0.0;

        // Fetch the friend's username
        final friendSnapshot = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
        final friendUsername = friendSnapshot.data()?['username'] ?? 'Unknown';

        // Fetch outgoing requests (current user owes the friend)
        final splitRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .where('to', isEqualTo: friendUsername)
            .get();

        for (var request in splitRequests.docs) {
          if (request.data()['status'] != 'cancelled') {
            netBalance += (request.data()['amount'] ?? 0.0);
          }
        }

        // Fetch incoming requests (friend owes the current user)
        final incomingRequests = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUsername)
            .where('from', isEqualTo: friendId)
            .get();

        for (var request in incomingRequests.docs) {
          if (request.data()['status'] != 'cancelled') {
            netBalance -= (request.data()['amount'] ?? 0.0);
          }
        }

        friendBalances.add({
          'friendId': friendId,
          'friendName': friendUsername,
          'netBalance': netBalance,
        });

        // Create a TextEditingController for each friend who owes the user
        if (netBalance > 0) {
          _amountControllers[friendId] = TextEditingController();
        }
      }

      setState(() {
        _friendBalances = friendBalances;
      });
    } catch (e) {
      print('Error fetching friends or balances: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching balances')));
    }
  }

  Future<void> _settlePartialExpense(String friendId, String friendName, double amount) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  try {
    final friendBalance = _friendBalances.firstWhere(
        (balance) => balance['friendName'] == friendName,
        orElse: () => <String, dynamic>{}, // Return an empty map instead of null
      );

      // Check if the friendBalance map is empty
      if (friendBalance.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend not found in balance list')));
        return;
      }

      double netBalance = friendBalance['netBalance'] ?? 0.0; // Ensure netBalance has a default value

      // Check if the amount entered is valid
      if (amount <= 0 || amount > netBalance) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter a valid amount')));
        return;
      }

      // Delete existing requests
      await _deleteExpenses(friendName);

    // Calculate remaining balance after the partial settlement
    double remainingAmount = netBalance - amount;

    // If there's a remaining balance, add a new split request
    if (remainingAmount > 0) {
      await _addSplitRequest(currentUser.uid, friendName, remainingAmount, 'pending', 'Partially settled');
    }

    // Refresh the balances
    _fetchFriendsAndBalances();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settled partially with $friendName')));
  } catch (e) {
    print('Error settling partial expense: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error settling expense')));
  }
}

// Function to delete existing split requests for the friend
  Future<void> _deleteExpenses(String friendName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final requests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: friendName)
          .get();

      for (var request in requests.docs) {
        await request.reference.delete(); // Delete the request
      }
    } catch (e) {
      print('Error deleting expenses: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting expenses')));
    }
  }
// Function to add a new split request
Future<void> _addSplitRequest(String fromId, String toName, double amount, String status, String description) async {
  try {
    await FirebaseFirestore.instance.collection('split_requests').add({
      'from': fromId,
      'to': toName,
      'amount': amount,
      'status': status,
      'description': description,
    });
  } catch (e) {
    print('Error adding new split request: $e');
  }
}


  Future<void> _cancelExpenses(String friendId, String friendName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Fetch the user's username
      final currentUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUsername = currentUserSnapshot.data()?['username'] ?? 'Unknown';

      // Cancel outgoing requests (current user owes the friend)
      final fromRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: friendName)
          .get();

      for (var request in fromRequests.docs) {
        await request.reference.update({'status': 'cancelled'});
      }

      // Cancel incoming requests (friend owes the current user)
      final toRequests = await FirebaseFirestore.instance
          .collection('split_requests')
          .where('to', isEqualTo: currentUsername)
          .where('from', isEqualTo: friendId)
          .get();

      for (var request in toRequests.docs) {
        await request.reference.update({'status': 'cancelled'});
      }
    } catch (e) {
      print('Error canceling expenses: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error settling expenses')));
    }
  }

  @override
  void dispose() {
    // Dispose of all controllers to free up resources
    _amountControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
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

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friendName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(netBalance > 0
                            ? 'Owes you: \$${netBalance.toStringAsFixed(2)}'
                            : 'You owe: \$${netBalance.abs().toStringAsFixed(2)}'),
                        if (netBalance > 0) ...[
                          TextField(
                            controller: _amountControllers[friendBalance['friendId']],
                            decoration: InputDecoration(labelText: 'Enter amount to settle'),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              double? amount = double.tryParse(_amountControllers[friendBalance['friendId']]?.text ?? '');
                              if (amount != null && amount > 0 && amount <= netBalance) {
                                _settlePartialExpense(friendBalance['friendId'], friendName, amount);
                                _amountControllers[friendBalance['friendId']]?.clear(); // Clear input after submission
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter a valid amount')));
                              }
                            },
                            child: Text('Settle'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
