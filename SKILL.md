---
name: weread-bookshelf
description: 当用户要求打开或看看我的书架、打开便利贴墙、更新/刷新/同步微信读书数据、生成或初始化书架页面时使用。调用微信读书 API 获取最新数据，写入 data/weread-data.js，并打开静态 HTML 页面；不需要 Node.js、PowerShell 或额外的微信读书技能。
version: 2.1.0
---

# WeRead Bookshelf — 微信读书书架可视化

把微信读书数据生成为两个可直接打开的本地 HTML 页面：

- **我的书架**：扇形封面流 + 阅读数据（热力图、进度排行、偏好分类、最近划线）+ 猜你喜欢
- **砖 · 句子便利贴**：所有划线和想法做成便利贴墙，支持搜索、点击查看详情、双主题

页面是固定模板，数据单独放在 `data/weread-data.js`。更新数据后不需要重新生成 HTML，打开页面就是最新内容。

## 前置条件

只需要两样东西：

1. **微信读书 API Key**：环境变量 `WEREAD_API_KEY`，格式 `wrk-xxxxxxxx`
2. **网络**：取数和下载封面需要联网

不需要安装：

- Node.js / npm
- PowerShell 脚本
- Python
- `weread-skills`
- 本地 Web 服务器

Agent 需要能发 HTTP 请求和写文件。Windows 10/11、macOS、Linux 自带的 `curl` 都可以；如果运行环境有自己的 HTTP 工具，也可以直接使用。

### 配置 API Key

Windows（命令提示符）：

```bat
setx WEREAD_API_KEY "wrk-你的key"
```

macOS / Linux：

```bash
export WEREAD_API_KEY="wrk-你的key"
```

把 `export` 写进 `~/.bashrc` 或 `~/.zshrc` 可持久生效。

不要要求用户把 key 发到聊天里，不要把 key 写进 `data.js`、日志或任何仓库文件。

## 页面结构

```text
weread-bookshelf/
├── SKILL.md
├── README.md
├── 我的书架-浅色版.html      # 固定页面，不含个人数据
├── 砖墙-便利贴.html          # 固定页面，不含个人数据
└── data/                     # 个人数据（git 忽略）
    ├── weread-data.js        # 运行时数据
    ├── covers/               # 本地封面
    ├── note-heights.json     # 可选：个别便利贴固定高度
    └── title_mapping.json    # 可选：拼音书名映射
```

`data/weread-data.js` 必须是浏览器可直接执行的 JS：

```js
window.WEREAD_DATA = {
  generatedAt: "2026-10-22T06:00:00.000Z",
  stats: { totalReadTime: 554610, readDays: 145, finishedCount: 2 },
  books: [],
  notes: [],
  chapterProgress: {},
  heatmap: {},
  preferences: [],
  recommend: [],
  covers: {}
};
```

页面通过 `<script src="data/weread-data.js"></script>` 加载它。`file://` 下普通 `<script>` 可以读取本地文件，不需要 `fetch`，也不需要服务器。

## Agent 调用指引

| 用户输入 | 执行动作 |
|---------|---------|
| “打开书架”“看看我的书架”“更新数据”“刷新书架”“同步数据”“第一次使用” | 执行完整更新流程，然后打开 `我的书架-浅色版.html` |
| “打开便利贴”“看看划线” | 执行完整更新流程，然后打开 `砖墙-便利贴.html` |
| “只打开书架，不更新”“先别更新，打开看看” | 不调用 API，直接打开已有页面 |
| “封面不显示”“重新下载封面” | 检查 `data/covers/`，只重新下载缺失封面并重写 `data/weread-data.js` |
| “把页面放到 D 盘/桌面” | 连 `data/` 一起复制；不要只复制 HTML |
| “设置定时更新” | 不支持，也不要创建系统计划任务 |

**默认行为：用户说“打开书架”就是更新并打开，不是打开旧页面。**

如果更新失败：

- 核心接口失败时停止，不要覆盖上一版 `data/weread-data.js`
- 不要静默打开旧页面；先报告失败原因
- 用户明确说“打开旧页面”时再打开

