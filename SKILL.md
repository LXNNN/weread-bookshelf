---
name: weread-bookshelf
description: 打开或更新微信读书书架首页；按书名打开单本书的便利贴墙。更新书架只拉首页数据，不拉划线句子和想法；单本便利贴按需拉取并写入独立数据文件。不需要 Node.js、PowerShell 或额外的微信读书技能。
version: 3.1.0
---

# WeRead Bookshelf — 微信读书书架可视化

把微信读书数据生成为两个可直接打开的本地 HTML 页面：

- **我的书架**：扇形封面流 + 阅读数据（热力图、进度排行、偏好分类、最近在读）+ 猜你喜欢
- **砖墙 · 句子便利贴**：**单本书**的划线和想法便利贴墙，支持划线/想法切换、点击查看详情、双主题

首页和笔记数据是分开的：

- `data/shelf.js`：首页数据，**不含任何划线或想法正文**
- `data/books/<bookId>.js`：单本书的笔记数据，**按需生成**

打开或更新书架时，**不会拉取任何书的划线句子和想法**。只有用户明确要求打开某本书的便利贴墙时，才拉取那一本书。

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

不要要求用户把 key 发到聊天里，不要把 key 写进数据文件、日志或任何仓库文件。

## 页面结构

```text
weread-bookshelf/
├── SKILL.md
├── README.md
├── 我的书架-浅色版.html      # 固定页面，读取 data/shelf.js
├── 砖墙-便利贴.html          # 单本模板，读取 ?bookId= 和 data/books/<bookId>.js
└── data/                     # 个人数据（git 忽略）
    ├── shelf.js              # 首页数据
    ├── books/
    │   └── <bookId>.js       # 单本数据，按需生成
    ├── covers/               # 本地封面
    └── title_mapping.json    # 可选：拼音书名映射
```

`data/shelf.js` 必须是浏览器可直接执行的 JS：

```js
window.WEREAD_SHELF = {
  generatedAt: "2026-11-10T06:00:00.000Z",
  stats: { totalReadTime: 554610, readDays: 145, finishedCount: 2 },
  books: [
    {
      bookId: "书籍 ID",
      title: "书名",
      author: "作者",
      cover: "data/covers/935536.jpg",
      progress: 28,
      readUpdateTime: 1792941988,
      finishReading: 0,
      noteCount: 60,
      reviewCount: 3,
      intro: "最近在读这本书的简介"
    }
  ],
  heatmap: {},
  preferences: [],
  recommend: []
};
```

`noteCount` 是划线条数，`reviewCount` 是想法/点评条数，来自 `/user/notebooks` 概览。它们用于打开单本墙前的 5000 条预检；没有笔记的书可以填 0。

`intro` 是可选字段，只给首页“最近在读”那一本填，用于卡片展示简介；其他书不需要为了这个字段逐本请求 `/book/info`。

**`shelf.js` 里不要放 `notes`、`chapterProgress`。** 笔记属于单本数据。

单本数据 `data/books/<bookId>.js`：

```js
window.WEREAD_BOOK = {
  schemaVersion: 1,
  generatedAt: "2026-11-10T06:00:00.000Z",
  book: {
    bookId: "书籍 ID",
    title: "书名",
    author: "作者",
    cover: "data/covers/935536.jpg",
    progress: 28
  },
  chapters: {
    "123": "第一章 标题",
    "124": "第二章 标题"
  },
  notes: [
    {
      bookId: "书籍 ID",
      title: "书名",
      author: "作者",
      type: "bookmark",
      content: "划线原文",
      chapterUid: 123,
      createTime: 1700000000
    },
    {
      bookId: "书籍 ID",
      title: "书名",
      author: "作者",
      type: "thought",
      content: "想法内容",
      abstract: "对应的划线原文，没有就填空字符串",
      chapterUid: 123,
      createTime: 1700000000
    }
  ],
  totalNotes: 123,
  truncated: false
};
```

- `type` 只有 `bookmark`（划线）和 `thought`（想法）两种。
- `truncated: true` 表示原书超过单本上限，只保留了抽样后的数据。
- 单本模板通过动态 `<script src="data/books/<bookId>.js">` 加载；`file://` 下不要用 `fetch`。

