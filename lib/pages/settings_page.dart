import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
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
  String _nickname = '微光旅人';
  CompanionPreferences _preferences = const CompanionPreferences(
    personality: CompanionPreferences.defaultPersonality,
    topic: CompanionPreferences.defaultTopic,
  );

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await _store.companionPreferences();
    if (mounted) setState(() => _preferences = preferences);
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: _nickname);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑个人资料', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: controller, autofocus: true, maxLength: 20, decoration: const InputDecoration(labelText: '昵称')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(context, value);
                },
                child: const Text('保存资料'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted || saved == null) return;
    HapticFeedback.lightImpact();
    setState(() => _nickname = saved);
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
          content: const Text(
            'Lumo 会将会话、摘要和你确认的记忆保存在这台设备的本地数据库中。\n\n发送消息时，当前所需上下文会通过 Cloudflare Pages 转发给 SenseNova 生成回复；不会创建账号或进行云端会话同步。你可以在每个智能体的对话信息中分别清空会话和记忆。',
          ),
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
              onTap: _editProfile,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(_nickname.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(_nickname, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text('ID: LUMO_20260716', style: Theme.of(context).textTheme.bodySmall)],
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
                value: '1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Lumo',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 Lumo contributors',
                  applicationIcon: const LumoMark(size: 52),
                ),
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