如果 `WEREAD_API_KEY` 不存在，提示用户按上面的方法配置，然后停止。

## 更新流程

按顺序执行，全部成功后一次性写入 `data/weread-data.js`。

### 0. 请求约定

- 地址：`POST https://i.weread.qq.com/api/agent/gateway`
- 请求头：
  - `Authorization: Bearer $WEREAD_API_KEY`
  - `Content-Type: application/json`
- 业务参数必须**平铺在 body 顶层**，和 `api_name`、`skill_version` 同级，不要包在 `params` 里。
- `skill_version` 使用 `1.0.4`。
- 每次请求后检查 `errcode`；不为 0 时报告 `errmsg`。
- 独立接口可以并发，但同一时间最多 **3 个 API 请求在途**；每个请求的启动时间至少间隔 **200ms**（180–250ms 都可以）。不要为了快把启动间隔压到 0。
- 多页接口（`/user/notebooks`、`/review/list/mine`）的翻页按顺序执行；不同书、不同接口可以并发。
- 遇到 HTTP 429、`errcode` 提示限流或连续失败时，把并发降到 1–2，并按 1s、2s、4s 退避重试；恢复后再回到 3 路。
- 如果运行环境不支持并发，就退回串行，但仍保持 200ms 左右的请求间隔。
- 同一次更新里，相同接口和参数不要重复请求；能从上一次 `data/weread-data.js` 复用的数据优先复用（见第 3 步章节缓存）。
- `/shelf/sync`、`/user/notebooks` 失败时停止整个更新；单本书的进度、划线、想法、章节失败时记录警告并跳过。

示例：

```bash
curl -sS "https://i.weread.qq.com/api/agent/gateway" \
  -H "Authorization: Bearer $WEREAD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"api_name":"/shelf/sync","skill_version":"1.0.4"}'
```

**并发调度建议**：把 `/shelf/sync`、`/user/notebooks`、月度/总体 `/readdata/detail`、`/book/recommend` 作为第一批，用 3 路请求池同时启动；书架和笔记本返回后，再把单本书的进度、划线、想法、章节任务放入同一个请求池。第一批里除 `/shelf/sync` 和 `/user/notebooks` 外的接口失败时只记录警告，不阻断更新。

### 1. 书架

调用 `/shelf/sync`（无参数），取 `books[]`，忽略 `albums[]` 和 `mp`。

每本书生成：

```json
{
  "bookId": "书籍 ID",
  "title": "书名",
  "author": "作者",
  "cover": "封面 URL 或 data/covers/xxx.jpg",
  "progress": 0
}
```

- 按 `readUpdateTime` 降序排列。
- **进度优先复用 `/user/notebooks` 的 `readingProgress`**：有笔记的书直接用它作为 `progress`（返回 0 也有效），不要再调用 `/book/getprogress`。
- 只对“在书架上、但没有出现在 `/user/notebooks` 结果里”的书调用 `/book/getprogress`（参数 `bookId`），把回包 `book.progress` 写入 `progress`；这些请求也放进 3 路请求池。`readingProgress` 字段缺失（不是 0）时，才回退到 `/book/getprogress`。
- 如果存在 `data/title_mapping.json`，用它替换拼音书名。

### 2. 笔记

先调用 `/user/notebooks`：

```json
{"api_name":"/user/notebooks","count":100,"skill_version":"1.0.4"}
```

- 用 `count` + 顶层 `lastSort` 游标翻页；`hasMore` 为 1 时取本页最后一条 `books[].sort` 作为下一页 `lastSort`，直到 `hasMore = 0`。
- 合并所有页的 `books[]`，按 `bookId` 去重。

对每本有笔记的书：

**并发**：把每本书的 `/book/bookmarklist` 和 `/review/list/mine` 作为独立任务放进同一个 3 路请求池；不同书可以同时取。每本书的结果先存到该书自己的临时数组，最后按 `/user/notebooks` 的书顺序合并，每本书内保持“先划线、后想法”。不要按请求完成顺序直接拼接，否则便利贴墙的顺序每次更新都会变。

