# Lumo

Lumo 是一款以“情绪微光”为视觉语言的 Flutter Android 情感陪伴应用。项目基于四页设计稿重构，包含公告、智能体会话、智能体探索、个性化设置和完整的演示交互。

## 功能

- 公告与活动详情、未读提醒
- 智能体搜索、对话列表与本地演示聊天
- 分类探索、智能体介绍与 Hero 转场
- 深色模式、提醒时间、陪伴性格、通知和隐私设置
- 降低动态效果支持、语义标签与 Android 安全区适配

## 运行

本仓库的项目规则禁止在当前机器执行 Flutter/Dart 命令。请在已安装 Flutter stable 与 Android SDK 的其他环境中运行：

```bash
flutter pub get
flutter run
```

推送到 GitHub 后，Actions 会远程执行依赖解析、静态分析、测试和 Debug APK 构建。

## 设计与资源

- 设计规范：`design-system/lumo/MASTER.md`
- 主视觉：项目专属 AI 生成图，无文字和水印
- 图标与品牌光环：SVG / Material Symbols
- 标题字：ZCOOL XiaoWei（SIL Open Font License）

## License

MIT。字体许可见 `assets/fonts/OFL.txt`。

