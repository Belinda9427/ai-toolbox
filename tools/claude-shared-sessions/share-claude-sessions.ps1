<#
.SYNOPSIS
  让 Claude 桌面版（Windows）所有账号 / 组织共用同一份侧栏会话列表。

.DESCRIPTION
  Claude 桌面版把 Code 侧栏的会话登记在
    %APPDATA%\Claude\claude-code-sessions\<账号ID>\<组织ID>\local_*.json
  只显示当前登录账号那个目录里的会话，换账号后旧会话就"消失"了。
  本脚本把所有 <账号ID>\<组织ID> 目录合并进 _shared，再把每个目录换成指向 _shared 的
  junction（目录快捷方式）。之后无论登录哪个账号，读写的都是同一份会话列表。
  对话内容本身（~\.claude\projects\*.jsonl）从来不分账号，本脚本不碰它。

  改动前自动备份；-Unlink 可随时撤销。必须在客户端完全退出时执行。

.EXAMPLE
  .\share-claude-sessions.ps1 -DryRun            # 只预览，不改任何文件
.EXAMPLE
  .\share-claude-sessions.ps1 -WaitMinutes 10    # 先运行，再去托盘退出 Claude；合并完自动重开
.EXAMPLE
  .\share-claude-sessions.ps1 -InstallShortcut   # 在桌面建「Claude 共享会话」快捷方式，以后用它启动
.EXAMPLE
  .\share-claude-sessions.ps1 -Unlink            # 撤销：各账号恢复成独立目录（每个都保留完整列表）
#>
param(
    [int]$WaitMinutes = 0,        # 客户端在运行时最多等它退出多久（分钟）；0 = 不等
    [switch]$DryRun,              # 只打印要做什么，不改任何文件
    [switch]$NoLaunch,            # 完成后不自动打开客户端
    [switch]$InstallShortcut,     # 安装到本机固定位置并在桌面建快捷方式
    [string]$ShortcutName = 'Claude 共享会话',
    [switch]$Unlink               # 撤销共享
)

if ($PSVersionTable.PSVersion -lt [version]'7.5') {
    Write-Host "需要 PowerShell 7.5 或更高版本（当前 $($PSVersionTable.PSVersion)）。"
    Write-Host '安装：winget install --id Microsoft.PowerShell -e   然后用 pwsh 运行本脚本。'
    exit 2
}
$ErrorActionPreference = 'Stop'

$installDir = Join-Path $env:LOCALAPPDATA 'claude-shared-sessions'
$log        = Join-Path $installDir 'share-claude-sessions.log'
New-Item -ItemType Directory -Force $installDir | Out-Null

function Log($m) { $line = "$(Get-Date -Format s) $m"; Write-Host $line; if (-not $DryRun) { Add-Content $log $line } }

# ---------- 找到本机的 Claude 桌面版 ----------
$pkg = Get-AppxPackage -Name Claude -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pkg) {
    $appDir    = Join-Path $pkg.InstallLocation 'app'
    $appLaunch = "shell:AppsFolder\$($pkg.PackageFamilyName)!Claude"
} else {
    $appDir    = Join-Path $env:LOCALAPPDATA 'AnthropicClaude'
    $appLaunch = Join-Path $appDir 'claude.exe'
}
$appExe = Get-ChildItem $appDir -Filter 'claude.exe' -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1

function Get-AppProcs {
    # 只认桌面版进程；Claude Code CLI 也叫 claude.exe，但不在客户端安装目录里
    Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($appDir, 'OrdinalIgnoreCase') }
}
function Start-App { if (-not $NoLaunch -and -not $DryRun) { Start-Process $appLaunch } }

$roots = @(
    (Join-Path $env:APPDATA 'Claude\claude-code-sessions')
    if ($pkg) { Join-Path $env:LOCALAPPDATA "Packages\$($pkg.PackageFamilyName)\LocalCache\Roaming\Claude\claude-code-sessions" }
) | Where-Object { Test-Path $_ }

