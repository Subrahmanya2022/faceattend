import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getNotifications();
      setState(() => _notifs = res['notifications'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    _load();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'session':
        return Icons.event;
      case 'message':
        return Icons.message;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'session':
        return AppColors.teal;
      case 'message':
        return AppColors.navy;
      case 'warning':
        return AppColors.amber;
      default:
        return AppColors.textGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => !n['is_read']).length;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _notifs.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: AppColors.textGray,
                ),
                SizedBox(height: 16),
                Text(
                  'No notifications yet.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 15),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: Column(
              children: [
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _markAllRead,
                          icon: const Icon(
                            Icons.done_all,
                            size: 16,
                            color: AppColors.teal,
                          ),
                          label: Text(
                            'Mark all read ($unread)',
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifs.length,
                    itemBuilder: (_, i) {
                      final n = _notifs[i];
                      final unrd = !n['is_read'];
                      final type = n['type'] ?? 'info';
                      final date = n['created_at'] != null
                          ? DateFormat(
                              'MMM d, h:mm a',
                            ).format(DateTime.parse(n['created_at']).toLocal())
                          : '';
                      return GestureDetector(
                        onTap: () async {
                          await ApiService.markNotificationRead(n['id']);
                          _load();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: unrd
                                ? _color(type).withAlpha(10)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: unrd
                                ? Border.all(color: _color(type).withAlpha(60))
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
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _color(type).withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _icon(type),
                                  color: _color(type),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: unrd
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      n['message'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGray,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (unrd)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _color(type),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
  }
}
