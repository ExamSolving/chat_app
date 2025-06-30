import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverProfileUrl;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfileUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'senderId': currentUserId,
      'receiverId': widget.receiverId,
      'text': _messageController.text.trim(),
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('chats').add(message);
    _messageController.clear();
  }

  Future<void> pickMedia() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child('${const Uuid().v4()}.jpg');
      await ref.putFile(File(pickedFile.path));
      final mediaUrl = await ref.getDownloadURL();

      final message = {
        'senderId': currentUserId,
        'receiverId': widget.receiverId,
        'mediaUrl': mediaUrl,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('chats').add(message);
    }
  }

  Widget buildChatInput() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: pickMedia,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() => _showEmojiPicker = false);
                  }
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget messageBubble(Map<String, dynamic> data, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xff056162) : const Color(0xff262d31),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: data['type'] == 'image'
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data['mediaUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => const Text(
                    'Image not found',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            : Text(
                data['text'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b2a),
        foregroundColor: const Color(0xffffffff),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  widget.receiverProfileUrl != null &&
                      widget.receiverProfileUrl!.isNotEmpty
                  ? NetworkImage(widget.receiverProfileUrl!)
                  : null,
              child:
                  widget.receiverProfileUrl == null ||
                      widget.receiverProfileUrl!.isEmpty
                  ? Text(
                      widget.receiverName.trim().isNotEmpty
                          ? widget.receiverName
                                .trim()
                                .split(' ')
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.receiverName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/bg_img.jpg', fit: BoxFit.cover),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['senderId'] == currentUserId &&
                              data['receiverId'] == widget.receiverId) ||
                          (data['senderId'] == widget.receiverId &&
                              data['receiverId'] == currentUserId);
                    }).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data =
                            messages[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == currentUserId;
                        return messageBubble(data, isMe);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          buildChatInput(),
        ],
      ),
    );
  }
}
