import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _nickname = '微光旅人';
  String _personality = '温柔倾听';
  String _topic = '日常放松';
  TimeOfDay _reminder = const TimeOfDay(hour: 22, minute: 0);
  bool _saveHistory = true;
  bool _notifications = true;

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: _nickname);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑个人资料', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
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

  Future<void> _selectValue({
    required String title,
    required List<String> values,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final item in values)
                RadioListTile<String>(
                  value: item,
                  groupValue: current,
                  title: Text(item),
                  onChanged: (selected) => Navigator.pop(context, selected),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) onSelected(value);
  }

  Future<void> _selectReminder() async {
    final value = await showTimePicker(context: context, initialTime: _reminder);
    if (!mounted || value == null) return;
    setState(() => _reminder = value);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存？'),
        content: const Text('只会清除临时图片和演示数据，不会删除对话记录。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
  }

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
                    child: Text(
                      _nickname.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nickname, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text('ID: LUMO_20260716', style: Theme.of(context).textTheme.bodySmall),
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
            _SettingsTile(
              icon: Icons.favorite_outline_rounded,
              title: '陪伴性格',
              value: _personality,
              onTap: () => _selectValue(
                title: '选择陪伴性格',
                values: const ['温柔倾听', '理性分析', '轻松鼓励'],
                current: _personality,
                onSelected: (value) => setState(() => _personality = value),
              ),
            ),
            _SettingsTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: '对话主题',
              value: _topic,
              onTap: () => _selectValue(
                title: '选择默认话题',
                values: const ['日常放松', '情绪梳理', '自我成长'],
                current: _topic,
                onSelected: (value) => setState(() => _topic = value),
              ),
            ),
            _SettingsTile(
              icon: Icons.alarm_rounded,
              title: '提醒时间',
              value: _reminder.format(context),
              onTap: _selectReminder,
            ),
            const _SettingsTile(
              icon: Icons.translate_rounded,
              title: '陪伴语言',
              value: '中文',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.history_rounded),
              title: const Text('保存对话记录'),
              subtitle: const Text('仅保存在当前设备'),
              value: _saveHistory,
              onChanged: (value) => setState(() => _saveHistory = value),
            ),
            const _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: '数据加密',
              value: '已开启',
              valueColor: Color(0xFF4F9177),
            ),
            _SettingsTile(
              icon: Icons.policy_outlined,
              title: '隐私说明',
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('隐私说明'),
                  content: const Text('Lumo 演示版不会上传对话内容。接入在线服务前，应补充账号、存储期限和数据删除说明。'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
                ),
              ),
            ),
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
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('通知推送'),
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
            ),
            _SettingsTile(icon: Icons.cleaning_services_outlined, title: '清除缓存', onTap: _clearCache),
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
          if (i != children.length - 1)
            Divider(height: 1, indent: 56, endIndent: 16, color: Theme.of(context).dividerColor),
        ],
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    leading: Icon(icon),
    title: Text(title),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(
            value!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor),
          ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded),
      ],
    ),
    onTap: onTap,
  );
}
