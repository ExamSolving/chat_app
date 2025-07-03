import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceHelper {
  static void setupUserPresence(String uid) {
    final db = FirebaseDatabase.instance;
    final userStatusRef = db.ref('status/$uid');
    final connectedRef = db.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        userStatusRef.onDisconnect().set({
          'state': 'offline',
          'lastSeen': ServerValue.timestamp,
          'typingTo': '',
        });
        userStatusRef.set({
          'state': 'online',
          'lastSeen': ServerValue.timestamp,
          'typingTo': '',
        });
      }
    });

    userStatusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isOnline': data['state'] == 'online',
          'lastSeen': Timestamp.fromMillisecondsSinceEpoch(
            data['lastSeen'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
        });
      }
    });
  }
}