# ---------- 安装快捷方式 ----------
if ($InstallShortcut) {
    $target = Join-Path $installDir 'share-claude-sessions.ps1'
    if ($PSCommandPath -ne $target) { Copy-Item $PSCommandPath $target -Force }
    $pwshAlias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe'
    $pwsh = if (Test-Path $pwshAlias) { $pwshAlias } else { (Get-Command pwsh).Source }
    $desk = [Environment]::GetFolderPath('Desktop')
    $tmp  = Join-Path $desk 'claude-shared-sessions-tmp.lnk'   # WScript.Shell 在非中文区域下存不了中文文件名，先用英文名
    $lnk  = (New-Object -ComObject WScript.Shell).CreateShortcut($tmp)
    $lnk.TargetPath       = $pwsh
    $lnk.Arguments        = "-NoProfile -WindowStyle Hidden -File `"$target`" -WaitMinutes 1"
    $lnk.WorkingDirectory = $installDir
    if ($appExe) { $lnk.IconLocation = "$($appExe.FullName),0" }
    $lnk.Description      = 'Merge Claude sessions across accounts, then open Claude'
    $lnk.Save()
    $final = Join-Path $desk "$ShortcutName.lnk"
    Move-Item $tmp $final -Force
    Log "已在桌面创建快捷方式：$ShortcutName（脚本安装在 $target）"
    Log '下一步：完全退出 Claude（托盘图标 → 退出），然后双击这个快捷方式。'
    exit 0
}

if (-not $roots) { Log '没找到 Claude 桌面版的会话目录。请确认已安装 Claude 桌面版并至少在 Code 页开过一个会话。'; exit 3 }

# ---------- 等客户端退出 ----------
function Wait-AppExit {
    if (-not (Get-AppProcs)) { return }
    Log "Claude 客户端正在运行，等待退出（最多 $WaitMinutes 分钟）……请从托盘图标完全退出。"
    $deadline = (Get-Date).AddMinutes($WaitMinutes)
    while (Get-AppProcs) {
        if ((Get-Date) -ge $deadline) { Log '客户端仍在运行，本次未做改动。完全退出客户端后再运行一次即可。'; Start-App; exit 1 }
        Start-Sleep -Seconds 3
    }
    Start-Sleep -Seconds 3   # 等文件句柄释放
}

function Get-Activity($path) {
    if ([IO.File]::ReadAllText($path) -match '"lastActivityAt":(\d+)') { [int64]$Matches[1] } else { 0 }
}
function Merge-Tasks($src, $dst) {
    # 定时任务按 id 合并，同一任务保留最近运行过的那份
    if (-not (Test-Path $dst)) { Copy-Item $src $dst; return }
    $s = Get-Content $src -Raw | ConvertFrom-Json -DateKind String
    $t = Get-Content $dst -Raw | ConvertFrom-Json -DateKind String
    $byId = [ordered]@{}
    foreach ($x in @($t.scheduledTasks) + @($s.scheduledTasks)) {
        if ($null -eq $x) { continue }
        $prev = $byId[$x.id]
        if (-not $prev -or [string]$x.lastRunAt -gt [string]$prev.lastRunAt) { $byId[$x.id] = $x }
    }
    $t.scheduledTasks = [object[]]@($byId.Values)
    [IO.File]::WriteAllText($dst, ($t | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
function Get-OrgDirs($root) {
    Get-ChildItem $root -Directory | Where-Object Name -ne '_shared' | ForEach-Object { Get-ChildItem $_.FullName -Directory }
}
function Test-Junction($d) { [bool]($d.Attributes -band [IO.FileAttributes]::ReparsePoint) }

foreach ($root in $roots) {
    $shared = Join-Path $root '_shared'

    # ---------- 撤销 ----------
    if ($Unlink) {
        $links = Get-OrgDirs $root | Where-Object { Test-Junction $_ }
        if (-not $links) { Log "没有需要撤销的共享目录：$root"; continue }
        if ($DryRun) { $links | ForEach-Object { Log "[DryRun] 将恢复为独立目录：$($_.Parent.Name)\$($_.Name)" }; continue }
        Wait-AppExit
        foreach ($d in $links) {
            [IO.Directory]::Delete($d.FullName, $false)   # 只删 junction 本身，不动 _shared 里的内容
            New-Item -ItemType Directory $d.FullName | Out-Null
            Copy-Item (Join-Path $shared '*') $d.FullName -Recurse
            Log "已恢复为独立目录（保留完整会话列表）：$($d.Parent.Name)\$($d.Name)"
        }
        continue
    }

    # ---------- 合并并接入 ----------
    $pending = Get-OrgDirs $root | Where-Object { -not (Test-Junction $_) }
    if (-not $pending) { Log '所有账号目录都已接入共享会话，无需处理。'; continue }
    if ($DryRun) {
        foreach ($d in $pending) { Log "[DryRun] 将合并并接入：$($d.Parent.Name)\$($d.Name)（$((Get-ChildItem $d.FullName -Filter 'local_*.json').Count) 个会话）" }
        continue
    }
    Wait-AppExit

    $backup = Join-Path (Split-Path $root) ('claude-code-sessions.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    foreach ($d in $pending) { Copy-Item $d.FullName (Join-Path $backup "$($d.Parent.Name)\$($d.Name)") -Recurse }
    Log "已备份到：$backup"

    New-Item -ItemType Directory -Force $shared | Out-Null
    foreach ($d in $pending) {
        foreach ($f in Get-ChildItem $d.FullName -File) {
            $dst = Join-Path $shared $f.Name
            if ($f.Name -eq 'scheduled-tasks.json') { Merge-Tasks $f.FullName $dst }
            elseif (-not (Test-Path $dst)) { Copy-Item $f.FullName $dst }
            elseif ($f.Name -like 'local_*.json' -and (Get-Activity $f.FullName) -gt (Get-Activity $dst)) { Copy-Item $f.FullName $dst -Force }
        }
        foreach ($sd in Get-ChildItem $d.FullName -Directory) { Copy-Item $sd.FullName $shared -Recurse -Force }
        Remove-Item $d.FullName -Recurse -Force
        New-Item -ItemType Junction -Path $d.FullName -Target $shared | Out-Null
        Log "已接入共享会话：$($d.Parent.Name)\$($d.Name)"
    }
    Log "共享会话共 $((Get-ChildItem $shared -Filter 'local_*.json').Count) 个。"
}

Start-App