旧的 `data/weread-data.js` **不再使用**。升级后第一次执行「打开书架」会生成 `data/shelf.js`；单本数据在第一次打开某本书时生成。

## Agent 调用指引

| 用户输入 | 执行动作 |
|---------|---------|
| “打开书架”“看看我的书架”“更新书架”“刷新书架”“同步数据”“第一次使用” | 执行**首页更新流程**，然后打开 `我的书架-浅色版.html` |
| “打开《书名》的便利贴墙” | **书名必须用《》包起来**。解析书名 → 找 `bookId`；已有单本数据就直接打开；没有缓存时先预检划线和想法合计条数，≤5000 才拉取，>5000 提示并且不生成 |
| “更新《书名》的便利贴墙” | 先预检合计条数；≤5000 时强制重新拉取并重写数据；>5000 时提示并且不生成，除非用户明确说“仍然生成” |
| “仍然生成《书名》的便利贴墙” | 跳过 5000 条预检拦截，拉取后随机抽样 5000 条并生成；仅在用户已经看到超限提示后使用 |
| “打开便利贴墙”（没有书名） | 提示用户必须指定书名，格式为：打开《书名》的便利贴墙 |
| “看看我在《书名》里的划线/想法” | 按单本书便利贴墙处理 |
| “只打开书架，不更新”“先别更新，打开看看” | 不调用 API，直接打开已有页面 |
| “封面不显示”“重新下载封面” | 检查 `data/covers/`，只重新下载缺失封面，并重写首页或单本数据 |
| “把页面放到 D 盘/桌面” | 连 `data/` 一起复制；不要只复制 HTML |
| “设置定时更新” | 不支持，也不要创建系统计划任务 |

**默认行为：**

- 用户说“打开书架”就是**更新首页并打开**，不是打开旧页面。
- 用户说“打开《书名》的便利贴墙”时，如果 `data/books/<bookId>.js` 已存在，直接用缓存打开；只有不存在时才拉取。
- 没有缓存或用户要求更新时，先读取 `noteCount + reviewCount`；合计超过 5000 条就停下提示，**不要**拉取正文，也**不要**生成空墙或抽样墙。
- 用户说“更新《书名》的便利贴墙”时才强制重新拉取。
- 首页更新**绝不**拉取 `/book/bookmarklist`、`/review/list/mine`。

如果更新失败：

- 首页更新失败时停止，不要覆盖上一版 `data/shelf.js`
- 单本更新失败时停止，不要覆盖上一版 `data/books/<bookId>.js`
- 不要静默打开旧页面；先报告失败原因
- 用户明确说“打开旧页面”时再打开

如果 `WEREAD_API_KEY` 不存在，提示用户按上面的方法配置，然后停止。

### 书名解析规则

用户必须用书名号包住书名，例如：

```text
打开《百年孤独》的便利贴墙
更新《百年孤独》的便利贴墙
```

处理步骤：

1. 用正则提取第一个 `《...》` 中的书名；没有书名号时停止，并提示正确格式。
2. 去掉书名首尾空格，与 `data/shelf.js` 的 `books[].title` 匹配。
3. 先精确匹配；没有精确匹配时再做包含匹配。
4. 匹配到多本时，列出书名、作者、bookId，让用户选择；不要随便选第一本。
5. 书架里找不到时，明确告诉用户“书架里没有这本书”，不要默认去 `/store/search` 打开书城的同名书。
6. 如果这本书没有任何划线或想法，提示用户，不要生成空便利贴墙。

## 请求约定

适用于首页更新和单本更新：

- 地址：`POST https://i.weread.qq.com/api/agent/gateway`
- 请求头：
  - `Authorization: Bearer $WEREAD_API_KEY`
  - `Content-Type: application/json`
- 业务参数必须**平铺在 body 顶层**，和 `api_name`、`skill_version` 同级，不要包在 `params` 里。
- `skill_version` 使用 `1.0.4`。
- 每次请求后检查 `errcode`；不为 0 时报告 `errmsg`。
- 独立接口可以并发，但同一时间最多 **3 个 API 请求在途**；每个请求的启动时间至少间隔 **200ms**（180–250ms 都可以）。
- 多页接口（`/user/notebooks`、`/review/list/mine`）的翻页按顺序执行；不同书、不同接口可以并发。
- 遇到 HTTP 429、`errcode` 提示限流或连续失败时，把并发降到 1–2，并按 1s、2s、4s 退避重试；恢复后再回到 3 路。
- 如果运行环境不支持并发，就退回串行，但仍保持 200ms 左右的请求间隔。
- 同一次更新里，相同接口和参数不要重复请求。

