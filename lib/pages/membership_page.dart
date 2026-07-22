import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
            if (_status != null && _status!.isMember) ...[
              _MembershipStatusCard(status: _status!),
              const SizedBox(height: 20),
            ],
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

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.status});
  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final isPermanent = status.plan == 'permanent';
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingDays = status.expireAt != null
        ? ((status.expireAt! - now) / 86_400_000).ceil()
        : null;
    // ponytail: 30-day window for progress ratio; permanent shows full bar.
    final progress = isPermanent
        ? 1.0
        : (remainingDays != null
              ? (remainingDays / MembershipProduct.durationDays).clamp(0.0, 1.0)
              : 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: LumoColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPermanent ? '永久会员' : '月度会员',
                    style: TextStyle(
                      color: LumoColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (status.expireAt != null)
                  Text(
                    '有效期至 ${_formatDate(status.expireAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (isPermanent)
              Text(
                '感谢长期支持，永久会员权益永久有效。',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$remainingDays',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontFamily: 'LumoDisplay',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '天剩余',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
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
  static const _polls = 10;
  static const _interval = Duration(seconds: 3);
  int _remaining = _polls;
  Timer? _timer;
  bool _checking = false;
  bool _timedOut = false;

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
    if (_remaining <= 0 || _timedOut) return;
    if (_checking) return;
    setState(() => _remaining--);
    setState(() => _checking = true);
    try {
      final status = await widget.authClient.checkMembership();
      if (status.isMember && mounted) {
        _timer?.cancel();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('支付成功！')));
        Navigator.pop(context, true);
        return;
      }
    } catch (_) {
      // network blips: keep polling
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (_remaining <= 0 && mounted) {
      setState(() => _timedOut = true);
    }
  }

  Future<void> _manualCheck() async {
    _timer?.cancel();
    setState(() => _checking = true);
    try {
      final status = await widget.authClient.checkMembership();
      if (status.isMember && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('支付成功！')));
        Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂未检测到支付记录，请确认已扫码完成支付。')));
        if (!_timedOut) {
          _timer = Timer.periodic(_interval, (_) => _tick());
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试。')));
        if (!_timedOut) {
          _timer = Timer.periodic(_interval, (_) => _tick());
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
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
          const SizedBox(height: 8),
          Text(
            '长按或截图保存二维码，在支付宝扫一扫中识别',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
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
          if (_timedOut)
            Text(
              '未检测到支付，可重新检测。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_checking)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Text(
                  '正在等待支付结果…（${_remaining * 3}s）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _checking ? null : _manualCheck,
              child: Text(_timedOut ? '重新检测支付状态' : '我已支付完成'),
            ),
          ),
        ],
      ),
    ),
  );
}
