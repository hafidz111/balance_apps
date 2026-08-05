import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:starvy/navigation/app_routes.dart';
import 'package:starvy/providers/ai_chat_provider.dart';
import 'package:starvy/providers/firebase_auth_provider.dart';
import 'package:starvy/providers/main_screen_provider.dart';
import 'package:starvy/providers/shared_preference_provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/service/premium_service.dart';
import 'package:starvy/service/purchase_service.dart';
import 'package:starvy/theme/app_colors.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _checkingPremium = true;
  bool _isPremium = false;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _refreshPremium();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshPremium() async {
    setState(() => _checkingPremium = true);
    final premium = await PremiumService.isPremium();
    if (!mounted) return;
    setState(() {
      _isPremium = premium;
      _checkingPremium = false;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _submit() async {
    final text = _controller.text;
    _controller.clear();
    await context.read<AiChatProvider>().send(text);
    _scrollToEnd();
  }

  Future<void> _buyPremium() async {
    final isLogin = context.read<SharedPreferenceProvider>().isLogin;
    final user = context.read<FirebaseAuthProvider>().profile;

    if (!isLogin || user == null) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Login dulu untuk beli fitur premium.',
        type: SnackType.error,
      );
      if (!mounted) return;
      await context.pushAppRoute(AppRoutes.login);
      if (!mounted) return;
      await _refreshPremium();
      return;
    }

    if (_buying) return;
    setState(() => _buying = true);
    try {
      final purchaseService = PurchaseService();
      await purchaseService.init();
      await purchaseService.buyRemoveAds();
      // Tunggu status premium dari listener IAP / cek ulang.
      await Future<void>.delayed(const Duration(seconds: 2));
      await PremiumService.isPremium();
      if (!mounted) return;
      await _refreshPremium();
      if (_isPremium) {
        CustomSnackBar.show(
          context,
          message: 'Premium aktif. Asisten AI terbuka!',
          type: SnackType.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Pembelian gagal. Coba lagi.',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPremium) {
      return const Center(child: CircularProgressIndicator());
    }

    final chat = context.watch<AiChatProvider>();
    if (_isPremium && chat.messages.isNotEmpty) _scrollToEnd();

    final chatBody = Column(
      children: [
        Material(
          color: AppColors.primaryLight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Asisten — spill insight dari data lokal tokomu.',
                    style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
                  ),
                ),
                if (_isPremium && chat.messages.isNotEmpty)
                  IconButton(
                    tooltip: 'Hapus chat',
                    onPressed: chat.loading ? null : chat.clear,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: chat.messages.isEmpty || !_isPremium
              ? _EmptyHints(
                  onPick: (q) {
                    if (!_isPremium) return;
                    _controller.text = q;
                    _submit();
                  },
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: chat.messages.length + (chat.loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (chat.loading && i == chat.messages.length) {
                      return const _Bubble(
                        isUser: false,
                        text: 'Lagi ngecek datanya… bentar ya ✨',
                      );
                    }
                    final m = chat.messages[i];
                    return _Bubble(
                      isUser: m.role == 'user',
                      text: m.content,
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: _isPremium,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!_isPremium || chat.loading) return;
                      _submit();
                    },
                    decoration: InputDecoration(
                      hintText: 'Tanya apa aja soal tokonya…',
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (!_isPremium || chat.loading) ? null : _submit,
                  icon: chat.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (_isPremium) return chatBody;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: IgnorePointer(child: chatBody),
        ),
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
        ),
        _AssistantPremiumLock(
          buying: _buying,
          onBuy: _buyPremium,
          onGoSettings: () {
            context.read<MainScreenProvider>().setSelectedIndex(9);
          },
        ),
      ],
    );
  }
}

class _AssistantPremiumLock extends StatelessWidget {
  const _AssistantPremiumLock({
    required this.buying,
    required this.onBuy,
    required this.onGoSettings,
  });

  final bool buying;
  final VoidCallback onBuy;
  final VoidCallback onGoSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade700, width: 1.2),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 36,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Asisten AI terkunci',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Beli fitur premium untuk buka chat Asisten AI. ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: buying ? null : onBuy,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: buying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.workspace_premium),
                    label: Text(buying ? 'Memproses…' : 'Beli fitur premium'),
                  ),
                ),
                TextButton(
                  onPressed: onGoSettings,
                  child: const Text('Ke Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHints extends StatelessWidget {
  const _EmptyHints({required this.onPick});

  final ValueChanged<String> onPick;

  static const _hints = [
    'Berapa cup/hari yang harus dikejar sisa bulan ini?',
    'Spill performa coffee vs bread bulan ini',
    'Saran biar omzet naik berdasarkan data toko',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Asisten AI Starvy',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Khusus data toko: penjualan, cup, target, insight, barcode & saran operasional. '
          'Di luar itu ditolak. Data dari lokal di HP.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 24),
        for (final h in _hints)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => onPick(h),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(h),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? 14 : 12,
          vertical: isUser ? 10 : 8,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.85 : 0.94),
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: isUser
            ? SelectableText(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.45,
                  fontSize: 15,
                ),
              )
            : MarkdownBody(
                data: text,
                selectable: true,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.45,
                    fontSize: 15,
                  ),
                  h1: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontSize: 20,
                  ),
                  h2: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontSize: 17,
                  ),
                  h3: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  em: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade800,
                  ),
                  listBullet: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                  tableHead: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  tableBody: const TextStyle(fontSize: 13, height: 1.35),
                  tableBorder: TableBorder.all(
                    color: Colors.grey.shade400,
                    width: 0.7,
                  ),
                  tableCellsPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  blockSpacing: 10,
                  listIndent: 20,
                ),
              ),
      ),
    );
  }
}
