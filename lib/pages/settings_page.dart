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
  const ProfilePage({required this.themeMode, required this.onThemeModeChanged, super.key});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _store = ChatStore();
  late final _authClient = AuthClient(store: _store);
  AccountSession? _account;
  CompanionPreferences _preferences = const CompanionPreferences(
    personality: CompanionPreferences.defaultPersonality,
    topic: CompanionPreferences.defaultTopic,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await _store.companionPreferences();
    final account = await _authClient.session();
    if (mounted) {
      setState(() {
        _preferences = preferences;
        _account = account;
      });
    }
  }

  Future<void> _showAccount() async {
    final account = _account;
    if (account != null) {
      final logout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(account.username),
          content: Text(account.isMember ? '永久会员' : '普通用户 · 每日 100 条消息'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出登录')),
          ],
        ),
      );
      if (logout == true) {
        await _authClient.logout();
        if (mounted) setState(() => _account = null);
      }
      return;
    }
    final register = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.login_rounded), title: const Text('登录'), onTap: () => Navigator.pop(context, false)),
              ListTile(
                leading: const Icon(Icons.person_add_alt_rounded),
                title: const Text('邀请注册'),
                subtitle: const Text('注册时需要邀请码'),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (register != null) await _authenticate(register: register);
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
              TextField(controller: username, autofocus: true, maxLength: 24, decoration: const InputDecoration(labelText: '账号')),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: '密码')),
              if (register) TextField(controller: invite, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: '邀请码')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
          actions: [
            TextButton(onPressed: loading ? null : () => Navigator.pop(context), child: const Text('取消')),
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
                            ? await _authClient.register(username.text.trim(), password.text, invite.text.trim())
                            : await _authClient.login(username.text.trim(), password.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext, result);
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

  Future<void> _selectPreference({required String title, required List<String> values, required bool isPersonality}) async {
    final current = isPersonality ? _preferences.personality : _preferences.topic;
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              RadioGroup<String>(
                groupValue: current,
                onChanged: (selected) => Navigator.pop(context, selected),
                child: Column(
                  children: [for (final item in values) RadioListTile<String>(value: item, title: Text(item))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (value == null) return;
    final next = CompanionPreferences(
      personality: isPersonality ? value : _preferences.personality,
      topic: isPersonality ? _preferences.topic : value,
    );
    await _store.saveCompanionPreferences(next);
    if (mounted) setState(() => _preferences = next);
  }

  Future<void> _showPrivacy() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('隐私说明'),
          content: const Text('Lumo 会妥善处理你的账号与对话数据。对话和记忆由你管理，你可以随时删除。'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
        ),
      );

  Future<void> _showLicenses() => showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开源许可', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Lumo 使用以下开源组件；许可文本由各组件的官方仓库维护。', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                const _LicenseLine(name: 'Flutter / Dart', license: 'BSD 3-Clause'),
                const _LicenseLine(name: 'flutter_animate、flutter_svg、sqflite', license: 'MIT'),
                const _LicenseLine(name: 'path、sqflite_common_ffi', license: 'BSD / MIT'),
              ],
            ),
          ),
        ),
      );

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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后再说')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络不可用，暂时无法检查更新。')));
    } on HttpException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新服务暂不可用，请稍后再试。')));
    } on FormatException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新信息无效，请稍后再试。')));
    } on Exception {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂时无法检查更新，请稍后再试。')));
    }
  }

  Future<void> _startUpdate(ReleaseUpdate update) async {
    try {
      if (!await _ensureInstallPermission() || !mounted) return;
      await _downloadUpdate(update);
    } on PlatformException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? '无法完成更新，请稍后再试。')));
    }
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('去设置')),
        ],
      ),
    );
    if (open == true) await checker.openInstallSettings();
    return false;
  }

  Future<void> _downloadUpdate(ReleaseUpdate update) async {
    final checker = UpdateChecker();
    final progress = ValueNotifier<double?>(null);
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('下载更新'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 16),
                  Text(value == null ? '正在准备下载…' : '${(value * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    try {
      final id = await checker.startDownload(update.url);
      while (mounted) {
        final status = await checker.downloadStatus(id);
        progress.value = status.progress;
        if (status.isFailed) throw PlatformException(code: 'download_failed', message: '更新下载失败（系统原因 ${status.reason ?? '未知'}）。');
        if (status.isComplete) break;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
      await checker.installDownloadedApk(id);
    } finally {
      if (dialogOpen && mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
    }
  }

  Future<void> _showAbout() => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LumoMark(size: 56),
                const SizedBox(height: 12),
                Text('Lumo', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(appVersionLabel, style: Theme.of(sheetContext).textTheme.bodyMedium),
                const SizedBox(height: 16),
                ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('检查更新'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _checkForUpdate();
                  },
                ),
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('© 2026 Lumo contributors')),
              ],
            ),
          ),
        ),
      );

  Future<void> _showPreferences() async {
    final selection = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('陪伴偏好', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _SettingsGroup(
                children: [
                  _SettingsRow(title: '陪伴性格', value: _preferences.personality, onTap: () => Navigator.pop(context, true)),
                  _SettingsRow(title: '对话主题', value: _preferences.topic, onTap: () => Navigator.pop(context, false)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    await _selectPreference(
      title: selection ? '选择全局陪伴性格' : '选择全局对话主题',
      values: selection ? const ['温柔倾听', '理性分析', '轻松鼓励'] : const ['日常放松', '情绪梳理', '自我成长'],
      isPersonality: selection,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsDetailPage(
          account: () => _account,
          personality: () => _preferences.personality,
          topic: () => _preferences.topic,
          onAccount: _showAccount,
          onPersonality: () => _selectPreference(
            title: '选择全局陪伴性格',
            values: const ['温柔倾听', '理性分析', '轻松鼓励'],
            isPersonality: true,
          ),
          onTopic: () => _selectPreference(
            title: '选择全局对话主题',
            values: const ['日常放松', '情绪梳理', '自我成长'],
            isPersonality: false,
          ),
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
        padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 32),
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
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
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
                      _account == null ? '可体验 10 条消息' : (_account!.isMember ? '永久会员' : '每日 100 条消息'),
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
              Expanded(child: _ProfileButton(label: _account == null ? '登录 / 注册' : '账号信息', onTap: _showAccount)),
              const SizedBox(width: 12),
              Expanded(child: _ProfileButton(label: '陪伴偏好', onTap: _showPreferences)),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: _ProfileShortcut(
                  icon: widget.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  label: widget.themeMode == ThemeMode.dark ? '浅色模式' : '深色模式',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onThemeModeChanged(widget.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
                  },
                ),
              ),
              Expanded(child: _ProfileShortcut(icon: Icons.shield_outlined, label: '隐私说明', onTap: _showPrivacy)),
              Expanded(child: _ProfileShortcut(icon: Icons.system_update_outlined, label: '检查更新', onTap: _checkForUpdate)),
              Expanded(child: _ProfileShortcut(icon: Icons.info_outline_rounded, label: '关于 Lumo', onTap: _showAbout)),
            ],
          ),
          const SizedBox(height: 72),
          const Center(child: LumoMark(size: 48)),
          const SizedBox(height: 14),
          Text('愿每一次陪伴都由你掌控', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
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
          child: SizedBox(height: 56, child: Center(child: Text(label, style: Theme.of(context).textTheme.titleMedium))),
        ),
      );
}

class _ProfileShortcut extends StatelessWidget {
  const _ProfileShortcut({required this.icon, required this.label, required this.onTap});

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

class _SettingsDetailPage extends StatefulWidget {
  const _SettingsDetailPage({
    required this.account,
    required this.personality,
    required this.topic,
    required this.onAccount,
    required this.onPersonality,
    required this.onTopic,
    required this.onPrivacy,
    required this.onLicenses,
    required this.onAbout,
    required this.onThemeChanged,
  });

  final AccountSession? Function() account;
  final String Function() personality;
  final String Function() topic;
  final Future<void> Function() onAccount;
  final Future<void> Function() onPersonality;
  final Future<void> Function() onTopic;
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
          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 32),
          children: [
            const _SettingsLabel('陪伴'),
            _SettingsGroup(
              children: [
                _SettingsRow(title: '陪伴性格', value: widget.personality(), onTap: () => _run(widget.onPersonality)),
                _SettingsRow(title: '对话主题', value: widget.topic(), onTap: () => _run(widget.onTopic)),
                const _SettingsRow(title: '陪伴语言', value: '中文'),
              ],
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('账号与隐私'),
            _SettingsGroup(
              children: [
                _SettingsRow(title: '账号设置', value: widget.account()?.username ?? '游客', onTap: () => _run(widget.onAccount)),
                _SettingsRow(title: '隐私说明', onTap: () => _run(widget.onPrivacy)),
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
                      widget.onThemeChanged(enabled ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
                _SettingsRow(title: '开源许可', onTap: () => _run(widget.onLicenses)),
                _SettingsRow(title: '关于 Lumo', value: appVersionLabel, onTap: () => _run(widget.onAbout)),
              ],
            ),
            if (widget.account() != null) ...[
              const SizedBox(height: 22),
              _SettingsGroup(children: [_SettingsRow(title: '退出登录', onTap: () => _run(widget.onAccount))]),
            ],
            const SizedBox(height: 42),
            Text('当前版本：$appVersionLabel', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('© 2026 Lumo contributors', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
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
                Divider(height: 1, indent: 20, endIndent: 20, color: Theme.of(context).dividerColor),
            ],
          ],
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.title, this.value, this.onTap, this.trailing});

  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 64,
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        trailing: trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: Text(value!, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (onTap != null) const SizedBox(width: 6),
                if (onTap != null) Icon(Icons.chevron_right_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          children: [Expanded(child: Text(name)), Text(license, style: Theme.of(context).textTheme.bodySmall)],
        ),
      );
}
