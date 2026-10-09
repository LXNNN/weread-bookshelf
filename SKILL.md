---
name: weread-bookshelf
description: 微信读书书架可视化 — 生成个人书架展示页面和划线句子便利贴墙，支持手动/定时自动更新数据，离线可用
version: 1.0.0
---

# WeRead Bookshelf — 微信读书书架可视化

将你的微信读书数据生成为精美的本地 HTML 页面：
- **我的书架**：扇形封面流 + 阅读数据（热力图/进度排行/偏好分类/最近划线）+ 猜你喜欢
- **砖墙便利贴**：所有划线和想法做成便利贴墙，可搜索、点击查看详情

## 前置条件

### 1. 微信读书 API Key
需要设置环境变量 `WEREAD_API_KEY`，格式 `wrk-xxxxxxxx`。

**Windows 设置方法（PowerShell 管理员）：**
```powershell
[Environment]::SetEnvironmentVariable("WEREAD_API_KEY", "wrk-你的key", "User")
```
设置后重启终端/应用生效。

### 2. 运行环境
- Windows 系统（PowerShell 5.1+）
- 不需要安装额外软件，所有脚本用 Windows 自带工具

## 快速开始

### 首次生成
```powershell
# 在 skill 目录下运行，默认输出到 skill 目录
.\scripts\update.ps1

# 指定输出目录
.\scripts\update.ps1 -OutputDir "D:\我的书架"
```
自动完成：获取书架数据 → 下载封面 → 获取笔记 → 生成页面 → 打开浏览器。

### 手动更新数据
```powershell
.\scripts\update.ps1              # 默认输出到 skill 目录
.\scripts\update.ps1 -OutputDir "D:\我的书架"  # 指定输出目录
```

### 注册定时自动更新（每天早上 6:00）
```powershell
.\scripts\setup_task.ps1 -Action register
```

### 管理定时任务
```powershell
.\scripts\setup_task.ps1 -TaskAction status    # 查看状态
.\scripts\setup_task.ps1 -TaskAction disable   # 暂停
.\scripts\setup_task.ps1 -TaskAction enable    # 恢复
.\scripts\setup_task.ps1 -TaskAction unregister # 删除
```

## 目录结构

```
weread-bookshelf/
├── SKILL.md                    # 本文件
├── scripts/
│   ├── update.ps1              # 一键更新（数据+封面+页面）
│   ├── fetch_data.ps1          # 获取微信读书数据
│   ├── download_covers.ps1     # 下载封面并转 base64
│   ├── generate_pages.ps1      # 生成 HTML 页面
│   └── setup_task.ps1          # 定时任务管理
├── templates/
│   ├── bookshelf.template.html # 书架页面模板
│   └── stickywall.template.html # 便利贴页面模板
├── data/                       # 缓存数据（自动生成）
│   ├── shelf.json
│   ├── notes.json
│   ├── covers_base64.json
│   └── chapter_progress.json
├── 我的书架-浅色版.html          # 生成的页面
└── 砖墙-便利贴.html              # 生成的页面
```

## 数据来源

通过微信读书 Agent API Gateway 获取：
- `/shelf/sync` — 书架书籍列表
- `/book/getprogress` — 每本书阅读进度
- `/user/notebooks` — 有笔记的书籍
- `/book/bookmarklist` — 划线内容
- `/review/list/mine` — 想法/点评
- `/book/chapterinfo` — 章节目录

## 输出说明

- 默认生成的 HTML 页面在 skill 根目录下
- 可通过 `-OutputDir` 参数指定输出目录，目录不存在会自动创建
- 所有封面和数据内嵌到 HTML 中，**离线可打开**
- 书架页面点击"便利贴墙"按钮可跳转
- 便利贴页面左上角有"返回书架"按钮

## Agent 调用指引

当用户说以下内容时，调用对应脚本：

| 用户输入 | 执行命令 |
|---------|---------|
| "生成我的书架"、"初始化书架"、"第一次使用" | `scripts\update.ps1` |
| "更新数据"、"刷新书架"、"同步数据" | `scripts\update.ps1` |
| "把页面生成到 D 盘"、"输出到指定文件夹" | `scripts\update.ps1 -OutputDir "用户指定的路径"` |
| "打开书架"、"看看我的书架" | 直接打开 `我的书架-浅色版.html` |
| "打开便利贴"、"看看划线" | 直接打开 `砖墙-便利贴.html` |
| "设置定时更新"、"每天自动更新" | `scripts\setup_task.ps1 -TaskAction register` |
| "暂停自动更新" | `scripts\setup_task.ps1 -TaskAction disable` |
| "恢复自动更新" | `scripts\setup_task.ps1 -TaskAction enable` |
| "查看更新状态" | `scripts\setup_task.ps1 -TaskAction status` |
| "删除定时任务" | `scripts\setup_task.ps1 -TaskAction unregister` |

执行 `update.ps1` 前检查 `WEREAD_API_KEY` 环境变量是否存在，不存在则提示用户配置。如果用户指定了输出目录，通过 `-OutputDir` 参数传递。

## 常见问题

### 导入的书显示拼音书名？
微信读书 API 对用户导入的私有书只返回拼音书名。可以在 `data/title_mapping.json` 中手动配置映射：
```json
{
  "拼音书名": "中文书名"
}
```
配置后重新运行 `update.ps1` 即可。
