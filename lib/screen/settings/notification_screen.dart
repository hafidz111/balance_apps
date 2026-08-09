import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/providers/notification_provider.dart';
import 'package:starvy/theme/app_colors.dart';
import 'package:starvy/utils/date_format.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0.5,
        title: const Text(
          "Notifikasi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (notifications.isNotEmpty) ...[
            TextButton(
              onPressed: () async {
                await provider.markAllAsRead();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Semua notifikasi ditandai dibaca")),
                );
              },
              child: const Text(
                "Baca Semua",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: "Hapus Semua Yang Sudah Dibaca",
              onPressed: () async {
                final readCount = notifications.where((n) => n.isRead).length;
                if (readCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Tidak ada notifikasi terbaca untuk dihapus")),
                  );
                  return;
                }
                await provider.deleteReadNotifications();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$readCount notifikasi terbaca dihapus")),
                );
              },
            ),
          ]
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_none_outlined,
                          size: 72,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Belum Ada Notifikasi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D2942),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Notifikasi yang Anda terima akan muncul di sini.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: item.isRead ? Colors.white : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isRead
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFBFDBFE),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x050F172A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Unread indicator line on the left side
                              Container(
                                width: 5,
                                color: item.isRead
                                    ? Colors.transparent
                                    : AppColors.primary,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontWeight: item.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatDates(item.timestamp),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.body,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: item.isRead
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
