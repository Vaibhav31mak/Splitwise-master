import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFriendPage extends StatefulWidget {
  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  List<DocumentSnapshot> _filteredUsers = [];
  final ValueNotifier<List<DocumentSnapshot>> _filteredUsersNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId != null) {
        // Fetch the current user's friends list
        final DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId)
            .get();

        // Safely cast the document data to Map<String, dynamic>
        final Map<String, dynamic>? data = currentUserDoc.data() as Map<String, dynamic>?;

        // Get the list of friends IDs (if available)
        final List<String> friends = List.from(data?['friends'] ?? []);

        // Fetch all users
        final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();

        // Filter out the current user and the ones who are already friends
        setState(() {
          _users = snapshot.docs
              .where((user) => user.id != currentUserId && !friends.contains(user.id))
              .toList();

          _filteredUsers = _users;
          _filteredUsersNotifier.value = _filteredUsers;
        });
      }
    } catch (e) {
      print('Failed to fetch users: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching users')));
    }
  }


  void _searchUser(String query) {
    final filteredUsers = query.isEmpty
        ? _users
        : _users.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      final searchLower = query.toLowerCase();
      return username.contains(searchLower);
    }).toList();

    setState(() {
      _filteredUsers = filteredUsers;
      _filteredUsersNotifier.value = _filteredUsers;
    });
  }

  void _sendFriendRequest(String userId, String username) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Fetch the current user's document from Firestore
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          // Cast the data to Map<String, dynamic>
          final data = userDoc.data() as Map<String, dynamic>?;

          // Debugging: Print out the document data
          print('Document data: $data');

          // Safely retrieve the user's username or default to 'No Username' if the field doesn't exist
          final String currentUserName = data != null && data.containsKey('username')
              ? data['username']
              : 'No Username';

          // Send the friend request with the correct name
          await FirebaseFirestore.instance.collection('friend_requests').add({
            'from': currentUser.uid,
            'to': userId,
            'fromName': currentUserName,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Friend request sent')));
        } else {
          print('Document does not exist.');
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User document not found')));
        }
      } catch (e) {
        print('Failed to send friend request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friend'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2.0),
                ),
              ),
              onChanged: _searchUser,
            ),
            SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _filteredUsersNotifier,
                builder: (context, value, child) {
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final user = value[index];
                      return Card(
                        elevation: 5,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Text(user['username'] ?? 'No Username'),
                          trailing: IconButton(
                            icon: Icon(Icons.person_add, color: Colors.teal),
                            onPressed: () => _sendFriendRequest(user.id, user['username'] ?? 'No Username'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}