import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d1b2a),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b2a),
        foregroundColor: Colors.white,
        leading: null,
        title: const Text("Home"),
      ),
      body: const Center(
        child: Text("Home Screen", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
