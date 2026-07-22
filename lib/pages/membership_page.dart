import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_client.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final _authClient = AuthClient();
  MembershipStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final status = await _authClient.checkMembership();
      if (mounted) {
        setState(() {
          _status = status;
          _loading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _startPurchase() async {
    String qrcode;
    String tradeNo;
    try {
      final result = await _authClient.createOrder();
      qrcode = result.qrcode;
      tradeNo = result.tradeNo;
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;

    // ponytail: best-effort launch — many emulators/no-Alipay devices will silently fail.
    unawaited(
      launchUrl(Uri.parse(qrcode), mode: LaunchMode.externalApplication),
    );

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QrCodePanel(
        qrcode: qrcode,
        tradeNo: tradeNo,
        authClient: _authClient,
      ),
    );
    if (paid == true && mounted) await _loadMembership();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return LumoSecondaryPage(
      title: '月度会员',
      body: RefreshIndicator(
        onRefresh: _loadMembership,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            40,
          ),
          children: [
            _BenefitsCard(),
            const SizedBox(height: 28),
            _PriceHeader(),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorView(message: _error!, onRetry: _loadMembership)
            else ...[
              _PurchaseSection(status: _status, onPurchase: _startPurchase),
              const SizedBox(height: 32),
              _FooterNotes(),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final benefits = <(_BenefitIcon, String)>[
      (
        _BenefitIcon(Icons.memory),
        '${(MembershipProduct.contextLimit / 1000).round()}k 上下文窗口',
      ),
      (
        _BenefitIcon(Icons.chat_bubble_outline_rounded),
        '每日 ${MembershipProduct.dailyMessages} 条消息',
      ),
      (_BenefitIcon(Icons.bolt_rounded), '高峰时段优先回复'),
      (_BenefitIcon(Icons.explore_outlined), '更多智能体（陆续开放）'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('会员权益', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final (icon, label) in benefits) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitIcon extends StatelessWidget {
  const _BenefitIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
  );
}

class _PriceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.displaySmall,
            children: [
              TextSpan(
                text: '¥${MembershipProduct.price.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'LumoDisplay'),
              ),
              TextSpan(
                text: ' / 月',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '有效期 ${MembershipProduct.durationDays} 天',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection({required this.status, required this.onPurchase});
  final MembershipStatus? status;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    if (status == null || !status!.isMember) {
      return FilledButton(onPressed: onPurchase, child: const Text('立即开通'));
    }
    final plan = status!.plan;
    if (plan == 'permanent') {
      return _InfoPill(text: '您是永久会员，无需续费。');
    }
    // monthly
    final expiry = status!.expireAt;
    final expiryText = expiry != null
        ? '会员有效期至：${_formatDate(expiry)}'
        : '会员有效中';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPill(text: expiryText),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onPurchase, child: const Text('续费一个月')),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: LumoColors.positive.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: LumoColors.positive),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      OutlinedButton(onPressed: onRetry, child: const Text('重试')),
    ],
  );
}

class _FooterNotes extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    '订阅说明：月度会员不自动续费，到期后需手动续费。支付由第三方支付服务处理，Lumo 不存储你的支付凭据。',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

String _formatDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _QrCodePanel extends StatefulWidget {
  const _QrCodePanel({
    required this.qrcode,
    required this.tradeNo,
    required this.authClient,
  });
  final String qrcode;
  final String tradeNo;
  final AuthClient authClient;

  @override
  State<_QrCodePanel> createState() => _QrCodePanelState();
}

class _QrCodePanelState extends State<_QrCodePanel> {
  // ponytail: 30s total, 3s interval. 10 polls — covers the typical Alipay flow.
  static const _polls = 10;
  static const _interval = Duration(seconds: 3);
  int _remaining = _polls;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_remaining <= 0 || _checking) return;
    setState(() => _remaining--);
    if (_remaining < 0) return;
    setState(() => _checking = true);
    try {
      final status = await widget.authClient.checkMembership();
      if (status.isMember && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (_) {
      // network blips: keep polling
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (_remaining <= 0 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未检测到支付，可重新发起。')));
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('使用支付宝扫码支付', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: widget.qrcode,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _remaining > 0 ? '正在等待支付结果…（${_remaining * 3}s）' : '检测超时',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('我已支付完成'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => unawaited(
                    launchUrl(
                      Uri.parse(widget.qrcode),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  child: const Text('打开支付宝'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
