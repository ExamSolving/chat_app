import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print(user?.photoURL.toString());

    return Scaffold(
      backgroundColor: const Color(0xff0d1b2a),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xff0d1b2a),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          print(userData);
          final name = userData?['name'] ?? user?.displayName ?? 'No Name';
          final email = userData?['email'] ?? user?.email ?? 'No Email';
          final profileUrl = userData?['photoURL'] ?? '';
          print("object$profileUrl");

          String initials = 'U';
          final parts = name.trim().split(' ');
          if (parts.length >= 2) {
            initials = parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
          } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
            initials = parts[0][0].toUpperCase();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.teal,
                    backgroundImage: profileUrl.isNotEmpty
                        ? NetworkImage(profileUrl)
                        : null,
                    child: profileUrl.isEmpty
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "$name",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$email",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Logout"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