**跳过空请求**：`/user/notebooks` 的 `noteCount` 表示划线数量，`reviewCount` 表示想法数量。`noteCount` 为 0 时跳过 `/book/bookmarklist`；`reviewCount` 为 0 时跳过 `/review/list/mine`；字段缺失（不是 0）才发起请求。

1. 调用 `/book/bookmarklist`（参数 `bookId`）。`updated[]` 的每条划线生成：

```json
{
  "bookId": "书籍 ID",
  "title": "书名",
  "author": "作者",
  "type": "bookmark",
  "content": "markText 原文",
  "chapterUid": 123,
  "createTime": 1700000000
}
```

2. 调用 `/review/list/mine`（参数 `bookid`，注意是小写 `d`；`count` 传 100）。用回包 `synckey` 翻页直到 `hasMore = 0`。`reviews[]` 的每条想法/点评生成：

```json
{
  "bookId": "书籍 ID",
  "title": "书名",
  "author": "作者",
  "type": "thought",
  "content": "想法内容",
  "abstract": "对应的划线原文，没有就填空字符串",
  "chapterUid": 123,
  "createTime": 1700000000
}
```

- 回包元素可能是 `{ review: {...} }`，也可能直接是想法对象；两种都要兼容。
- 同样用 `title_mapping.json` 替换笔记里的书名。
- 所有笔记合并成一个**扁平数组**。

> `/book/bookmarklist` 返回的是划线（高亮），不是书签；书签内容当前接口不导出，不要混淆。

### 3. 章节与进度

**章节缓存**：先读取上一版 `data/weread-data.js` 的 `chapterProgress[bookId].chapters`。如果存在且非空，直接复用，**不要调用 `/book/chapterinfo`**；只对新增的有笔记书籍、或旧数据中没有章节缓存的书调用 `/book/chapterinfo`（参数 `bookId`），把 `chapters[]` 转成 `chapterUid → title` 的对象。章节请求也放进 3 路请求池。当前进度用本次得到的 `progress` 覆盖缓存里的旧进度；需要强制刷新某本书的章节时，删除旧数据中对应条目后重新更新。结构如下：

```json
{
  "书籍 ID": {
    "chapters": {
      "123": "第一章 标题",
      "124": "第二章 标题"
    },
    "progress": 45
  }
}
```

`chapters` 的 key 必须是字符串。进度取本次数据中同一 `bookId` 的 `progress`（有笔记的书优先用 `/user/notebooks` 的 `readingProgress`）。

### 4. 热力图、偏好与统计

月度、总体和推荐接口与书架/笔记本互不依赖，放在第一批并发请求里一起启动；不要等笔记全部取完再串行调用。

调用 `/readdata/detail`，`mode` 为 `monthly`：

```json
{"api_name":"/readdata/detail","mode":"monthly","skill_version":"1.0.4"}
```

回包 `readTimes` 是对象，key 为 Unix 时间戳（秒），value 为阅读秒数。按**本地日期**的“日”聚合（同一天有多个时间戳就相加）；如果回包跨月，只保留当前月。写入：

```json
{
  "1": 1200,
  "2": 300,
  "15": 900
}
```

key 是当月第几天，不带前导零。

再调用 `/readdata/detail`，`mode` 为 `overall`：

- `preferCategory[]` 过滤 `readingTime > 0`，按顺序循环使用颜色：
  `#b4643a, #c89b5a, #8f4a26, #d4b896, #a67c52, #e0c9a6, #b8860b, #cd853f`
- 生成 `preferences`：
  ```json
  [{"name":"文学","time":12345,"color":"#b4643a"}]
  ```
  `name` 取 `categoryTitle`，`time` 取 `readingTime`。
- 生成 `stats`：
  - `totalReadTime`：回包 `totalReadTime`（秒）
  - `readDays`：回包 `readDays`
  - `finishedCount`：书架上 `progress >= 100` 的书数

### 5. 推荐好书

