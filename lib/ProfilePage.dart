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
  List<double> _monthlyExpenses = List.filled(12, 0.0); // Initialize list for 12 months
  String _selectedYear = DateTime.now().year.toString(); // Default selected year

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _fetchExpenseAnalysis(); // Fetch default year data
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
      // Fetch the current user's username
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String username = userSnapshot['username'] ?? '';

      // Determine the start and end timestamps for the selected year
      DateTime startOfYear = DateTime(int.parse(_selectedYear), 1, 1);
      DateTime endOfYear = DateTime(int.parse(_selectedYear), 12, 31, 23, 59, 59);

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: username)
            .where('status', isEqualTo: 'approved')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
            .orderBy('timestamp')
            .get();

        if (snapshot.docs.isNotEmpty) {
          // Process the documents
          for (var doc in snapshot.docs) {
            print("Document ID: ${doc.id}");
            print("Document Data: ${doc.data()}");
          }
        } else {
          print("No documents found for the selected year.");
        }

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

  double _getMaxYValue() {
    // Determine the maximum Y value dynamically based on monthly expenses
    double maxExpense = _monthlyExpenses.reduce((a, b) => a > b ? a : b);
    return maxExpense + (maxExpense * 0.2); // Add 20% padding to the max value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
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
            // Year selection dropdown
            Row(
              children: [
                Text('Select Year:', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedYear,
                  items: List.generate(10, (index) {
                    String year = (DateTime.now().year - index).toString();
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year),
                    );
                  }),
                  onChanged: (String? newYear) {
                    if (newYear != null) {
                      setState(() {
                        _selectedYear = newYear;
                      });
                      _fetchExpenseAnalysis(); // Fetch data for the selected year
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Expense Analysis',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxYValue(), // Dynamically set maxY based on expenses
                  barGroups: _buildBarGroups(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false, // Hide the left Y-axis labels
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const months = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                          ];
                          return Text(
                            months[value.toInt()],
                            style: TextStyle(color: Colors.black),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // Hiding top side titles
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  gridData: FlGridData(show: false),
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
          ],
        ),
      ),
    );
  }
}
