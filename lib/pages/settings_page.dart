import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../auth_client.dart';
import '../chat_store.dart';
import '../update_checker.dart';
import '../widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _store = ChatStore();
  late final _authClient = AuthClient(store: _store);
  AccountSession? _account;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = await _authClient.session();
    if (mounted) {
      setState(() => _account = account);
    }
  }

  Future<void> _showAccount() async {
    final account = _account;
    final choice = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => _AccountPage(account: account)),
    );
    if (choice == null) return;
    if (account != null) {
      if (choice) {
        await _authClient.logout();
        if (mounted) setState(() => _account = null);
      }
      return;
    }
    await _authenticate(register: choice);
  }

  Future<void> _authenticate({required bool register}) async {
    final username = TextEditingController();
    final password = TextEditingController();
    final invite = TextEditingController();
    var loading = false;
    String? error;
    final account = await showDialog<AccountSession>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(register ? '邀请注册' : '登录 Lumo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                autofocus: true,
                maxLength: 24,
                decoration: const InputDecoration(labelText: '账号'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              ),
              if (register)
                TextField(
                  controller: invite,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: '邀请码'),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setDialogState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        final result = register
                            ? await _authClient.register(
                                username.text.trim(),
                                password.text,
                                invite.text.trim(),
                              )
                            : await _authClient.login(
                                username.text.trim(),
                                password.text,
                              );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, result);
                        }
                      } on AuthException catch (exception) {
                        setDialogState(() {
                          loading = false;
                          error = exception.message;
                        });
                      }
                    },
              child: Text(loading ? '请稍候…' : (register ? '注册' : '登录')),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    password.dispose();
    invite.dispose();
    if (account != null && mounted) setState(() => _account = account);
  }

  Future<void> _showPrivacy() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const _PrivacyPage()));

  Future<void> _showLicenses() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const _LicensesPage()));

  Future<void> _checkForUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await UpdateChecker().check();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(const SnackBar(content: Text('已是最新版本')));
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('发现新版本 ${update.version}（构建 ${update.build}）'),
          content: const Text('将在应用内下载 APK，下载完成后会打开系统安装器。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(_startUpdate(update));
              },
              child: const Text('去下载'),
            ),
          ],
        ),
      );
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络不可用，暂时无法检查更新。')));
      }
    } on HttpException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新信息无效，请稍后再试。')));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法检查更新，请稍后再试。')));
      }
    }
  }

  Future<void> _startUpdate(ReleaseUpdate update) async {
    try {
      if (!await _ensureInstallPermission() || !mounted) return;
      await _downloadUpdate(update);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? '无法完成更新，请稍后再试。')),
        );
      }
    } on SocketException {
      _showUpdateError('更新下载连接失败，请检查代理或网络后重试。');
    } on TimeoutException {
      _showUpdateError('更新下载超时，请切换网络后重试。');
    } on HttpException catch (error) {
      _showUpdateError(error.message);
    } on FormatException {
      _showUpdateError('下载内容不是有效的安装包。');
    } on FileSystemException {
      _showUpdateError('更新包处理失败，请重新下载后再试。');
    } on Exception {
      _showUpdateError('无法完成更新，请稍后再试。');
    }
  }

  void _showUpdateError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureInstallPermission() async {
    final checker = UpdateChecker();
    if (await checker.canRequestPackageInstalls()) return true;
    if (!mounted) return false;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('安装权限'),
        content: const Text('安装更新需要允许 Lumo 安装未知应用。开启后请重新检查更新。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (open == true) await checker.openInstallSettings();
    return false;
  }

  Future<void> _downloadUpdate(ReleaseUpdate update) async {
    final checker = UpdateChecker();
    final progress = ValueNotifier<(int, int)>((0, -1));
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('下载更新'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (context, value, child) {
                final (received, total) = value;
                final fraction = total > 0
                    ? (received / total).clamp(0, 1).toDouble()
                    : null;
                final label = fraction != null
                    ? '${(fraction * 100).toStringAsFixed(0)}%'
                    : received > 0
                    ? '已下载 ${(received / 1024 / 1024).toStringAsFixed(1)} MB'
                    : '正在连接下载服务…';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: fraction),
                    const SizedBox(height: 16),
                    Text(label),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    try {
      final apk = await checker.download(update.url, (received, total) {
        if (mounted) progress.value = (received, total);
      });
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
      await checker.installApk(apk.path);
    } finally {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();
    }
  }

  Future<void> _showAbout() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _AboutPage(onCheckForUpdate: _checkForUpdate),
    ),
  );

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsDetailPage(
          account: () => _account,
          onAccount: _showAccount,
          onPrivacy: _showPrivacy,
          onLicenses: _showLicenses,
          onAbout: _showAbout,
          onThemeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('profile-scroll'),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          32,
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('profile-settings'),
              tooltip: '设置',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _account?.username.substring(0, 1).toUpperCase() ?? '游',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _account?.username ?? '游客用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _account == null
                          ? '可体验 10 条消息'
                          : (_account!.isMember ? '永久会员' : '每日 100 条消息'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _ProfileButton(
                  label: _account == null ? '登录 / 注册' : '账号信息',
                  onTap: _showAccount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: _ProfileShortcut(
                  icon: widget.themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: widget.themeMode == ThemeMode.dark ? '浅色模式' : '深色模式',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onThemeModeChanged(
                      widget.themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    );
                  },
                ),
              ),
              Expanded(
                child: _ProfileShortcut(
                  icon: Icons.shield_outlined,
                  label: '隐私说明',
                  onTap: _showPrivacy,
                ),
              ),
              Expanded(
                child: _ProfileShortcut(
                  icon: Icons.system_update_outlined,
                  label: '检查更新',
                  onTap: _checkForUpdate,
                ),
              ),
              Expanded(
                child: _ProfileShortcut(
                  icon: Icons.info_outline_rounded,
                  label: '关于 Lumo',
                  onTap: _showAbout,
                ),
              ),
            ],
          ),
          const SizedBox(height: 72),
          const Center(child: LumoMark(size: 48)),
          const SizedBox(height: 14),
          Text(
            '愿每一次陪伴都由你掌控',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    ),
  );
}

