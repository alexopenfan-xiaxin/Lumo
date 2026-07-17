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
    title: '智能体性格系统升级',
    description: '所有陪伴者新增了共情能力，对话更自然。',
    detail: '现在，陪伴者会更准确地理解你的语气和情绪线索，并延续上一段对话的上下文。你仍然可以在设置中随时调整陪伴性格。',
    time: '2小时前',
    color: LumoColors.clay,
    icon: Icons.auto_awesome_rounded,
  ),
  NoticeItem(
    tag: '活动',
    title: '七日微光计划',
    description: '每天留一分钟给自己，完成温和的情绪练习。',
    detail: '连续七天完成一次情绪签到或短时冥想，即可生成一份只保存在本机的情绪回顾。中断也没有关系，照顾自己不是比赛。',
    time: '今天 10:00',
    color: LumoColors.fogBlue,
    icon: Icons.wb_twilight_rounded,
  ),
  NoticeItem(
    tag: '通知',
    title: '服务维护通知',
    description: '7月18日凌晨 2:00–4:00 暂停在线服务。',
    detail: '维护期间，已有对话仍可在本机查看，但无法发送新消息。维护结束后无需更新应用。',
    time: '昨天',
    color: Color(0xFF927C6B),
    icon: Icons.schedule_rounded,
  ),
  NoticeItem(
    tag: '新功能',
    title: '语音陪伴上线',
    description: '现在可以用更自然的方式说出此刻感受。',
    detail: '进入任意对话，点击输入框右侧的麦克风即可开始。首次使用时，Android 会询问麦克风权限。语音不会在未确认时发送。',
    time: '3天前',
    color: LumoColors.positive,
    icon: Icons.mic_none_rounded,
  ),
];

String categoryLabel(CompanionCategory category) => switch (category) {
  CompanionCategory.all => '全部',
  CompanionCategory.listener => '情感倾听',
  CompanionCategory.meditation => '冥想引导',
  CompanionCategory.counselor => '心理咨询',
  CompanionCategory.life => '生活陪伴',
};
