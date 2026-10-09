# download_covers.ps1 - 下载书籍封面并转 base64
# 用法: .\download_covers.ps1
# 输入: data/shelf.json, data/recommend.json
# 输出: data/covers_base64.json

$ErrorActionPreference = "Stop"
$skillDir = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $skillDir "data"

$shelfPath = Join-Path $dataDir "shelf.json"
$recPath = Join-Path $dataDir "recommend.json"
$outputPath = Join-Path $dataDir "covers_base64.json"

if (-not (Test-Path $shelfPath)) {
    Write-Host "错误: 找不到 $shelfPath，请先运行 fetch_data.ps1" -ForegroundColor Red
    exit 1
}

$shelfBooks = Get-Content $shelfPath -Raw -Encoding UTF8 | ConvertFrom-Json
$recBooks = @()
if (Test-Path $recPath) {
    $recBooks = Get-Content $recPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

# 合并所有需要封面的书
$allBooks = @()
$allBooks += $shelfBooks
if ($recBooks) { $allBooks += $recBooks }

# 去重（按书名）
$uniqueBooks = @{}
foreach ($b in $allBooks) {
    if ($b.title -and $b.cover -and -not $uniqueBooks.ContainsKey($b.title)) {
        $uniqueBooks[$b.title] = $b.cover
    }
}

Write-Host "需要下载封面: $($uniqueBooks.Count) 本" -ForegroundColor Cyan

# 读取已有的封面缓存（增量下载）
$existingCovers = @{}
if (Test-Path $outputPath) {
    $existingObj = Get-Content $outputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $existingObj.PSObject.Properties) {
        $existingCovers[$prop.Name] = $prop.Value
    }
    Write-Host "已有缓存封面: $($existingCovers.Count) 本"
}

$covers = @{}
$downloadCount = 0
$skipCount = 0

foreach ($title in $uniqueBooks.Keys) {
    $coverUrl = $uniqueBooks[$title]

    # 已有缓存则跳过
    if ($existingCovers.ContainsKey($title) -and $existingCovers[$title]) {
        $covers[$title] = $existingCovers[$title]
        $skipCount++
        continue
    }

    try {
        Write-Host "  下载: $title"
        $imgBytes = Invoke-WebRequest -Uri $coverUrl -UseBasicParsing | Select-Object -ExpandProperty Content
        $base64 = [Convert]::ToBase64String($imgBytes)
        # 判断图片格式
        $ext = "jpeg"
        if ($coverUrl -match '\.png') { $ext = "png" }
        elseif ($coverUrl -match '\.webp') { $ext = "webp" }
        $covers[$title] = "data:image/$ext;base64,$base64"
        $downloadCount++
    } catch {
        Write-Host "    下载失败: $_" -ForegroundColor Yellow
        $covers[$title] = ""
    }

    Start-Sleep -Milliseconds 100
}

$covers | ConvertTo-Json -Depth 3 | Out-File $outputPath -Encoding UTF8
Write-Host "`n封面下载完成: 新下载 $downloadCount 本，跳过 $skipCount 本" -ForegroundColor Green
Write-Host "输出: $outputPath"
