// HomePage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project/settleup.dart';
import 'add_friend_page.dart';
import 'friends_page.dart';
import 'bill_split_screen.dart';
import 'bill_requests_page.dart';
import 'split_requested_page.dart';
import 'ProfilePage.dart';
import 'package:battery_plus/battery_plus.dart';

// Ensure FriendRequestsPage is imported or placed below this class
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DocumentSnapshot> _friendRequests = [];
  String _userName = '';
  final Battery _battery = Battery(); // Create an instance of Battery
  int _batteryLevel = 0;  // Store battery level

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
    _fetchUserName();
    _getBatteryLevel();
  }
  Future<void> _getBatteryLevel() async {
    final level = await _battery.batteryLevel;  // Get battery level
    setState(() {
      _batteryLevel = level;  // Update state with battery level
    });
  }
  Future<void> _fetchFriendRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      setState(() {
        _friendRequests = snapshot.docs;
      });
    }
  }

  Future<void> _fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      print("User data: ${userSnapshot.data()}");
      setState(() {
        _userName = userSnapshot['username'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()), // Navigate to ProfilePage
              );
            },  
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.teal),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome $_userName ,',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Battery Level: $_batteryLevel%',  // Display battery level
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildNavigationButton(context, 'Split Expense', BillSplitScreen()),//4
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'View Split Requests', SplitRequestsPage()),//5
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'View Splits Requested', SplitRequestedPage()),//6
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'Add Friend', AddFriendPage()),//1
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'Settle Up', SettleUpPage()),//7
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'Friend Requests', FriendRequestsPage(//2
                    friendRequests: _friendRequests,
                    onAccept: _fetchFriendRequests,
                  )),
                  SizedBox(height: 20),
                  _buildNavigationButton(context, 'Friends', FriendsPage()),//3
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(BuildContext context, String text, Widget page) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}

// Define the FriendRequestsPage here or import it from another file
class FriendRequestsPage extends StatefulWidget {
  final List<DocumentSnapshot> friendRequests;
  final Function onAccept;

  FriendRequestsPage({required this.friendRequests, required this.onAccept});

  @override
  _FriendRequestsPageState createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  late List<DocumentSnapshot> _localFriendRequests;

  @override
  void initState() {
    super.initState();
    _localFriendRequests = List.from(widget.friendRequests); // Create a local copy of the friend requests
  }

  Future<void> _acceptFriendRequest(BuildContext context, String requestId, String fromId, int index) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Add friends for both users
        await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).set({
          'friends': FieldValue.arrayUnion([fromId]),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('friends').doc(fromId).set({
          'friends': FieldValue.arrayUnion([currentUser.uid]),
        }, SetOptions(merge: true));

        // Update the friend request status to 'accepted'
        await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
          'status': 'accepted',
        });

        // Remove the request from the local list and update the UI
        setState(() {
          _localFriendRequests.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request accepted')),
        );

        widget.onAccept();
      } catch (e) {
        print('Failed to accept friend request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Requests'),
        backgroundColor: Colors.teal,
      ),
      body: _localFriendRequests.isEmpty
          ? Center(
        child: Text('No friend requests', style: TextStyle(fontSize: 18, color: Colors.grey)),
      )
          : ListView.builder(
        itemCount: _localFriendRequests.length,
        itemBuilder: (context, index) {
          final request = _localFriendRequests[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text('${request['fromName']} sent you a friend request',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(
                onPressed: () {
                  _acceptFriendRequest(context, request.id, request['from'], index);
                },
                child: Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
