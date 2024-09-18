import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillSplitScreen extends StatefulWidget {
  @override
  _BillSplitScreenState createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  List<String> _friends = [];
  List<String> _selectedFriends = [];
  Map<String, TextEditingController> _amountControllers = {};
  double _totalBill = 0.0;
  Map<String, double> _balances = {};
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId)
            .get();

        final List<String> friendIds = List<String>.from((userSnapshot.data() as Map<String, dynamic>)['friends'] ?? []);

        final List<String> friendNames = [];

        for (final friendId in friendIds) {
          final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
          friendNames.add(friendDoc.data()?['username'] ?? 'No Username');
        }

        setState(() {
          _friends = friendNames;
          _isLoading = false;
        });
      } catch (e) {
        print('Failed to fetch friends: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching friends')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bill Splitter'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderText('Total Bill Amount'),
              TextField(
                decoration: _inputDecoration('Enter total bill'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _totalBill = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
              SizedBox(height: 20),
              _buildHeaderText('Select Friends to Split'),
              SizedBox(height: 10),
              _isLoading
                  ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
                  : _friends.isNotEmpty
                  ? Column(
                children: _friends.map((friend) {
                  bool isSelected = _selectedFriends.contains(friend);
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: Text(friend, style: TextStyle(fontSize: 16)),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedFriends.add(friend);
                                  _amountControllers[friend] = TextEditingController();
                                } else {
                                  _selectedFriends.remove(friend);
                                  _amountControllers.remove(friend)?.dispose();
                                }
                              });
                            },
                          ),
                          if (isSelected)
                            TextField(
                              controller: _amountControllers[friend],
                              decoration: _inputDecoration('Amount owed for $friend'),
                              keyboardType: TextInputType.number,
                            ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
                  : Center(child: Text('No friends found', style: TextStyle(fontSize: 18, color: Colors.grey))), // Show this if no friends found
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _selectedFriends.isEmpty ? null : _splitBill,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  child: Text('Split Bill'),
                ),
              ),
              SizedBox(height: 20),
              if (_balances.isNotEmpty) _buildBalancesView(),
            ],
          ),
        ),
      ),
    );
  }
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }

  Widget _buildHeaderText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  void _splitBill() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _selectedFriends.isNotEmpty) {
      double totalOwed = 0.0;
      Map<String, double> amountsOwed = {};
      List<String> friendsWithoutAmount = [];
      double remainingAmount = _totalBill;

      for (String friend in _selectedFriends) {
        String? amountText = _amountControllers[friend]?.text;
        double amountOwed = double.tryParse(amountText ?? '') ?? 0.0;

        if (amountText != null && amountText.isNotEmpty) {
          amountsOwed[friend] = amountOwed;
          totalOwed += amountOwed;
          remainingAmount -= amountOwed;
        } else {
          friendsWithoutAmount.add(friend);
        }
      }

      if (friendsWithoutAmount.isNotEmpty) {
        double splitAmount = remainingAmount / friendsWithoutAmount.length;

        for (String friend in amountsOwed.keys) {
          try {
            await FirebaseFirestore.instance.collection('split_requests').add({
              'from': currentUser.uid,
              'to': friend,
              'amount': amountsOwed[friend]!,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp(),
              'description': 'Bill Split',
            });
          } catch (e) {
            print('Failed to send split request: $e');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send split request')));
          }
        }

        for (String friend in friendsWithoutAmount) {
          try {
            await FirebaseFirestore.instance.collection('split_requests').add({
              'from': currentUser.uid,
              'to': friend,
              'amount': splitAmount,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp(),
              'description': 'Bill Split',
            });
          } catch (e) {
            print('Failed to send split request: $e');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send split request')));
          }
        }
      }

      Map<String, double> balances = {};
      for (String friend in _selectedFriends) {
        double amountOwed = amountsOwed[friend] ?? (remainingAmount / friendsWithoutAmount.length);
        balances[friend] = amountOwed;
      }

      setState(() {
        _balances = balances;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Split requests sent')));
    }
  }

  Widget _buildBalancesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _balances.entries.map((entry) {
        String name = entry.key;
        double balance = entry.value;
        String balanceText = balance > 0
            ? '$name should receive \$${balance.abs().toStringAsFixed(2)}'
            : '$name owes \$${balance.abs().toStringAsFixed(2)}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            balanceText,
            style: TextStyle(fontSize: 16, color: balance > 0 ? Colors.green : Colors.red),
          ),
        );
      }).toList(),
    );
  }
}