示例：

```bash
curl -sS "https://i.weread.qq.com/api/agent/gateway" \
  -H "Authorization: Bearer $WEREAD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"api_name":"/shelf/sync","skill_version":"1.0.4"}'
```

## 首页更新流程

目标：只生成首页数据，**不拉取任何笔记正文**。

### 1. 书架

调用 `/shelf/sync`（无参数），取 `books[]`，忽略 `albums[]` 和 `mp`。

每本书生成：

```json
{
  "bookId": "书籍 ID",
  "title": "书名",
  "author": "作者",
  "cover": "封面 URL 或 data/covers/xxx.jpg",
  "progress": 0,
  "readUpdateTime": 1792941988,
  "finishReading": 0
}
```

- `readUpdateTime` 取回包的最近阅读时间，用于首页排序和“最近在读”。
- `finishReading` 取回包字段（1=读完，0=在读）。
- 按 `readUpdateTime` 降序排列。
- 如果存在 `data/title_mapping.json`，用它替换拼音书名。
- **首页展示全部书架书，不设置数量上限。**

### 2. 最近在读简介（只取一本）

从排序后的 `books[]` 取第一本（按 `readUpdateTime` 降序；如果都没有时间，取 `books[0]`），调用：

```json
{"api_name":"/book/info","bookId":"书籍 ID","skill_version":"1.0.4"}
```

- 把回包 `intro` 写入这本书的 `books[].intro`，换行和连续空白压成空格。
- 只请求这一本，**不要遍历书架逐本请求**。
- 请求失败或没有 `intro` 时留空，不影响首页更新。

### 3. 笔记概览（只拿统计，不拿正文）

调用 `/user/notebooks`，每页 `count` 传 100：

```json
{"api_name":"/user/notebooks","count":100,"skill_version":"1.0.4"}
```

- 用 `count` + 顶层 `lastSort` 游标翻页；`hasMore` 为 1 时取本页最后一条 `books[].sort` 作为下一页 `lastSort`，直到 `hasMore = 0`。
- 合并所有页的 `books[]`，按 `bookId` 去重。
- 对每本书取 `readingProgress`、`noteCount`、`reviewCount`，并把 `noteCount` / `reviewCount` 写入 `books[]`（没有概览记录的书填 0），**不要**因此调用 `/book/bookmarklist` 或 `/review/list/mine`。
- `noteCount` 是划线条数，`reviewCount` 是想法/点评条数；两者相加就是单本墙的预检总量。
- 用 `readingProgress` 填充 `books[].progress`。字段缺失（不是 0）时才保留 0；首页进度排行只显示 `progress > 0` 的书。
- 这个接口同时为单本墙提供上限预检数据，但**不提供笔记正文**，不能用来生成便利贴墙。

### 4. 热力图、偏好与统计

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
- 生成 `stats`：
  - `totalReadTime`：回包 `totalReadTime`（秒）
  - `readDays`：回包 `readDays`
  - `finishedCount`：书架上 `finishReading === 1` 的书数

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

封面目录：`data/covers/`。**每次更新前先扫描目录，只下载本地没有的封面。** 封面下载最多 **4 个并发**，不要一张一张串行等待；先完成 API 取数，再并发处理封面。

文件命名必须稳定：

- 所有书统一用 `<bookId>.<ext>`，例如 `data/covers/935536.jpg`
- 推荐书也用其 `bookId`；同一本书同时出现在书架和推荐里时共用一份封面
- 万一某个推荐项没有 `bookId`，不要用 `rec-序号` 复用本地文件，直接保留远程 URL
- 扩展名按 URL 或响应 `Content-Type` 判断：`jpg` / `png` / `webp`；无法判断时用 `jpg`
- 同一 `bookId` 只保留一份文件

更新步骤：

