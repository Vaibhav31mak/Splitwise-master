import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<DocumentSnapshot<Map<String, dynamic>>> _friends = [];
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
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId)
            .get();

        final List<String> friendIds = List.from(snapshot.data()?['friends'] ?? []);

        final List<DocumentSnapshot<Map<String, dynamic>>> friendDocs = [];
        for (final friendId in friendIds) {
          if (friendId != currentUserId) {
            final DocumentSnapshot<Map<String, dynamic>> friendDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(friendId)
                .get();
            friendDocs.add(friendDoc);
          }
        }
        setState(() {
          _friends = friendDocs;
          _isLoading = false;
        });
      } catch (e) {
        print('Failed to fetch friends: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching friends')));
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        // Update the current user's friends list
        final DocumentReference currentUserRef = FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId);

        await currentUserRef.update({
          'friends': FieldValue.arrayRemove([friendId])
        });

        // Optionally, you can also remove the current user from the friend's list
        final DocumentReference friendRef = FirebaseFirestore.instance
            .collection('friends')
            .doc(friendId);

        await friendRef.update({
          'friends': FieldValue.arrayRemove([currentUserId])
        });

        setState(() {
          _friends.removeWhere((friend) => friend.id == friendId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend removed successfully')),
        );
      } catch (e) {
        print('Failed to remove friend: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing friend')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
          : _friends.isEmpty
          ? Center(child: Text('No friends found', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index].data();
          final friendId = _friends[index].id;
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text(friend?['username'] ?? 'No Username',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  _removeFriend(friendId);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