调用 `/book/recommend`，参数 `count` 为 `12`。把 `books[]` 转成：

```json
[
  {
    "bookId": "书籍 ID",
    "title": "书名",
    "author": "作者",
    "category": "分类",
    "cover": "封面 URL 或 data/covers/935536.jpg",
    "intro": "简介"
  }
]
```

`bookId` 取回包里的 `bookId`；`category` 和 `intro` 缺失时填 `""`。

### 6. 封面（增量更新）

封面目录：`data/covers/`。**每次更新前先扫描目录，只下载本地没有的封面，不要每次全量重新下载。** 封面下载最多 **4 个并发**，不要一张一张串行等待；先完成 API 取数，再并发处理封面。

文件命名必须稳定：

- 所有书统一用 `<bookId>.<ext>`，例如 `data/covers/935536.jpg`
- 推荐书也用其 `bookId`；同一本书同时出现在书架和推荐里时共用一份封面
- 万一某个推荐项没有 `bookId`，不要用 `rec-序号` 复用本地文件，直接保留远程 URL，避免序号变化导致封面错配
- 扩展名按 URL 或响应 `Content-Type` 判断：`jpg` / `png` / `webp`；无法判断时用 `jpg`
- 同一 `bookId` 只保留一份文件

更新步骤：

1. 用当前书架的 `bookId`、推荐的 `bookId`，以及笔记中仍有记录但已不在书架上的 `bookId`，生成本次需要的封面集合。
2. 对每个 `bookId`，先查找 `data/covers/<bookId>.*`（任意支持的扩展名）。找到且文件大小大于 0 就直接复用，写入 `cover` 和 `covers[书名]`，**不要重新下载**；0 字节文件视为缺失。
3. 找不到时再看旧版 `data/weread-data.js` 的 `covers[书名]`：如果它指向的本地文件仍然存在，可以复用，并尽量把它重命名为 `<bookId>.<ext>`。这样旧版 `rec-XX.*` 不需要重新下载。
4. 只有以上都找不到时才下载；多个下载任务最多 4 个并发：
   ```bash
   mkdir -p data/covers
   curl -L --fail --max-time 20 "封面 URL" -o "data/covers/935536.jpg"
   ```
5. 下载失败不要中断更新：书架/推荐书的 `cover` 保留原始远程 URL，下次更新会再次尝试。
6. 对不在书架但仍有笔记的书，可以从 `/user/notebooks` 的 `book.cover` 补下载封面，保证便利贴弹窗能显示；下载失败就跳过。
7. 记录本次实际使用的所有封面文件路径（`usedCoverFiles`），**此时先不要删除任何文件**。

`covers` 的结构：

```json
{
  "书名": "data/covers/935536.jpg"
}
```

本地封面让页面离线也能显示图片。没有下载成功的书会回退到远程 URL。

#### 清理已删除书籍的封面

`data/weread-data.js` 成功写入后，扫描 `data/covers/`：

- 删除不在 `usedCoverFiles` 中的文件，包括已从书架删除且没有任何笔记引用的书，以及旧版遗留的 `rec-XX.*`
- 如果一本书已从书架删除，但便利贴里还有它的笔记，保留它的封面，供弹窗使用
- 推荐列表会轮换，旧推荐封面可能被清理、新推荐封面会重新下载；这是接口特性，保持增量逻辑即可，不要因此清空整个目录或跳过书架/笔记封面
- 不要按修改时间清理，也不要每次清空整个目录；只删除确认未被本次数据引用的文件
- 如果 `data.js` 写入失败，不要删除任何封面，保留上一版可用数据

这样书架和笔记封面正常只下载新增；推荐书轮换时会有少量新增封面，更新仍然很快。

### 7. 写 `data/weread-data.js`

把所有结果合并成一个对象，写成合法的 JS 文件：

```js
window.WEREAD_DATA = { ... };
```

注意：