1. 用当前书架所有 `bookId` 和推荐 `bookId` 生成本次需要的封面集合。
2. 对每个 `bookId`，先查找 `data/covers/<bookId>.*`（任意支持的扩展名）。找到且文件大小大于 0 就直接复用，写入 `cover`，**不要重新下载**；0 字节文件视为缺失。
3. 找不到时再看旧版数据里的封面路径：如果指向的本地文件仍然存在，可以复用，并尽量把它重命名为 `<bookId>.<ext>`。
4. 只有以上都找不到时才下载；多个下载任务最多 4 个并发：
   ```bash
   mkdir -p data/covers
   curl -L --fail --max-time 20 "封面 URL" -o "data/covers/935536.jpg"
   ```
5. 下载失败不要中断更新：`cover` 保留原始远程 URL，下次更新会再次尝试。
6. 首页更新只需要书架和推荐书的封面；**不要**为了便利贴墙下载其他封面。单本墙打开时再按需补。
7. 记录本次实际使用的所有封面文件路径（`usedCoverFiles`），**此时先不要删除任何文件**。

### 7. 写 `data/shelf.js`

把所有结果合并成一个对象，写成合法的 JS 文件：

```js
window.WEREAD_SHELF = { ... };
```

注意：

- 文件编码 UTF-8，不要 BOM。
- 把 JSON 里的 `<` 替换成 `\u003c`，避免内容里的 `</script>` 提前闭合页面脚本。
- 把 U+2028 / U+2029 替换成 `\u2028` / `\u2029`。
- `generatedAt` 用当前时间的 ISO 字符串。
- 先写临时文件再重命名，避免写到一半留下坏文件。
- 不要把 key 写进这个文件。
- **不要写 `notes`、`chapterProgress`。**
- **不要删除或修改 `data/books/`**；首页更新和单本缓存互不影响。
- 写入成功后，再按 `usedCoverFiles` 清理 `data/covers/` 中的孤儿封面；写入失败时不要清理。

封面清理规则：

- 删除不在 `usedCoverFiles` 中的文件
- **保留** `data/books/` 中已有单本数据对应 bookId 的封面（扫描 `data/books/*.js` 的文件名即可），避免用户打开旧单本墙时封面被删除
- 推荐列表会轮换，旧推荐封面可能被清理、新推荐封面会重新下载；这是接口特性
- 不要按修改时间清理，也不要每次清空整个目录
- 如果 `shelf.js` 写入失败，不要删除任何封面

### 8. 打开页面

更新成功后打开 `我的书架-浅色版.html`。如果页面已经开着，提醒用户刷新（F5）。

Windows 可以用：

```bat
start "" "我的书架-浅色版.html"
```

macOS / Linux 用 `open` 或 `xdg-open`。

### 首页更新耗时

- 典型规模（26 本书）本机测试：约 6–8 个 API 请求，几秒完成；封面首次补齐会慢一些，后续增量很快。
- 首页更新**不会**随笔记数量增长，因为不拉取任何笔记正文。
- 如果首页更新明显变慢，优先检查：是否错误地调用了 `/book/bookmarklist`、`/review/list/mine` 或逐本 `/book/chapterinfo`；是否在重复下载已有封面。

## 单本便利贴更新流程

触发条件：用户使用 `打开《书名》的便利贴墙` 或 `更新《书名》的便利贴墙`，且书名用《》包起来。

### 1. 解析书名并找到 bookId

按上面的「书名解析规则」在 `data/shelf.js` 的 `books[]` 中找。

- 如果 `data/shelf.js` 不存在，先执行一次首页更新流程，再继续。
- 找不到书或多本书重名时停止并说明，不要擅自选择。
- 如果这本书没有任何划线或想法，提示用户，不生成空墙。

### 2. 判断是否需要拉取，并预检条数

- 用户说“打开《书名》的便利贴墙”，且 `data/books/<bookId>.js` 已存在：直接打开，不调用 API。
- 用户说“更新《书名》的便利贴墙”，或数据文件不存在：先做 5000 条预检，再决定是否拉取。

预检方法（不拉正文）：

