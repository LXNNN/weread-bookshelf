# fetch_data.ps1 - 从微信读书获取所有数据
# 用法: .\fetch_data.ps1
# 输出: data/ 目录下的多个 JSON 文件

$ErrorActionPreference = "Stop"
$skillDir = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $skillDir "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }

# 检查 API Key
$apiKey = $env:WEREAD_API_KEY
if (-not $apiKey) {
    $apiKey = [Environment]::GetEnvironmentVariable("WEREAD_API_KEY", "User")
    if ($apiKey) { $env:WEREAD_API_KEY = $apiKey }
}
if (-not $apiKey) {
    Write-Host "错误: 未设置环境变量 WEREAD_API_KEY" -ForegroundColor Red
    Write-Host "请运行: [Environment]::SetEnvironmentVariable('WEREAD_API_KEY', 'wrk-你的key', 'User')"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}
$apiUrl = "https://i.weread.qq.com/api/agent/gateway"

function Invoke-WeReadApi {
    param([string]$ApiName, [hashtable]$Params = @{})
    $body = @{ api_name = $ApiName; skill_version = "1.0.4" }
    foreach ($k in $Params.Keys) { $body[$k] = $Params[$k] }
    $bodyJson = $body | ConvertTo-Json -Depth 10
    $resp = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $bodyJson
    if ($resp.errcode -and $resp.errcode -ne 0) {
        Write-Host "API $ApiName 错误: $($resp.errmsg)" -ForegroundColor Yellow
    }
    return $resp
}

Write-Host "=== 1. 获取书架数据 ===" -ForegroundColor Cyan
$shelfResp = Invoke-WeReadApi -ApiName "/shelf/sync"
$books = @()
if ($shelfResp.books) {
    foreach ($b in $shelfResp.books) {
        $books += [PSCustomObject]@{
            bookId = $b.bookId
            title = $b.title
            author = $b.author
            cover = $b.cover
            progress = 0
            readUpdateTime = if ($b.readUpdateTime) { $b.readUpdateTime } else { 0 }
        }
    }
}
Write-Host "书架书籍: $($books.Count) 本"

# 按最近阅读时间降序排列（微信读书书架顺序）
$books = $books | Sort-Object -Property @{Expression={if ($_.readUpdateTime) { $_.readUpdateTime } else { 0 }}; Descending=$true}
Write-Host "已按书架顺序（最近阅读时间）排序"

# 修复拼音书名：读取用户配置的书名映射
$mappingPath = Join-Path $dataDir "title_mapping.json"
$titleMapping = @{}
if (Test-Path $mappingPath) {
    $mappingObj = Get-Content $mappingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $mappingObj.PSObject.Properties) {
        $titleMapping[$prop.Name] = $prop.Value
    }
}
foreach ($b in $books) {
    if ($titleMapping[$b.title]) {
        Write-Host "  映射书名: $($b.title) → $($titleMapping[$b.title])"
        $b.title = $titleMapping[$b.title]
    }
}

Write-Host "=== 2. 获取每本书阅读进度 ===" -ForegroundColor Cyan
$progressMap = @{}
for ($i = 0; $i -lt $books.Count; $i++) {
    $b = $books[$i]
    try {
        $progResp = Invoke-WeReadApi -ApiName "/book/getprogress" -Params @{ bookId = $b.bookId }
        if ($progResp.book -and $progResp.book.progress) {
            $b.progress = $progResp.book.progress
            $progressMap[$b.bookId] = $progResp.book.progress
        }
    } catch {
        Write-Host "  $($b.title) 进度获取失败" -ForegroundColor Yellow
    }
    if ($i % 5 -eq 0) { Write-Host "  进度: $($i+1)/$($books.Count)" }
    Start-Sleep -Milliseconds 200
}
$books | ConvertTo-Json -Depth 5 | Out-File (Join-Path $dataDir "shelf.json") -Encoding UTF8
Write-Host "书架数据已保存"

Write-Host "=== 3. 获取笔记数据 ===" -ForegroundColor Cyan
$allNotes = @()
$notebooksResp = Invoke-WeReadApi -ApiName "/user/notebooks" -Params @{ count = 100 }
$noteBooks = @()
if ($notebooksResp.books) { $noteBooks = $notebooksResp.books }
Write-Host "有笔记的书: $($noteBooks.Count) 本"

foreach ($nb in $noteBooks) {
    $bookId = $nb.bookId
    $bookTitle = $nb.book.title
    $bookAuthor = $nb.book.author
    Write-Host "  获取《$bookTitle》笔记..."

    # 划线
    try {
        $bmResp = Invoke-WeReadApi -ApiName "/book/bookmarklist" -Params @{ bookId = $bookId }
        if ($bmResp.updated) {
            foreach ($bm in $bmResp.updated) {
                $allNotes += [PSCustomObject]@{
                    bookId = $bookId
                    title = $bookTitle
                    author = $bookAuthor
                    type = "bookmark"
                    content = $bm.markText
                    chapterUid = $bm.chapterUid
                    createTime = $bm.createTime
                }
            }
        }
    } catch { Write-Host "    划线获取失败" -ForegroundColor Yellow }

    # 想法
    try {
        $rvResp = Invoke-WeReadApi -ApiName "/review/list/mine" -Params @{ bookid = $bookId }
        if ($rvResp.reviews) {
            foreach ($rv in $rvResp.reviews) {
                $review = if ($rv.review) { $rv.review } else { $rv }
                $allNotes += [PSCustomObject]@{
                    bookId = $bookId
                    title = $bookTitle
                    author = $bookAuthor
                    type = "thought"
                    content = $review.content
                    abstract = $review.abstract
                    chapterUid = $review.chapterUid
                    createTime = $review.createTime
                }
            }
        }
    } catch { Write-Host "    想法获取失败" -ForegroundColor Yellow }

    Start-Sleep -Milliseconds 300
}
$allNotes | ConvertTo-Json -Depth 5 | Out-File (Join-Path $dataDir "notes.json") -Encoding UTF8
Write-Host "笔记总数: $($allNotes.Count) 条"

