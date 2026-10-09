# update.ps1 - 一键更新（获取数据 + 下载封面 + 生成页面）
# 用法: .\update.ps1 [-OutputDir <目录>]
# 说明: 静默运行，适合定时任务调用

param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$skillDir = Split-Path -Parent $scriptDir

# 确定输出目录
if ($OutputDir) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $outputDir = Resolve-Path $OutputDir
} else {
    $outputDir = $skillDir
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  微信读书书架数据更新" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    Write-Host "`n[1/3] 获取微信读书数据..." -ForegroundColor Yellow
    & (Join-Path $scriptDir "fetch_data.ps1")
    if ($LASTEXITCODE -ne 0) { throw "数据获取失败" }

    Write-Host "`n[2/3] 下载书籍封面..." -ForegroundColor Yellow
    & (Join-Path $scriptDir "download_covers.ps1")
    if ($LASTEXITCODE -ne 0) { throw "封面下载失败" }

    Write-Host "`n[3/3] 生成 HTML 页面..." -ForegroundColor Yellow
    & (Join-Path $scriptDir "generate_pages.ps1") -OutputDir $outputDir
    if ($LASTEXITCODE -ne 0) { throw "页面生成失败" }

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  更新完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

    # 非定时任务运行时，自动打开浏览器
    if (-not $env:TASK_RUNNING) {
        $htmlPath = Join-Path $outputDir "我的书架-浅色版.html"
        if (Test-Path $htmlPath) {
            Write-Host "正在打开书架页面..." -ForegroundColor Cyan
            Start-Process $htmlPath
        }
    }

} catch {
    Write-Host "`n更新失败: $_" -ForegroundColor Red
    exit 1
}
