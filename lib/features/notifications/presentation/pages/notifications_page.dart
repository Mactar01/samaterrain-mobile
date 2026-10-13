import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final dio = DioClient().dio;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await dio.get('/notifications');
      // Réponse paginée Laravel : { notifications: { data: [...] }, unread_count }
      setState(() {
        _notifications = response.data['notifications']['data'] as List<dynamic>;
        _unreadCount = response.data['unread_count'] ?? 0;
      });
    } catch (e) {
      setState(() => _error = 'Impossible de charger les notifications.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(dynamic notification) async {
    if (notification['read_at'] != null) return;
    try {
      await dio.patch('/notifications/${notification['id']}/read');
      setState(() {
        notification['read_at'] = DateTime.now().toIso8601String();
        _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await dio.patch('/notifications/read-all');
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur, réessayez.'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    return DateFormat('d MMM yyyy à HH:mm', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Tout marquer comme lu',
              icon: const Icon(Icons.done_all),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetch, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return const Center(child: Text("Vous n'avez aucune notification."));
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final data = n['data'] ?? {};
          final isUnread = n['read_at'] == null;

          return ListTile(
            tileColor: isUnread ? Colors.green.shade50 : null,
            leading: Icon(
              isUnread ? Icons.notifications_active : Icons.notifications_none,
              color: isUnread ? const Color(0xFF2E7D32) : Colors.grey,
            ),
            title: Text(
              data['title'] ?? 'Notification',
              style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['message'] != null) Text(data['message']),
                const SizedBox(height: 4),
                Text(_formatDate(n['created_at']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            onTap: () => _markRead(n),
          );
        },
      ),
    );
  }
}
