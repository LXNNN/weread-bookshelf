# WeRead Bookshelf — 微信读书书架可视化

把微信读书数据生成为两个可直接打开的本地 HTML 页面，离线可用。页面与数据分离：HTML 是固定模板，更新时只写 `data/weread-data.js` 和封面，不需要重新生成页面。

## ✨ 功能特点

- 固定 HTML 模板 + 独立数据文件，无需 Node.js、PowerShell 或本地服务器
- 封面按 `bookId` 增量更新，已有封面不会重复下载
- 页面与数据均可离线使用

### 📚 我的书架页面
- 扇形封面流（Coverflow 效果）
- 阅读热力图（本月每日阅读时长）
- 阅读进度排行榜
- 阅读偏好分类（环形图）
- 最近划线展示
- 猜你喜欢（个性化推荐）
- 总阅读时长、阅读天数、已读完数量
- 小猫萌宠动画

### 📝 砖 · 句子便利贴页面
- 所有划线和想法做成便利贴墙
- 高饱和配色，紧凑瀑布流，多种便利贴形状、图钉、胶带与纸张纹理
- 可切换莫兰迪 / 高饱和主题（默认高饱和，选择会记住）
- 支持搜索（书名、作者或句子）
- 点击便利贴查看详情（书籍封面、章节、进度、划线日期）
- 小猫萌宠动画

## 🖼️ 截图

<img width="2160" height="1187" alt="image" src="https://github.com/user-attachments/assets/d30ee766-dc58-4541-8059-e6db995a52bc" />
<img width="2160" height="1187" alt="image" src="https://github.com/user-attachments/assets/f7cba545-d3dd-46ec-9ef6-74e8f01b54c7" />


## 🚀 快速开始

### 1. 前置条件

只需要：

- 微信读书 API Key（环境变量 `WEREAD_API_KEY`）
- 网络

**不需要安装 Node.js、npm、Python、PowerShell 脚本、`weread-skills` 或本地服务器。**

### 2. 配置 API Key

Windows（命令提示符）：

```bat
setx WEREAD_API_KEY "wrk-你的APIKey"
```

macOS / Linux：把下面一行写进 `~/.bashrc` 或 `~/.zshrc`：

```bash
export WEREAD_API_KEY="wrk-你的APIKey"
```

设置后重开终端生效。不要把 key 写进仓库或发到聊天中。

### 3. 安装技能

下载或克隆本仓库，把整个 `weread-bookshelf` 目录放到 agent 的技能目录。常见位置：

- 通用 Agent Skills：`~/.agents/skills/weread-bookshelf`
- Claude Code：`~/.claude/skills/weread-bookshelf`
- Windows：`%USERPROFILE%\.agents\skills\weread-bookshelf`

也可以直接克隆到技能目录：

```bash
git clone https://github.com/LXNNN/weread-bookshelf.git ~/.agents/skills/weread-bookshelf
```

目录中至少要有 `SKILL.md` 和两个 HTML 页面；`data/` 会在第一次更新时自动创建，不需要手动准备。安装后重启 agent，或按所用 agent 的方式重新加载技能。

### 4. 使用

在 agent 对话中直接说：

> 打开书架

agent 会：

1. 调用微信读书 API 获取最新数据
2. 对比 `data/covers/` 与当前书架，只下载新增书籍的封面
3. 写入 `data/weread-data.js`，并清理已删除且没有笔记引用的封面
4. 打开 `我的书架-浅色版.html`

说 **“打开便利贴”** 会更新数据并打开便利贴页面。  
说 **“只打开书架，不更新”** 则直接打开现有页面。

## 🧩 它是怎么工作的

两个 HTML 是固定模板，不包含个人数据。页面通过：

```html
<script src="data/weread-data.js"></script>
```

加载本地数据文件。更新时只写 `data/weread-data.js` 和封面，不需要重新生成 HTML，也不需要任何构建工具。

首次使用或数据文件缺失时，页面会显示提示，而不会白屏。

### 封面增量更新

封面统一按 `bookId` 命名（如 `data/covers/935536.jpg`），书架和推荐共用同一份文件。每次更新时：

1. 先扫描 `data/covers/`，已有且非空的封面直接复用，不重新下载。
2. 只下载本地没有的新书封面；下载失败会保留远程 URL，下次只重试缺失项。
3. 旧版 `data/weread-data.js` 里的 `covers[书名]` 如果指向仍然存在的本地文件，会复用并尽量重命名为 `<bookId>.<ext>`，因此旧版 `rec-XX` 封面不需要重新下载。
4. `data.js` 写入成功后，删除已经从书架消失、且没有任何笔记引用的封面；如果便利贴里还有这本书的笔记，封面会保留。
5. `data.js` 写入失败时不会删除任何封面，避免破坏上一版可用数据。

## 📁 目录结构

```text
weread-bookshelf/
├── README.md
├── SKILL.md                    # 给 agent 的接口与更新说明
├── 我的书架-浅色版.html         # 固定页面
├── 砖墙-便利贴.html             # 固定页面
└── data/                       # 个人数据（git 忽略）
    ├── weread-data.js          # 页面运行时数据
    ├── covers/                 # 本地封面
    ├── note-heights.json       # 可选：个别便利贴固定高度
    └── title_mapping.json      # 可选：拼音书名映射
```

页面必须和 `data/` 目录放在一起。只复制 HTML 会没有数据、没有封面。

## ❓ 常见问题

**Q: 页面显示“还没有书架数据”？**  
A: `data/weread-data.js` 没有加载到。确认 HTML 和 `data/` 在同一目录，并且文件内容是合法的 `window.WEREAD_DATA = {...};`。

**Q: 封面不显示？**  
A: 检查 `data/covers/` 下是否有对应图片；如果某张封面下载失败，页面会回退到远程 URL，需要联网才能看到。下次说“打开书架”只会重试缺失的封面，不会重新下载已有封面。

**Q: 导入的书显示拼音书名？**  
A: 在 `data/title_mapping.json` 中配置：

```json
{
  "拼音书名": "中文书名"
}
```

然后让 agent 重新更新数据。

**Q: 可以在 Mac/Linux 上使用吗？**  
A: 可以。取数用 `curl` 或 agent 的 HTTP 工具，页面是静态 HTML，不需要 Node 或 PowerShell。

**Q: 为什么没有定时自动更新？**  
A: 本技能按“对话中触发”设计，不注册系统计划任务。需要刷新时说“更新数据/刷新书架”。

**Q: 怎么调整某张便利贴的高度？**  
A: 在 `data/note-heights.json` 里按 `createTime` 配置高度，然后让 agent 重新更新数据。没有配置的便利贴按内容自适应。

## 📄 数据来源

通过微信读书 Agent API Gateway 获取：

- `/shelf/sync` — 书架书籍列表
- `/book/getprogress` — 阅读进度
- `/user/notebooks` — 有笔记的书籍
- `/book/bookmarklist` — 划线内容
- `/review/list/mine` — 想法/点评
- `/book/chapterinfo` — 章节目录
- `/readdata/detail` — 阅读统计和偏好
- `/book/recommend` — 推荐好书

接口参数、分页和字段说明见 `SKILL.md`。

## 📝 License

MIT
