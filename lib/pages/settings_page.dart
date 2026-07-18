import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../auth_client.dart';
import '../chat_store.dart';
import '../update_checker.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.themeMode, required this.onThemeModeChanged, super.key});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
      showDragHandle: true,
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
        showDragHandle: true,
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
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final result = await UpdateChecker().downloadAndInstall(update.url);
                  messenger.showSnackBar(
                    SnackBar(content: Text(result == 'permission_required' ? '请允许 Lumo 安装未知应用后，再到“关于 Lumo”中检查。' : '更新开始下载，完成后将打开安装器。')),
                  );
                } on PlatformException catch (error) {
                  try {
                    await UpdateChecker().openInBrowser(update.url);
                    messenger.showSnackBar(const SnackBar(content: Text('系统下载服务不可用，已在浏览器中打开 APK 下载。')));
                  } on PlatformException {
                    messenger.showSnackBar(SnackBar(content: Text(error.message ?? '无法开始下载，请稍后再试。')));
                  }
                }
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

  Future<void> _showAbout() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
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

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('settings-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '设置', subtitle: '让陪伴更贴近你的习惯'),
          const SizedBox(height: 22),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _showAccount,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(_account?.username.substring(0, 1).toUpperCase() ?? '游', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_account?.username ?? '游客用户', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 3),
                          Text(
                            _account == null ? '可体验 10 条消息' : (_account!.isMember ? '永久会员' : '每日 100 条消息'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsCard(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text('全局陪伴偏好'),
              ),
              _SettingsTile(
                icon: Icons.favorite_outline_rounded,
                title: '陪伴性格',
                value: _preferences.personality,
                onTap: () => _selectPreference(title: '选择全局陪伴性格', values: const ['温柔倾听', '理性分析', '轻松鼓励'], isPersonality: true),
              ),
              _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: '对话主题',
                value: _preferences.topic,
                onTap: () => _selectPreference(title: '选择全局对话主题', values: const ['日常放松', '情绪梳理', '自我成长'], isPersonality: false),
              ),
              const _SettingsTile(icon: Icons.translate_rounded, title: '陪伴语言', value: '中文'),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsCard(
            children: [
              _SettingsTile(icon: Icons.policy_outlined, title: '隐私说明', onTap: _showPrivacy),
              _SettingsTile(icon: Icons.gavel_outlined, title: '开源许可', onTap: _showLicenses),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('深色模式'),
                value: widget.themeMode == ThemeMode.dark,
                onChanged: (enabled) {
                  HapticFeedback.selectionClick();
                  widget.onThemeModeChanged(enabled ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: '关于 Lumo',
                value: appVersionLabel,
                onTap: _showAbout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) Divider(height: 1, indent: 56, endIndent: 16, color: Theme.of(context).dividerColor),
            ],
          ],
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.value, this.onTap});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 56,
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) Text(value!, style: Theme.of(context).textTheme.bodyMedium),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
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
