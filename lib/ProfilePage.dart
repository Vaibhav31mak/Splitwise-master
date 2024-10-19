import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = 'User';
  String _email = '';
  double _totalExpenses = 0.0;
  double _averageExpenses = 0.0;
  List<double> _monthlyExpenses = List.filled(
      12, 0.0); // Initialize list for 12 months
  String _selectedYear = DateTime
      .now()
      .year
      .toString(); // Default selected year

  // New variables for friends' expense analysis
  List<String> _friendNames = [];
  List<double> _pendingExpenses = [];
  List<double> _cancelledExpenses = [];

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _fetchExpenseAnalysis(); // Fetch default year data
    _fetchFriendsExpenseAnalysis(); // Fetch friends' expense data
  }

  Future<void> _fetchUserDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      setState(() {
        _userName = userSnapshot['username'] ?? 'User';
        _email = currentUser.email ?? 'No email found';
      });
    }
  }

  Future<void> _fetchExpenseAnalysis() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String username = userSnapshot['username'] ?? '';
      DateTime startOfYear = DateTime(int.parse(_selectedYear), 1, 1);
      DateTime endOfYear = DateTime(
          int.parse(_selectedYear), 12, 31, 23, 59, 59);

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: username)
            .where('status', isEqualTo: 'approved')
            .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where(
            'timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
            .orderBy('timestamp')
            .get();

        double totalExpenses = 0.0;
        List<double> monthlyExpenses = List.filled(12, 0.0);

        for (var doc in snapshot.docs) {
          Timestamp timestamp = doc['timestamp'];
          DateTime date = timestamp.toDate();
          int month = date.month;
          double expenses = (doc['amount'] as num).toDouble();
          monthlyExpenses[month - 1] += expenses;
          totalExpenses += expenses;
        }

        setState(() {
          _totalExpenses = totalExpenses;
          _averageExpenses = totalExpenses / 12;
          _monthlyExpenses = monthlyExpenses;
        });
      } catch (e) {
        print("Error fetching expenses: $e");
      }
    }
  }

  Future<void> _fetchFriendsExpenseAnalysis() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        String username = userSnapshot['username'] ?? '';

        // Fetching the current user's friends from the friends collection
        final friendsDocSnapshot = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUser.uid) // Accessing the document for the current user
            .get();

        if (!friendsDocSnapshot.exists) {
          print('No friends found for the current user.');
          return; // Exit if no friends document exists
        }

        List<String> friendNames = [];
        List<double> pendingExpenses = [];
        List<double> cancelledExpenses = [];

        // Assuming the friends are stored as a list in the document
        List<dynamic> friendsList = friendsDocSnapshot.data()?['friends'] ?? [];

        print('Number of friends: ${friendsList.length}');

        for (var friendId in friendsList) {
          // Get friend's name from the users table
          final friendSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();

          if (friendSnapshot.exists) {
            String friendName = friendSnapshot['username'] ?? 'Unknown';
            print('name: $friendName id: $friendId');
            // Calculate pending and cancelled expenses for each friend
            final splitRequestsSnapshot = await FirebaseFirestore.instance
                .collection('split_requests')
                .where('from', isEqualTo: currentUser.uid)
                .where('to', isEqualTo: friendName)
                .get();

            double pendingAmount = 0.0;
            double cancelledAmount = 0.0;

            for (var splitDoc in splitRequestsSnapshot.docs) {
              double amount = (splitDoc['amount'] as num).toDouble();
              String status = splitDoc['status'];

              if (status == 'pending') {
                pendingAmount += amount;
              } else if (status == 'cancelled') {
                cancelledAmount += amount;
              }
            }

            friendNames.add(friendName);
            pendingExpenses.add(pendingAmount);
            cancelledExpenses.add(cancelledAmount);
          } else {
            print('Friend not found for ID: $friendId');
          }
        }

        print('Friend Names: $friendNames');
        print('Pending Expenses: $pendingExpenses');
        print('Cancelled Expenses: $cancelledExpenses');

        setState(() {
          _friendNames = friendNames;
          _pendingExpenses = pendingExpenses;
          _cancelledExpenses = cancelledExpenses;
        });
      } catch (e) {
        print("Error fetching friends' expenses: $e");
      }
    }
  }


  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(12, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _monthlyExpenses[index],
            color: Colors.teal,
            width: 16,
          ),
        ],
      );
    });
  }

  List<BarChartGroupData> _buildFriendsBarGroups() {
    return List.generate(_friendNames.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _pendingExpenses[index],
            color: Colors.orange,
            width: 8,
            borderRadius: BorderRadius.circular(0),
          ),
          BarChartRodData(
            toY: _cancelledExpenses[index],
            color: Colors.red,
            width: 8,
            borderRadius: BorderRadius.circular(0),
          ),
        ],
      );
    });
  }

  double _getMaxYValue() {
    double maxExpense = _monthlyExpenses.reduce((a, b) => a > b ? a : b);
    return maxExpense + (maxExpense * 0.2); // Add 20% padding to the max value
  }

  double _getMaxFriendsYValue() {
    double maxPending = _pendingExpenses.isNotEmpty
        ? _pendingExpenses.reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxCancelled = _cancelledExpenses.isNotEmpty
        ? _cancelledExpenses.reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxExpense = maxPending > maxCancelled ? maxPending : maxCancelled;
    return maxExpense + (maxExpense * 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.teal,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Username: $_userName',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Email: $_email',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 20),
            Row(
              children: [
                Text('Select Year:', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedYear,
                  items: List.generate(10, (index) {
                    String year = (DateTime
                        .now()
                        .year - index).toString();
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year),
                    );
                  }),
                  onChanged: (String? newYear) {
                    if (newYear != null) {
                      setState(() {
                        _selectedYear = newYear;
                        _fetchExpenseAnalysis(); // Update graph based on selected year
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20), // Padding between dropdown and chart
            Container(
              height: 300, // Fixed height for the chart
              child: BarChart(
                BarChartData(
                  maxY: _getMaxYValue(),
                  barGroups: _buildBarGroups(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          List<String> months = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                          ];
                          return Text(months[value.toInt()]);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Total Expenses: \$$_totalExpenses',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Average Expense: \$$_averageExpenses',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20), // Padding between graphs
            Container(
              height: 300, // Fixed height for the friends' chart
              child: BarChart(
                BarChartData(
                  maxY: _getMaxFriendsYValue(),
                  barGroups: _buildFriendsBarGroups(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(_friendNames[value.toInt()]);
                        },
                      ),
                    ),
                  ),

                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 20, height: 20, color: Colors.orange),
                    SizedBox(width: 5),
                    Text('Pending Amount'),
                  ],
                ),
                SizedBox(width: 20),
                Row(
                  children: [
                    Container(width: 20, height: 20, color: Colors.red),
                    SizedBox(width: 5),
                    Text('Cancelled Amount'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}