class _ProfileShortcut extends StatelessWidget {
  const _ProfileShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    radius: 32,
    onTap: onTap,
    child: Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.account});

  final AccountSession? account;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return LumoSecondaryPage(
      title: '账号管理',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          24,
          horizontalPadding,
          32,
        ),
        children: [
          const _SettingsLabel('账户'),
          _SettingsGroup(
            children: account == null
                ? [
                    _SettingsRow(
                      title: '登录',
                      onTap: () => Navigator.pop(context, false),
                    ),
                    _SettingsRow(
                      title: '邀请注册',
                      value: '需要邀请码',
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ]
                : [
                    _SettingsRow(title: '账号', value: account!.username),
                    _SettingsRow(
                      title: '权益',
                      value: account!.isMember ? '永久会员' : '每日 100 条消息',
                    ),
                  ],
          ),
          if (account != null) ...[
            const SizedBox(height: 28),
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 64,
                title: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) => LumoSecondaryPage(
    title: '隐私说明',
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        lumoHorizontalPadding(context),
        24,
        lumoHorizontalPadding(context),
        32,
      ),
      children: [
        Text(
          'Lumo 会妥善处理你的账号与对话数据。对话和记忆由你管理，你可以随时删除。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class _LicensesPage extends StatelessWidget {
  const _LicensesPage();

  @override
  Widget build(BuildContext context) => LumoSecondaryPage(
    title: '开源许可',
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        lumoHorizontalPadding(context),
        24,
        lumoHorizontalPadding(context),
        32,
      ),
      children: [
        Text(
          'Lumo 使用以下开源组件；许可文本由各组件的官方仓库维护。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        const _SettingsGroup(
          children: [
            _LicenseLine(name: 'Flutter / Dart', license: 'BSD 3-Clause'),
            _LicenseLine(
              name: 'flutter_animate、flutter_markdown、flutter_svg、sqflite',
              license: 'MIT / BSD',
            ),
            _LicenseLine(name: 'path、sqflite_common_ffi', license: 'BSD / MIT'),
          ],
        ),
      ],
    ),
  );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.onCheckForUpdate});

  final Future<void> Function() onCheckForUpdate;

  @override
  Widget build(BuildContext context) => LumoSecondaryPage(
    title: '关于 Lumo',
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        lumoHorizontalPadding(context),
        32,
        lumoHorizontalPadding(context),
        32,
      ),
      children: [
        const Center(child: LumoMark(size: 64)),
        const SizedBox(height: 16),
        Text(
          'Lumo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          appVersionLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        _SettingsGroup(
          children: [
            _SettingsRow(
              title: '检查更新',
              onTap: () {
                Navigator.pop(context);
                unawaited(onCheckForUpdate());
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          '© 2026 Lumo contributors',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _SettingsDetailPage extends StatefulWidget {
  const _SettingsDetailPage({
    required this.account,
    required this.onAccount,
    required this.onPrivacy,
    required this.onLicenses,
    required this.onAbout,
    required this.onThemeChanged,
  });

  final AccountSession? Function() account;
  final Future<void> Function() onAccount;
  final Future<void> Function() onPrivacy;
  final Future<void> Function() onLicenses;
  final Future<void> Function() onAbout;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<_SettingsDetailPage> createState() => _SettingsDetailPageState();
}

class _SettingsDetailPageState extends State<_SettingsDetailPage> {
  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('设置', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            32,
          ),
          children: [
            const _SettingsLabel('账号与隐私'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  title: '账号设置',
                  value: widget.account()?.username ?? '游客',
                  onTap: () => _run(widget.onAccount),
                ),
                _SettingsRow(
                  title: '隐私说明',
                  onTap: () => _run(widget.onPrivacy),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('应用'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  title: '深色模式',
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (enabled) {
                      HapticFeedback.selectionClick();
                      widget.onThemeChanged(
                        enabled ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                _SettingsRow(
                  title: '开源许可',
                  onTap: () => _run(widget.onLicenses),
                ),
                _SettingsRow(
                  title: '关于 Lumo',
                  value: appVersionLabel,
                  onTap: () => _run(widget.onAbout),
                ),
              ],
            ),
            if (widget.account() != null) ...[
              const SizedBox(height: 22),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    title: '退出登录',
                    onTap: () => _run(widget.onAccount),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 42),
            Text(
              '当前版本：$appVersionLabel',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 Lumo contributors',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Theme.of(context).dividerColor,
            ),
        ],
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    trailing:
        trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 128),
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (onTap != null) const SizedBox(width: 6),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
    onTap: onTap,
  );
}

class _LicenseLine extends StatelessWidget {
  const _LicenseLine({required this.name, required this.license});

  final String name;
  final String license;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(name)),
        Text(license, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