- 文件编码 UTF-8，不要 BOM。
- 把 JSON 里的 `<` 替换成 `\u003c`，避免笔记内容里的 `</script>` 提前闭合页面脚本。
- 把 U+2028 / U+2029 替换成 `\u2028` / `\u2029`。
- `generatedAt` 用当前时间的 ISO 字符串。
- 先写临时文件再重命名，避免写到一半留下坏文件。
- 不要把 key 写进这个文件。
- 写入成功后，再按第 6 步的 `usedCoverFiles` 清理 `data/covers/` 中的孤儿封面；写入失败时不要清理。

笔记可以带一个可选的 `height`：

```json
{"createTime": 1788428054, "height": 250}
```

如果存在 `data/note-heights.json`，按 `createTime` 把高度附加到对应笔记：

```json
{
  "1788428054": 250,
  "1788006429": 180
}
```

没有这个文件就不加 `height`，便利贴按内容自适应。

### 8. 打开页面

更新成功后打开：

- 书架：`我的书架-浅色版.html`
- 便利贴：`砖墙-便利贴.html`

Windows 可以用：

```bat
start "" "我的书架-浅色版.html"
```

macOS / Linux 用 `open` 或 `xdg-open`。

如果页面已经开着，提醒用户刷新（F5）。

### 更新耗时

- 典型规模（25 本书、86 条笔记）本机测试：串行约 22 秒，使用本章的 3 路并发 + 进度复用 + 章节缓存 + 空请求跳过后约 7–9 秒；网络和书籍数量不同会有差异。
- 首次运行需要补章节和封面，会慢一些；后续命中章节缓存和封面增量，通常更快。
- 如果整次更新明显超过 30 秒，优先检查：是否仍然逐本串行请求、是否对每本书都重复调用了 `/book/getprogress` 或 `/book/chapterinfo`。

## 数据文件契约

| 文件 | 类型 | 说明 |
|------|------|------|
| `data/weread-data.js` | JS | 页面唯一运行时数据，顶层是 `window.WEREAD_DATA` |
| `data/covers/` | 图片 | 本地封面，路径相对于 skill 根目录 |
| `data/note-heights.json` | 对象 | 可选，`createTime → 高度` |
| `data/title_mapping.json` | 对象 | 可选，拼音书名 → 中文书名 |

旧的 `data/shelf.json`、`notes.json`、`chapter_progress.json`、`heatmap.json`、`preferences.json`、`recommend.json`、`covers_base64.json` **不再使用**。更新时直接写 `data/weread-data.js`，不要生成这些中间文件。

## 常见问题

### 页面显示“还没有书架数据”？

说明 `data/weread-data.js` 没有加载到。检查：

1. 文件是否存在
2. HTML 和 `data/` 是否还在同一目录
3. 文件是否是合法的 `window.WEREAD_DATA = {...};`

### 封面不显示？

1. 检查 `data/covers/` 下是否有对应图片
2. 检查 `data.js` 里的路径是不是 `data/covers/xxx.jpg`
3. 重新下载缺失封面并重写 `data.js`

### 导入的书显示拼音书名？

在 `data/title_mapping.json` 中配置：

```json
{
  "拼音书名": "中文书名"
}
```

更新数据时应用到书架和笔记。

### 可以在 Mac/Linux 上使用吗？

可以。取数用 `curl` 或 agent 的 HTTP 工具，页面是静态 HTML，不需要 Node 或 PowerShell。

### 为什么不生成单文件 HTML？

单文件需要把数据、封面全部嵌入 HTML，每次更新都要重写几 MB 文件。现在固定 HTML + `data.js` + 本地封面，更新只写几十 KB 数据，打开就是最新内容。

需要把页面发给别人时，连 `data/` 目录一起复制；只复制 HTML 会没有数据。

### 为什么没有定时更新？

本技能按“用户在对话中触发”设计，不注册系统定时任务。需要刷新时说“更新数据/刷新书架”。

## 安全

- `WEREAD_API_KEY` 只从环境变量读取。
- 不要硬编码、打印、提交或发送到外部服务。
- `data/` 包含个人阅读记录、笔记和封面，已在 `.gitignore` 中忽略。
- 两个 HTML 是通用模板，不包含个人数据，可以安全分发。