Write-Host "=== 4. 获取章节目录和进度 ===" -ForegroundColor Cyan
$chapterProgress = @{}
$noteBookIds = $noteBooks | ForEach-Object { $_.bookId } | Select-Object -Unique
foreach ($bookId in $noteBookIds) {
    $chapters = @{}
    try {
        $chResp = Invoke-WeReadApi -ApiName "/book/chapterinfo" -Params @{ bookId = $bookId }
        if ($chResp.chapters) {
            foreach ($ch in $chResp.chapters) {
                $chapters[$ch.chapterUid.ToString()] = $ch.title
            }
        }
    } catch { Write-Host "  $bookId 章节获取失败" -ForegroundColor Yellow }

    $progress = if ($progressMap[$bookId]) { $progressMap[$bookId] } else { 0 }
    $chapterProgress[$bookId] = @{
        chapters = $chapters
        progress = $progress
    }
    Start-Sleep -Milliseconds 200
}
$chapterProgress | ConvertTo-Json -Depth 5 | Out-File (Join-Path $dataDir "chapter_progress.json") -Encoding UTF8
Write-Host "章节进度数据已保存"

Write-Host "=== 5. 获取本月阅读数据（热力图） ===" -ForegroundColor Cyan
try {
    $readDetail = Invoke-WeReadApi -ApiName "/readdata/detail" -Params @{ mode = "monthly" }
    $monthlyData = @{}
    if ($readDetail.readTimes) {
        foreach ($prop in $readDetail.readTimes.PSObject.Properties) {
            $timestamp = [long]$prop.Name
            $date = [DateTimeOffset]::FromUnixTimeSeconds($timestamp).LocalDateTime
            $day = $date.Day
            $monthlyData[$day.ToString()] = [int]$prop.Value
        }
    }
    $monthlyData | ConvertTo-Json -Depth 3 | Out-File (Join-Path $dataDir "heatmap.json") -Encoding UTF8
    Write-Host "本月阅读数据: $($monthlyData.Count) 天有记录"
} catch {
    Write-Host "  阅读数据获取失败，使用空数据: $_" -ForegroundColor Yellow
    @{} | ConvertTo-Json | Out-File (Join-Path $dataDir "heatmap.json") -Encoding UTF8
}

Write-Host "=== 6. 获取阅读偏好分类 ===" -ForegroundColor Cyan
try {
    $prefResp = Invoke-WeReadApi -ApiName "/readdata/detail" -Params @{ mode = "overall" }
    $categoryData = @()
    if ($prefResp.preferCategory) {
        $colors = @('#b4643a', '#c89b5a', '#8f4a26', '#d4b896', '#a67c52', '#e0c9a6', '#b8860b', '#cd853f')
        $i = 0
        foreach ($cat in $prefResp.preferCategory) {
            if ($cat.readingTime -gt 0) {
                $categoryData += [PSCustomObject]@{
                    name = $cat.categoryTitle
                    time = $cat.readingTime
                    color = $colors[$i % $colors.Count]
                }
                $i++
            }
        }
    }
    $categoryData | ConvertTo-Json -Depth 3 | Out-File (Join-Path $dataDir "preferences.json") -Encoding UTF8
    Write-Host "偏好分类: $($categoryData.Count) 类"
} catch {
    Write-Host "  偏好数据获取失败: $_" -ForegroundColor Yellow
    @() | ConvertTo-Json | Out-File (Join-Path $dataDir "preferences.json") -Encoding UTF8
}

Write-Host "=== 7. 获取推荐好书 ===" -ForegroundColor Cyan
try {
    $recResp = Invoke-WeReadApi -ApiName "/book/recommend" -Params @{ count = 12 }
    $recBooks = @()
    if ($recResp.books) {
        foreach ($rb in $recResp.books) {
            $recBooks += [PSCustomObject]@{
                title = $rb.title
                author = $rb.author
                category = if ($rb.category) { $rb.category } else { "" }
                cover = $rb.cover
                intro = $rb.intro
            }
        }
    }
    $recBooks | ConvertTo-Json -Depth 3 | Out-File (Join-Path $dataDir "recommend.json") -Encoding UTF8
    Write-Host "推荐好书: $($recBooks.Count) 本"
} catch {
    Write-Host "  推荐数据获取失败: $_" -ForegroundColor Yellow
    @() | ConvertTo-Json | Out-File (Join-Path $dataDir "recommend.json") -Encoding UTF8
}

Write-Host "`n=== 数据获取完成 ===" -ForegroundColor Green
Write-Host "数据目录: $dataDir"
