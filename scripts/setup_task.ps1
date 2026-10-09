# setup_task.ps1 - 定时任务管理
# 用法:
#   .\setup_task.ps1 -Action register    # 注册每天6:00自动更新
#   .\setup_task.ps1 -Action unregister  # 删除定时任务
#   .\setup_task.ps1 -Action status      # 查看状态
#   .\setup_task.ps1 -Action enable      # 启用
#   .\setup_task.ps1 -Action disable     # 禁用

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("register", "unregister", "status", "enable", "disable")]
    [string]$TaskAction
)

$taskName = "WeReadBookshelf_DailyUpdate"
$scriptDir = $PSScriptRoot
$updateScript = Join-Path $scriptDir "update.ps1"
$logFile = Join-Path (Split-Path -Parent $scriptDir) "update_log.txt"

switch ($TaskAction) {
    "register" {
        # 检查是否已存在
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "定时任务已存在，先删除..." -ForegroundColor Yellow
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }

        # 创建定时任务：每天 6:00 运行
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$updateScript`"" `
            -WorkingDirectory $scriptDir
        $trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        Register-ScheduledTask -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "微信读书书架数据每日自动更新（每天6:00）" `
            -Force | Out-Null

        Write-Host "定时任务注册成功！" -ForegroundColor Green
        Write-Host "  任务名: $taskName"
        Write-Host "  触发时间: 每天 06:00"
        Write-Host "  执行脚本: $updateScript"
        Write-Host "  日志文件: $logFile"
    }

    "unregister" {
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "定时任务已删除" -ForegroundColor Green
        } else {
            Write-Host "定时任务不存在" -ForegroundColor Yellow
        }
    }

    "status" {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $info = Get-ScheduledTaskInfo -TaskName $taskName
            Write-Host "定时任务状态:" -ForegroundColor Cyan
            Write-Host "  任务名: $taskName"
            Write-Host "  状态: $($task.State)"
            Write-Host "  上次运行: $($info.LastRunTime)"
            Write-Host "  上次结果: $($info.LastTaskResult)"
            Write-Host "  下次运行: $($info.NextRunTime)"
        } else {
            Write-Host "定时任务不存在，请先注册" -ForegroundColor Yellow
        }
    }

    "enable" {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Enable-ScheduledTask -TaskName $taskName | Out-Null
            Write-Host "定时任务已启用" -ForegroundColor Green
        } else {
            Write-Host "定时任务不存在" -ForegroundColor Yellow
        }
    }

    "disable" {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Disable-ScheduledTask -TaskName $taskName | Out-Null
            Write-Host "定时任务已禁用" -ForegroundColor Green
        } else {
            Write-Host "定时任务不存在" -ForegroundColor Yellow
        }
    }
}
