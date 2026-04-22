import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMessages();
      setState(() => _messages = res['messages'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: AppColors.textGray,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No messages yet.',
                    style: TextStyle(color: AppColors.textGray, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showNewMessage(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                    label: const Text(
                      'Send a message',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final auth = context.read<AuthProvider>();
                    final isSend = m['sender_id'] == auth.userId;
                    final other = isSend
                        ? m['receiver_name']
                        : m['sender_name'];
                    final oRole = isSend
                        ? m['receiver_role']
                        : m['sender_role'];
                    final unread = !m['is_read'] && !isSend;
                    final date = m['created_at'] != null
                        ? DateFormat(
                            'MMM d, h:mm a',
                          ).format(DateTime.parse(m['created_at']).toLocal())
                        : '';
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ThreadScreen(
                              messageId: m['id'],
                              subject: m['subject'] ?? '',
                            ),
                          ),
                        );
                        _load();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: unread
                              ? AppColors.teal.withAlpha(10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: unread
                              ? Border.all(color: AppColors.teal.withAlpha(60))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AvatarCircle(
                              name: other ?? '?',
                              size: 44,
                              color: oRole == 'admin'
                                  ? AppColors.amber
                                  : oRole == 'teacher'
                                  ? AppColors.teal
                                  : AppColors.navy,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          other ?? '',
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m['subject'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: unread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: unread
                                          ? AppColors.textDark
                                          : AppColors.textGray,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  StatusBadge(status: oRole ?? ''),
                                ],
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.teal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () => _showNewMessage(context),
                    backgroundColor: AppColors.teal,
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  void _showNewMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewMessageSheet(onSent: _load),
    );
  }
}

class NewMessageSheet extends StatefulWidget {
  final VoidCallback onSent;
  const NewMessageSheet({super.key, required this.onSent});
  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  List _users = [];
  int? _to;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiService.getContacts();
      if (mounted) {
        setState(() => _users = res['contacts'] ?? []);
      }
    } catch (e) {
      if (mounted) setState(() => _users = []);
    }
  }

  // Future<void> _loadUsers() async {
  //   try {
  //     final res = await ApiService.getContacts();
  //     setState(() => _users = res['contacts'] ?? []);
  //   } catch (_) {}
  // }

  // Future<void> _loadUsers() async {
  //   try {
  //     final auth = context.read<AuthProvider>();
  //     final all = <dynamic>[];
  //     if (auth.role == 'student' || auth.role == 'teacher') {
  //       final a = await ApiService.getUsers(role: 'admin');
  //       final t = await ApiService.getUsers(role: 'teacher');
  //       all.addAll(a['users'] ?? []);
  //       if (auth.role == 'student') all.addAll(t['users'] ?? []);
  //     } else if (auth.role == 'admin') {
  //       final t = await ApiService.getUsers(role: 'teacher');
  //       final s = await ApiService.getUsers(role: 'student');
  //       all.addAll(t['users'] ?? []);
  //       all.addAll(s['users'] ?? []);
  //       // Add superadmin
  //       final su = await ApiService.getUsers(role: 'superadmin');
  //       all.addAll(su['users'] ?? []);
  //     } else {
  //       final a = await ApiService.getUsers(role: 'admin');
  //       all.addAll(a['users'] ?? []);
  //     }
  //     setState(
  //       () => _users = all
  //           .where((u) => u['id'] != context.read<AuthProvider>().userId)
  //           .toList(),
  //     );
  //   } catch (_) {}
  // }

  Future<void> _send() async {
    if (_to == null || _subject.text.isEmpty || _body.text.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.sendMessage({
        'receiverId': _to,
        'subject': _subject.text.trim(),
        'body': _body.text.trim(),
      });
      if (!mounted) return;
      if (res['message'] != null) {
        Navigator.pop(context);
        widget.onSent();
      } else {
        setState(() => _error = res['error'] ?? 'Failed to send');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'New Message',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_users.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.teal,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading contacts...',
                      style: TextStyle(color: AppColors.textGray, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _to,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Send To',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: _users.map((u) {
                  final role = u['role'] ?? '';
                  Color color = role == 'superadmin'
                      ? Colors.purple
                      : role == 'admin'
                      ? AppColors.amber
                      : role == 'teacher'
                      ? AppColors.teal
                      : AppColors.navy;
                  return DropdownMenuItem(
                    value: u['id'] as int,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (u['name'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                u['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                role,
                                style: TextStyle(fontSize: 6, color: color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _to = v),
              ),

            // if (_users.isEmpty)
            //   const Center(child: CircularProgressIndicator())
            // else
            //   DropdownButtonFormField<int>(
            //     initialValue: _to,
            //     isExpanded: true,
            //     decoration: const InputDecoration(
            //       labelText: 'Send To',
            //       prefixIcon: Icon(Icons.person_outline),
            //     ),
            //     items: _users
            //         .map(
            //           (u) => DropdownMenuItem(
            //             value: u['id'] as int,
            //             child: Text(
            //               '${u['name']} (${u['role']})',
            //               overflow: TextOverflow.ellipsis,
            //             ),
            //           ),
            //         )
            //         .toList(),
            //     onChanged: (v) => setState(() => _to = v),
            //   ),
            const SizedBox(height: 10),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                label: Text(
                  _loading ? 'Sending...' : 'Send Message',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  final int messageId;
  final String subject;
  const ThreadScreen({
    super.key,
    required this.messageId,
    required this.subject,
  });
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  Map _original = {};
  List _replies = [];
  bool _loading = true;
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getThread(widget.messageId);
      setState(() {
        _original = res['message'] ?? {};
        _replies = res['replies'] ?? [];
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _sendReply() async {
    if (_reply.text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiService.replyMessage(widget.messageId, _reply.text.trim());
      _reply.clear();
      await _load();
    } catch (_) {}
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(widget.subject, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _MessageBubble(
                        message: _original,
                        isMine: _original['sender_id'] == auth.userId,
                        isFirst: true,
                      ),
                      ..._replies.map(
                        (r) => _MessageBubble(
                          message: r,
                          isMine: r['sender_id'] == auth.userId,
                          isFirst: false,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          decoration: const InputDecoration(
                            hintText: 'Write a reply...',
                            isDense: true,
                          ),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _sendReply,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: AppColors.teal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map message;
  final bool isMine;
  final bool isFirst;
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final name = isMine ? 'You' : message['sender_name'] ?? '';
    final date = message['created_at'] != null
        ? DateFormat(
            'MMM d, h:mm a',
          ).format(DateTime.parse(message['created_at']).toLocal())
        : '';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMine) ...[
                  AvatarCircle(name: name, size: 28, color: AppColors.navy),
                  const SizedBox(width: 6),
                ],
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  AvatarCircle(name: name, size: 28, color: AppColors.teal),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMine ? AppColors.teal : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFirst && (message['subject'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        message['subject'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isMine ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ),
                  Text(
                    message['body'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine ? Colors.white : AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: const TextStyle(fontSize: 10, color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }
}
