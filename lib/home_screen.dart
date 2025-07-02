import 'package:chat_app/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xff0d1b2a),
      appBar: AppBar(
        elevation: 5,
        backgroundColor: const Color(0xff0d1b2a),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // hides back button
        title: const Text("Chats"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No users found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final users = snapshot.data!.docs
              .where((doc) => doc.id != currentUserId)
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final name = user['name'] ?? 'No Name';
              final email = user['email'] ?? 'No Email';
              final profileUrl = user['profileUrl'];
              final userId = users[index].id;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: profileUrl != null && profileUrl.isNotEmpty
                    ? CircleAvatar(
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: NetworkImage(profileUrl),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Text(
                          name.trim().isNotEmpty
                              ? name
                                    .trim()
                                    .split(' ')
                                    .map((e) => e.isNotEmpty ? e[0] : '')
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: userId,
                        receiverName: name,
                        receiverProfileUrl: profileUrl,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