1. 优先从 `data/shelf.js` 的对应书读取 `noteCount` 和 `reviewCount`。
2. 如果字段缺失、用户要求“更新”，或缓存合计已经 >5000（准备拒绝前先复核），调用 `/user/notebooks`（`count: 100`，按 `lastSort` 翻页）找到这本书，拿最新计数；只读概览，不调用 `/book/bookmarklist`、`/review/list/mine`。
3. `total = noteCount + reviewCount`。

判断：

- `total > 5000`：停止，告诉用户“《书名》有 X 条划线 + Y 条想法，合计 Z 条，超过单本 5000 条上限，未生成便利贴墙”。不要拉取正文，不要写 `data/books/<bookId>.js`；如果已有旧数据，保留旧数据并告诉用户仍可打开旧墙。如果用户明确说“仍然生成《书名》的便利贴墙”，再进入下面的拉取流程，最终随机抽样 5000 条。
- `total === 0`，或书不在 `/user/notebooks` 概览里：提示没有划线或想法，不生成空墙。如果用户确认刚写过笔记，先请用户更新书架再试。
- `total <= 5000`：继续拉取。

预检只用于避免无效的大请求；如果概览计数过期，实际拉取后超过 5000 条，仍按「单本上限与抽样」处理。预检接口失败时报告原因并停止，不要直接拉取正文。

### 3. 拉取划线

调用 `/book/bookmarklist`（参数只有 `bookId`）：

```json
{"api_name":"/book/bookmarklist","bookId":"935536","skill_version":"1.0.4"}
```

- `updated[]` 的每条划线生成：
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
- 回包的 `chapters[]` 转成 `chapterUid → title` 的对象，写入单本数据的 `chapters`。
- 回包的 `book` 可以用来补书名、作者、封面。
- **这个接口没有分页参数**，一次返回全书划线；如果单本划线特别多，响应会比较大，属于已知限制。

### 4. 拉取想法/点评

调用 `/review/list/mine`（参数 `bookid`，注意是小写 `d`；`count` 传 100）：

```json
{"api_name":"/review/list/mine","bookid":"935536","count":100,"skill_version":"1.0.4"}
```

- 用回包 `synckey` 翻页直到 `hasMore = 0`。
- `reviews[]` 的每条想法/点评生成：
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
- `abstract` 是这条想法对应的划线原句，弹窗会显示；必须保留，没有时填空字符串。
- 如果 `chapterName` 有值但 `chapters` 里没有对应章节，可以用它补一个章节标题。

### 5. 单本上限与抽样

```text
MAX_NOTES_PER_BOOK = 5000
```

- 5000 是**划线和想法的合计上限**，不是划线 5000、想法再 5000。
- 如果 `bookmark + thought` 总数超过 5000，随机抽取 5000 条，`truncated: true`，`totalNotes` 写实际总数。
- 如果总数不超过 5000，全部保留，`truncated: false`。
- 抽样在写入数据文件时完成；页面刷新不会重新抽样，只有“更新《书名》的便利贴墙”才会重新抽。
- 单本墙页面使用批次加载和 5000 条上限，不会一次性生成全部 DOM。

### 6. 写 `data/books/<bookId>.js`

结构按上面的单本数据契约。注意：

- 文件编码 UTF-8，不要 BOM。
- 把 JSON 里的 `<` 替换成 `\u003c`，U+2028 / U+2029 替换成 `\u2028` / `\u2029`。
- `generatedAt` 用当前时间的 ISO 字符串。
- 先写临时文件再重命名；写入失败时保留上一版单本数据。
- **不要修改 `data/shelf.js`**；首页和单本缓存互不影响。
- 书名、作者、封面、进度从 `data/shelf.js` 的对应书复制；单本拉取回包有更新值时以回包为准。

### 7. 打开单本墙

更新成功后打开：

```text
砖墙-便利贴.html?bookId=<bookId>
```

Windows 上**不要**把带 `?bookId=` 的路径直接交给 `start`：

```bat
REM 错误：Windows 会把 ?bookId=... 当成文件名的一部分，弹出“找不到文件”对话框
start "" "C:\...\砖墙-便利贴.html?bookId=935536"
```

应使用浏览器的可执行文件打开 `file:///` URL，例如 Chrome：

```bat
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --new-window "file:///C:/完整路径/砖墙-便利贴.html?bookId=935536"
```

没有 Chrome 时用 Edge：

