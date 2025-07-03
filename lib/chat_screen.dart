import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    markMessagesAsSeen();
    updateLastSeen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _onStopTyping();
    super.dispose();
  }

  void updateLastSeen() {
    FirebaseDatabase.instance
        .ref("status/$currentUserId/lastSeen")
        .onDisconnect()
        .set(ServerValue.timestamp);
  }

  void _onTyping() {
    if (!_isTyping) {
      setState(() => _isTyping = true);
      FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'typingTo': widget.receiverId,
      });
      FirebaseDatabase.instance
          .ref('status/$currentUserId/typingTo')
          .set(widget.receiverId);
    }
  }

  void _onStopTyping() {
    if (_isTyping) {
      setState(() => _isTyping = false);
      FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'typingTo': '',
      });
      FirebaseDatabase.instance.ref('status/$currentUserId/typingTo').set('');
    }
  }

  void markMessagesAsSeen() async {
    final unread = await FirebaseFirestore.instance
        .collection('chats')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isSeen', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      doc.reference.update({'isSeen': true});
    }
  }

  String getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '$uid1\_$uid2' : '$uid2\_$uid1';
  }

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatId = getChatId(currentUserId!, widget.receiverId);

    final message = {
      'chatId': chatId,
      'senderId': currentUserId,
      'receiverId': widget.receiverId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
    };

    await FirebaseFirestore.instance.collection('chats').add(message);
    _messageController.clear();
    _onStopTyping();

    Future.delayed(const Duration(milliseconds: 100), scrollToBottom);
  }

  Future<void> pickMedia() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child('${const Uuid().v4()}.jpg');
        await ref.putFile(File(pickedFile.path));
        final mediaUrl = await ref.getDownloadURL();

        final chatId = getChatId(currentUserId!, widget.receiverId);

        final message = {
          'chatId': chatId, // ✅ FIXED: Added chatId
          'senderId': currentUserId,
          'receiverId': widget.receiverId,
          'mediaUrl': mediaUrl,
          'type': 'image',
          'timestamp': FieldValue.serverTimestamp(),
          'isSeen': false,
        };

        await FirebaseFirestore.instance.collection('chats').add(message);
        Future.delayed(const Duration(milliseconds: 100), scrollToBottom);
      } catch (e) {
        print('Error uploading media: $e');
      }
    }
  }

  Widget buildAppBarTitle() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref("status/${widget.receiverId}")
          .onValue,
      builder: (context, snapshot) {
        final data = snapshot.data?.snapshot.value;
        String subtitle = 'Loading...';

        if (data != null && data is Map) {
          final isOnline = data['state'] == 'online';
          final typingTo = data['typingTo'] ?? '';
          final lastSeen = data['lastSeen'];

          if (typingTo == currentUserId) {
            subtitle = 'Typing...';
          } else if (isOnline) {
            subtitle = 'Online';
          } else if (lastSeen != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(lastSeen);
            subtitle = 'Last seen ${DateFormat('dd MMM hh:mm a').format(dt)}';
          } else {
            subtitle = 'Offline';
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName, style: const TextStyle(fontSize: 16)),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  Widget buildChatInput() {
    return Container(
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
                onChanged: (text) {
                  if (text.trim().isNotEmpty) {
                    _onTyping();
                  } else {
                    _onStopTyping();
                  }
                },
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() => _showEmojiPicker = false);
                  }
                },
                onEditingComplete: _onStopTyping,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            data['type'] == 'image'
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
            if (isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 5),
                  Icon(
                    data['isSeen'] == true ? Icons.done_all : Icons.check,
                    size: 16,
                    color: data['isSeen'] == true ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
          ],
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
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal,
              backgroundImage:
                  widget.receiverProfileUrl != null &&
                      widget.receiverProfileUrl!.isNotEmpty
                  ? NetworkImage(widget.receiverProfileUrl!)
                  : null,
              child:
                  widget.receiverProfileUrl == null ||
                      widget.receiverProfileUrl!.isEmpty
                  ? Text(
                      widget.receiverName
                          .trim()
                          .split(' ')
                          .map((e) => e[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: buildAppBarTitle()),
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

                    final allMessages = snapshot.data!.docs;
                    List<QueryDocumentSnapshot> filteredMessages = [];

                    for (var doc in allMessages) {
                      final data = doc.data() as Map<String, dynamic>;

                      final isChatBetweenUsers =
                          (data['senderId'] == currentUserId &&
                              data['receiverId'] == widget.receiverId) ||
                          (data['senderId'] == widget.receiverId &&
                              data['receiverId'] == currentUserId);

                      if (isChatBetweenUsers) {
                        filteredMessages.add(doc);

                        if (data['receiverId'] == currentUserId &&
                            data['isSeen'] == false) {
                          doc.reference.update({'isSeen': true});
                        }
                      }
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      scrollToBottom();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      itemCount: filteredMessages.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredMessages[index].data()
                                as Map<String, dynamic>;
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
