# WeRead Bookshelf — 微信读书书架可视化

将你的微信读书数据生成为精美的本地 HTML 页面，离线可用。

## ✨ 功能特点

### 📚 我的书架页面
- 扇形封面流（Coverflow 效果），按微信读书书架顺序排列
- 阅读热力图（本月每日阅读时长）
- 阅读进度排行榜
- 阅读偏好分类（环形图）
- 最近划线展示
- 猜你喜欢（个性化推荐）
- 小猫萌宠动画（走路、睡觉、玩球）

### 📝 砖墙便利贴页面
- 所有划线和想法做成便利贴墙
- 莫兰迪配色，不规则排列
- 支持搜索（按书名或句子）
- 点击便利贴查看详情（书籍封面、章节、进度、划线日期）
- 小猫萌宠动画

## 🖼️ 截图

> 在此处添加截图

## 🚀 快速开始

### 1. 前置条件

- Windows 系统（PowerShell 5.1+）
- 微信读书 API Key

### 2. 配置 API Key

打开 PowerShell，运行：

```powershell
[Environment]::SetEnvironmentVariable("WEREAD_API_KEY", "wrk-你的APIKey", "User")
```

设置后重启终端生效。

### 3. 生成页面

```powershell
# 进入 skill 目录
cd weread-bookshelf

# 一键生成（默认输出到当前目录）
.\scripts\update.ps1

# 或指定输出目录
.\scripts\update.ps1 -OutputDir "D:\我的书架"
```

自动完成：获取书架数据 → 下载封面 → 获取笔记 → 生成页面 → 打开浏览器。

## ⚙️ 定时自动更新

注册每天早上 6:00 自动更新：

```powershell
.\scripts\setup_task.ps1 -TaskAction register
```

管理定时任务：

```powershell
.\scripts\setup_task.ps1 -TaskAction status     # 查看状态
.\scripts\setup_task.ps1 -TaskAction disable    # 暂停
.\scripts\setup_task.ps1 -TaskAction enable     # 恢复
.\scripts\setup_task.ps1 -TaskAction unregister # 删除
```

## 📖 使用说明

### 书架页面
- 左右滑动或点击切换书籍
- 顶部导航可跳转到对应区域
- 点击"便利贴墙"按钮跳转到便利贴页面

### 便利贴页面
- 搜索框输入书名或句子，按回车搜索
- 点击任意便利贴查看详情
- 左上角"返回书架"按钮返回

## 🔧 高级配置

### 拼音书名映射

微信读书 API 对用户导入的私有书只返回拼音书名。可在 `data/title_mapping.json` 中手动配置：

```json
{
  "拼音书名": "中文书名"
}
```

配置后重新运行 `update.ps1` 即可。

## 📁 目录结构

```
weread-bookshelf/
├── README.md                   # 本文件
├── SKILL.md                    # Skill 说明文档（供 Agent 读取）
├── .gitignore                  # Git 忽略规则
├── scripts/
│   ├── update.ps1              # 一键更新（数据+封面+页面）
│   ├── fetch_data.ps1          # 获取微信读书数据
│   ├── download_covers.ps1     # 下载封面并转 base64
│   ├── generate_pages.ps1      # 生成 HTML 页面
│   └── setup_task.ps1          # 定时任务管理
├── templates/
│   ├── bookshelf.template.html # 书架页面模板
│   └── stickywall.template.html # 便利贴页面模板
├── data/                       # 缓存数据（自动生成，已忽略）
└── *.html                      # 生成的页面（已忽略）
```

## ❓ 常见问题

**Q: 页面打开是空白？**
A: 检查浏览器控制台是否有 JS 错误，通常是数据文件缺失，重新运行 `update.ps1` 即可。

**Q: 导入的书显示拼音书名？**
A: 见上方"拼音书名映射"配置。

**Q: 想法内容为空？**
A: 确保使用最新版本脚本，旧版本可能存在字段层级问题。

**Q: 可以在 Mac/Linux 上运行吗？**
A: 当前脚本是 PowerShell 写的，仅支持 Windows。如需跨平台可考虑改写为 Python 或 Node.js。

## 📄 数据来源

通过微信读书 Agent API Gateway 获取：
- `/shelf/sync` — 书架书籍列表
- `/book/getprogress` — 每本书阅读进度
- `/user/notebooks` — 有笔记的书籍
- `/book/bookmarklist` — 划线内容
- `/review/list/mine` — 想法/点评
- `/book/chapterinfo` — 章节目录
- `/readdata/detail` — 阅读统计和偏好
- `/book/recommend` — 推荐好书

## 📝 License

MIT