```bat
start "" msedge.exe --new-window "file:///C:/完整路径/砖墙-便利贴.html?bookId=935536"
```

macOS / Linux 用 `open` / `xdg-open` 打开 file URL。

- 如果页面已经开着，提醒用户刷新（F5）。
- 页面会自动显示书名、作者、封面、章节和划线/想法切换。
- 书名只用于展示和解析，URL 参数只放 `bookId`；`bookId` 必须匹配 `^[A-Za-z0-9_-]+$`。

### 单本更新耗时

- 正常单本：先做 0–1 组概览预检；≤5000 条时再拉划线 1 个请求 + 想法 1–N 个分页请求，通常几秒。
- 合计超过 5000 条时只做预检，不发起大请求，直接提示用户。
- 单本划线特别多时，响应可能较大，首次打开会明显变慢；这是 `/book/bookmarklist` 不支持分页导致的已知限制。

## 数据文件契约

| 文件 | 类型 | 说明 |
|------|------|------|
| `data/shelf.js` | JS | 首页唯一运行时数据，顶层是 `window.WEREAD_SHELF` |
| `data/books/<bookId>.js` | JS | 单本运行时数据，顶层是 `window.WEREAD_BOOK` |
| `data/covers/` | 图片 | 本地封面，路径相对于 skill 根目录 |
| `data/title_mapping.json` | 对象 | 可选，拼音书名 → 中文书名 |

旧的 `data/weread-data.js`、`data/shelf.json`、`notes.json`、`chapter_progress.json`、`heatmap.json`、`preferences.json`、`recommend.json`、`covers_base64.json` 都**不再使用**。升级后直接写 `data/shelf.js` 和 `data/books/<bookId>.js`，不要生成这些中间文件。

## 常见问题

### 首页显示“还没有书架数据”？

说明 `data/shelf.js` 没有加载到。检查：

1. 文件是否存在
2. HTML 和 `data/` 是否还在同一目录
3. 文件是否是合法的 `window.WEREAD_SHELF = {...};`

### 单本墙显示“缺少书籍参数”？

说明 URL 里没有 `bookId`。请通过 agent 打开：

```text
打开《书名》的便利贴墙
```

### 单本墙显示“还没有这本书的便利贴数据”？

说明 `data/books/<bookId>.js` 还不存在。请对 agent 说：

```text
更新《书名》的便利贴墙
```

### 封面不显示？

1. 检查 `data/covers/` 下是否有对应图片
2. 检查 `data/shelf.js` 或单本数据里的 `cover` 路径
3. 重新下载缺失封面并重写对应数据文件

### 导入的书显示拼音书名？

在 `data/title_mapping.json` 中配置：

```json
{
  "拼音书名": "中文书名"
}
```

更新数据时应用到书架和单本笔记。

### 可以在 Mac/Linux 上使用吗？

可以。取数用 `curl` 或 agent 的 HTTP 工具，页面是静态 HTML，不需要 Node 或 PowerShell。

### 为什么没有全局便利贴墙和搜索？

全局墙需要把所有书的笔记汇总到同一个页面，书多、笔记多时会带来数据文件和渲染压力。现在改成：

- 首页只负责书架和阅读数据
- 单本便利贴墙按需生成，只加载一本书
- 单本墙内用“划线/想法”切换，不做跨书搜索

这是有意的取舍。

### 为什么单本便利贴墙是一个固定 HTML？

`砖墙-便利贴.html` 是模板，通过 `?bookId=` 读取 `data/books/<bookId>.js`。更新某本书的数据时只重写数据文件，**不重新生成 HTML**；模板样式或脚本升级后，所有书都会自动使用新模板。

### 为什么没有定时更新？

本技能按“用户在对话中触发”设计，不注册系统定时任务。需要刷新时说“更新书架”或“更新《书名》的便利贴墙”。

## 安全

- `WEREAD_API_KEY` 只从环境变量读取。
- 不要硬编码、打印、提交或发送到外部服务。
- `data/` 包含个人阅读记录、笔记和封面，已在 `.gitignore` 中忽略。
- 两个 HTML 是通用模板，不包含个人数据，可以安全分发。
- 单本墙的 `bookId` 参数必须做白名单校验（`^[A-Za-z0-9_-]+$`），不要直接拼接到文件路径。
