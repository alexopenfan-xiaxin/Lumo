# Lumo

Lumo 是一款以“情绪微光”为视觉语言的 Flutter Android 情感陪伴应用。项目包含公告、智能体会话、智能体探索、个人中心和完整的演示交互。

## 功能

- 公告与活动详情、未读提醒
- 智能体搜索、对话列表与本地演示聊天
- 分类探索、智能体介绍与 Hero 转场
- 个人中心、深色模式、陪伴偏好、账号、隐私与版本信息
- 降低动态效果支持、语义标签与 Android 安全区适配
- Cloudflare 智能体管理台：新建、编辑、上下线和邀请码管理

## 智能体管理

Pages 首页是管理台，使用 `accounts.role = 'admin'` 的 Lumo 账号登录。智能体配置保存在现有 D1 `lumo-auth` 的 `agents` 表；公开 `/agents` 接口只下发展示字段，身份提示词只在 Worker 内使用。

头像可填 HTTPS 图片地址，留空则显示文字头像；不依赖 R2。首次升级 App 后，后续新增或修改智能体无需再发版。

## 运行

本仓库的项目规则禁止在当前机器执行 Flutter/Dart 命令。请在已安装 Flutter stable 与 Android SDK 的其他环境中运行：

```bash
flutter pub get
flutter run
```

推送到 GitHub 后，Actions 会远程执行依赖解析、静态分析、测试和 Debug APK 构建。

## 设计与资源

- 设计规范：`design-system/lumo/MASTER.md`
- 管理台规范：`design-system/lumo/pages/admin.md`
- 主视觉：项目专属 AI 生成图，无文字和水印
- 图标与品牌光环：SVG / Material Symbols
- 标题字：ZCOOL XiaoWei（SIL Open Font License）

## License

MIT。字体许可见 `assets/fonts/OFL.txt`。
