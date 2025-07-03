import 'package:chat_app/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final Map<String, Map<String, dynamic>> lastMessageCache = {};

  String getChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '$a\_$b' : '$b\_$a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d1b2a),
      appBar: AppBar(
        foregroundColor: const Color(0xffffffff),
        elevation: 5,
        title: const Text("WhatsApp"),
        backgroundColor: const Color(0xff0d1b2a),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!.docs
              .where((d) => d.id != currentUserId)
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final userDoc = users[i];
              final userId = userDoc.id;
              final name = (userDoc.data() as Map)['name'] ?? 'No Name';
              final profileUrl = (userDoc.data() as Map)['photoURL'] ?? '';
              final chatId = getChatId(currentUserId!, userId);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('chatId', isEqualTo: chatId)
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (ctx2, msgSnap) {
                  String lastMessage = 'No messages yet';
                  String time = '';

                  // If data is present, update cache
                  if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                    final d =
                        msgSnap.data!.docs.first.data() as Map<String, dynamic>;
                    final t = d['type'] == 'image'
                        ? '📷 Photo'
                        : d['text'] ?? '';
                    final ts = d['timestamp'] as Timestamp?;
                    lastMessage = t;
                    time = ts != null
                        ? DateFormat('hh:mm a').format(ts.toDate())
                        : '';
                    lastMessageCache[chatId] = {
                      'text': lastMessage,
                      'time': time,
                    };
                  } else if (lastMessageCache.containsKey(chatId)) {
                    // Fallback to cached data
                    lastMessage = lastMessageCache[chatId]!['text'];
                    time = lastMessageCache[chatId]!['time'];
                  }

                  return ListTile(
                    leading: profileUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 26,
                            backgroundImage: NetworkImage(profileUrl),
                          )
                        : CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.teal,
                            child: Text(
                              name
                                  .trim()
                                  .split(' ')
                                  .map((e) => e[0])
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instance
                          .ref('status/$userId/typingTo')
                          .onValue,
                      builder: (context, typingSnapshot) {
                        final typingTo = typingSnapshot.data?.snapshot.value
                            ?.toString();
                        final isTyping = typingTo == currentUserId;

                        return Text(
                          isTyping
                              ? 'Typing...'
                              : (lastMessage.isNotEmpty
                                    ? lastMessage
                                    : 'No messages yet'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                    trailing: time.isNotEmpty
                        ? Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          )
                        : null,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: userId,
                            receiverName: name,
                            receiverProfileUrl: profileUrl,
                          ),
                        ),
                      );
                      if (mounted) {
                        setState(() {}); // Safe rebuild after return
                      }
                    },
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
