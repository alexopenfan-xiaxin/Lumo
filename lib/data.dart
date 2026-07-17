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
  final int unread;
}

const companions = <Companion>[
  Companion(
    id: 'warm-light',
    name: '暖时光',
    glyph: '暖',
    tagline: '温柔的倾听者，永远在你身边',
    category: CompanionCategory.listener,
    color: LumoColors.clay,
    people: '12.5万人正在陪伴',
    lastMessage: '好的，今晚试试深呼吸放松…',
    lastTime: '14:32',
    openingMessage: '我在。今天有什么想慢慢说给我听的？',
    unread: 2,
  ),
  Companion(
    id: 'stillness',
    name: '静心',
    glyph: '静',
    tagline: '正念冥想引导，帮你找到内心平静',
    category: CompanionCategory.meditation,
    color: Color(0xFF5FAE82),
    people: '8.3万人正在使用',
    lastMessage: '今天冥想感觉怎么样？',
    lastTime: '12:15',
    openingMessage: '先把肩膀放松。我们用一分钟，听一听此刻的呼吸。',
  ),
  Companion(
    id: 'starlight',
    name: '星光',
    glyph: '星',
    tagline: '专业的心理分析，深度了解自己',
    category: CompanionCategory.counselor,
    color: LumoColors.fogBlue,
    people: '5.1万人正在咨询',
    lastMessage: '周末要不要一起做个情绪小练习？',
    lastTime: '昨天',
    openingMessage: '欢迎回来。我们可以从最近反复出现的一个念头开始。',
  ),
  Companion(
    id: 'joy',
    name: '悦己',
    glyph: '悦',
    tagline: '专注于自我成长和习惯养成',
    category: CompanionCategory.life,
    color: Color(0xFFCE756B),
    people: '6.8万人一起成长',
    lastMessage: '你今天的小满足记录了吗？',
    lastTime: '周一',
    openingMessage: '今天不追求满分。选一件做完会让你轻松一点的小事吧。',
    unread: 1,
  ),
  Companion(
    id: 'morning',
    name: '晨曦',
    glyph: '晨',
    tagline: '清爽的生活陪练，陪你开启新一天',
    category: CompanionCategory.life,
    color: LumoColors.gold,
    people: '3.9万人今天已打卡',
    lastMessage: '早安，新的一天开始了',
    lastTime: '7/10',
    openingMessage: '早安。今天最值得优先照顾的，是你的哪一种感受？',
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

