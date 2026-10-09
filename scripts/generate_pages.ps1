# generate_pages.ps1 - 生成 HTML 页面
# 用法: .\generate_pages.ps1 [-OutputDir <目录>]
# 输入: data/ 目录下的 JSON + templates/ 目录下的模板
# 输出: 指定目录或 skill 根目录下的 HTML 文件

param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$skillDir = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $skillDir "data"
$templateDir = Join-Path $skillDir "templates"

# 确定输出目录
if ($OutputDir) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $targetDir = (Resolve-Path $OutputDir).Path
} else {
    $targetDir = $skillDir
}
Write-Host "输出目录: $targetDir"

# 如果指定了其他输出目录，删除默认目录下的旧页面，避免重复
if ($OutputDir -and ($targetDir -ne $skillDir)) {
    $oldFiles = @("我的书架-浅色版.html", "砖墙-便利贴.html")
    foreach ($f in $oldFiles) {
        $oldPath = Join-Path $skillDir $f
        if (Test-Path $oldPath) {
            Remove-Item $oldPath -Force
            Write-Host "已删除默认目录旧页面: $f"
        }
    }
}

# 辅助函数：PSObject 转 Hashtable（兼容 PowerShell 5.1）
function ConvertTo-Hashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [hashtable]) { return $InputObject }
    $ht = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }
    return $ht
}

# 读取数据
$shelf = Get-Content (Join-Path $dataDir "shelf.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$notes = Get-Content (Join-Path $dataDir "notes.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$covers = ConvertTo-Hashtable (Get-Content (Join-Path $dataDir "covers_base64.json") -Raw -Encoding UTF8 | ConvertFrom-Json)
$chapterProgress = ConvertTo-Hashtable (Get-Content (Join-Path $dataDir "chapter_progress.json") -Raw -Encoding UTF8 | ConvertFrom-Json)
$heatmap = ConvertTo-Hashtable (Get-Content (Join-Path $dataDir "heatmap.json") -Raw -Encoding UTF8 | ConvertFrom-Json)
$preferences = Get-Content (Join-Path $dataDir "preferences.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$recommend = Get-Content (Join-Path $dataDir "recommend.json") -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "=== 生成书架页面 ===" -ForegroundColor Cyan

# 处理书架数据：封面转 base64
$booksJson = @()
foreach ($b in $shelf) {
    $coverUrl = if ($covers[$b.title]) { $covers[$b.title] } else { $b.cover }
    $booksJson += [PSCustomObject]@{
        id = $b.bookId
        title = $b.title
        author = $b.author
        cover = $coverUrl
        progress = $b.progress
    }
}
$booksJsonStr = $booksJson | ConvertTo-Json -Depth 5 -Compress

# 热力图数据
$now = Get-Date
$year = $now.Year
$month = $now.Month
$firstDay = [int](Get-Date -Year $year -Month $month -Day 1).DayOfWeek
$daysInMonth = [DateTime]::DaysInMonth($year, $month)
$heatmapStr = $heatmap | ConvertTo-Json -Depth 3 -Compress

# 偏好分类
$prefsJson = @()
foreach ($p in $preferences) {
    $prefsJson += [PSCustomObject]@{ name = $p.name; time = $p.time; color = $p.color }
}
$prefsStr = $prefsJson | ConvertTo-Json -Depth 3 -Compress

# 推荐好书：封面转 base64
$recJson = @()
foreach ($r in $recommend) {
    $coverUrl = if ($covers[$r.title]) { $covers[$r.title] } else { $r.cover }
    $recJson += [PSCustomObject]@{
        title = $r.title
        author = $r.author
        category = $r.category
        cover = $coverUrl
        intro = $r.intro
    }
}
$recStr = $recJson | ConvertTo-Json -Depth 3 -Compress

# 读取模板并替换
$bookshelfTemplate = Get-Content (Join-Path $templateDir "bookshelf.template.html") -Raw -Encoding UTF8
$bookshelfTemplate = $bookshelfTemplate.Replace('{{BOOKS_DATA}}', $booksJsonStr)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{HEATMAP_DATA}}', $heatmapStr)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{HEATMAP_YEAR}}', $year)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{HEATMAP_MONTH}}', $month)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{HEATMAP_FIRST_DAY}}', $firstDay)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{HEATMAP_DAYS}}', $daysInMonth)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{CATEGORY_DATA}}', $prefsStr)
$bookshelfTemplate = $bookshelfTemplate.Replace('{{RECOMMEND_DATA}}', $recStr)

$bookshelfOutput = Join-Path $targetDir "我的书架-浅色版.html"
$bookshelfTemplate | Out-File $bookshelfOutput -Encoding UTF8
Write-Host "书架页面已生成: $bookshelfOutput"

Write-Host "`n=== 生成便利贴页面 ===" -ForegroundColor Cyan

# 封面数据
$coversStr = $covers | ConvertTo-Json -Depth 3 -Compress

# 章节进度数据
$cpStr = $chapterProgress | ConvertTo-Json -Depth 5 -Compress

# 笔记数据
$notesStr = $notes | ConvertTo-Json -Depth 5 -Compress

# 读取模板并替换
$stickyTemplate = Get-Content (Join-Path $templateDir "stickywall.template.html") -Raw -Encoding UTF8
$stickyTemplate = $stickyTemplate.Replace('{{COVERS_DATA}}', $coversStr)
$stickyTemplate = $stickyTemplate.Replace('{{CHAPTER_PROGRESS_DATA}}', $cpStr)
$stickyTemplate = $stickyTemplate.Replace('{{NOTES_DATA}}', $notesStr)

$stickyOutput = Join-Path $targetDir "砖墙-便利贴.html"
$stickyTemplate | Out-File $stickyOutput -Encoding UTF8
Write-Host "便利贴页面已生成: $stickyOutput"

Write-Host "`n=== 页面生成完成 ===" -ForegroundColor Green
Write-Host "书架页面: $bookshelfOutput"
Write-Host "便利贴页面: $stickyOutput"
