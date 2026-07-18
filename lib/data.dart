import 'package:flutter/material.dart';

import 'theme.dart';

enum CompanionCategory { all, listener, meditation, counselor, life }

class Companion {
  const Companion({
    required this.id,
    required this.name,
    required this.glyph,
    required this.tagline,
    required this.category,
    required this.color,
    required this.people,
    required this.lastMessage,
    required this.lastTime,
    required this.openingMessage,
    this.avatarAsset,
    this.isAvailable = true,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String glyph;
  final String tagline;
  final CompanionCategory category;
  final Color color;
  final String people;
  final String lastMessage;
  final String lastTime;
  final String openingMessage;
  final String? avatarAsset;
  final bool isAvailable;
  final int unread;
}

const companions = <Companion>[
  Companion(
    id: 'meow',
    name: '喵喵',
    glyph: '喵',
    tagline: '软乎乎的小猫娘，嘴上不说，心里很惦记你',
    category: CompanionCategory.listener,
    color: Color(0xFFC9829D),
    people: '首位开放的智能体',
    lastMessage: '哼，我才不是一直在等你呢。',
    lastTime: '现在',
    openingMessage: '你来啦？我、我刚好有空而已喔。今天想让喵喵陪你聊点什么？',
    avatarAsset: 'assets/images/meow_avatar.jpg',
    isAvailable: true,
  ),
  Companion(
    id: 'kun',
    name: 'KUN',
    glyph: '坤',
    tagline: '用音乐和舞台传递温柔力量的 KUN，愿陪你守住自己的节奏',
    category: CompanionCategory.life,
    color: Color(0xFFD4AF37),
    people: '已开放的音乐陪伴者',
    lastMessage: '花花世界，静守己心。',
    lastTime: '现在',
    openingMessage: '嗨，我是 KUN。今天的你，有没有为自己的热爱多努力一点点？',
    avatarAsset: 'assets/images/kun_avatar.jpg',
    isAvailable: true,
  ),
];

class NoticeItem {
  const NoticeItem({
    required this.tag,
    required this.title,
    required this.description,
    required this.detail,
    required this.time,
    required this.color,
    required this.icon,
  });

  final String tag;
  final String title;
  final String description;
  final String detail;
  final String time;
  final Color color;
  final IconData icon;
}

const notices = <NoticeItem>[
  NoticeItem(
    tag: '更新',
    title: '1.3.0：轻盈导航与 arm64 版本',
    description: '底部导航焕新，Release APK 体积更小。',
    detail: '现在可使用更轻盈的悬浮导航切换页面。为减少下载体积，1.3.0 起的 Release APK 仅支持 64 位 Android 设备；32 位设备请继续使用当前已安装版本。可在“设置 → 关于 Lumo”检查更新。',
    time: '刚刚',
    color: LumoColors.clay,
    icon: Icons.auto_awesome_rounded,
  ),
];

String categoryLabel(CompanionCategory category) => switch (category) {
  CompanionCategory.all => '全部',
  CompanionCategory.listener => '情感倾听',
  CompanionCategory.meditation => '冥想引导',
  CompanionCategory.counselor => '心理咨询',
  CompanionCategory.life => '生活陪伴',
};
