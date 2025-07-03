import 'package:chat_app/login_screen.dart';
import 'package:chat_app/main_screen.dart';
import 'package:chat_app/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WrapperScreen extends StatelessWidget {
  const WrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          PresenceHelper.setupUserPresence(snapshot.data!.uid);
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
