[CmdletBinding()]
param(
    [switch]$ScanOnce,
    [switch]$InitializeBaseline,
    [string]$DesktopOverride = '',
    [string]$DataOverride = '',
    [switch]$SelfTest,
    [switch]$SmokeTest,
    [switch]$AutoApprove
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppName = '桌面智能归档'
$script:Desktop = if ($DesktopOverride) { [IO.Path]::GetFullPath($DesktopOverride) } else { [Environment]::GetFolderPath('Desktop') }
$script:Root = Join-Path $script:Desktop '桌面整理'
$script:RecentRoot = Join-Path $script:Root '最近一周'
$script:ArchiveRoot = Join-Path $script:Root '归档'
$script:DataRoot = if ($DataOverride) { [IO.Path]::GetFullPath($DataOverride) } else { Join-Path $env:LOCALAPPDATA 'DesktopOrganizerCN' }
$script:ConfigPath = Join-Path $script:DataRoot 'config.json'
$script:StatePath = Join-Path $script:DataRoot 'state.json'
$script:LogPath = Join-Path $script:DataRoot 'organizer.log'
$script:ProjectPath = Join-Path $script:DataRoot 'projects.json'
$script:PendingPath = Join-Path $script:DataRoot 'pending.json'
$script:SchedulePath = Join-Path $script:DataRoot 'schedule.json'
$script:Mutex = $null
$script:TestBusyProcess = $null
$script:TestFullScreen = $null
$script:TestOnBattery = $null

function Write-Log([string]$Message) {
    if (-not (Test-Path -LiteralPath $script:DataRoot)) { New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null }
    Add-Content -LiteralPath $script:LogPath -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message) -Encoding UTF8
}

function Get-DefaultConfig {
    [ordered]@{
        SourceFolder = $script:Desktop
        ScanMinutes = 5
        SettleMinutes = 10
        ArchiveAfterDays = 7
        CleanupTime = '20:00'
        AskBeforeRecentMove = $false
        AutomationEnabled = $true
        WorkdayReminderEnabled = $true
        QuietStartHour = 22
        QuietEndHour = 9
        RecentProtectionMinutes = 30
        PauseLargeScanOnBattery = $true
        LargeFileMB = 100
        BusyProcesses = @('Photoshop','blender','Premiere Pro','AfterFX','Resolve','Illustrator','InDesign','Adobe Media Encoder','VEGAS','CapCut')
        Categories = @(
            [ordered]@{ Type='设计项目'; Project='示例设计'; Keywords=@('示例') },
            [ordered]@{ Type='设计项目'; Project='图像处理'; Keywords=@('图像','监护') },
            [ordered]@{ Type='设计项目'; Project='概念项目'; Keywords=@('概念项目','概念','鹿','参考','素材') },
            [ordered]@{ Type='设计项目'; Project='工业设计'; Keywords=@('折叠刀架','刀架','爆炸图','分体','木头架子','铜奔马','人因工程','拖延症','灭虫士','产品效果图') },
            [ordered]@{ Type='比赛材料'; Project='比赛与展板'; Keywords=@('大工赛','展板','参赛','报名','提交视频','作品信息') },
            [ordered]@{ Type='教学资料'; Project='化学'; Keywords=@('化学') },
            [ordered]@{ Type='教学资料'; Project='物理'; Keywords=@('物理','沪科版') },
            [ordered]@{ Type='教学资料'; Project='试卷'; Keywords=@('试卷','模拟卷','考试版','九年级','练习') },
            [ordered]@{ Type='个人资料'; Project='简历'; Keywords=@('简历') },
            [ordered]@{ Type='个人资料'; Project='行政与实习'; Keywords=@('实习','鉴定表','整改报告','材料') },
            [ordered]@{ Type='网页与程序'; Project='网页文件'; Keywords=@('.html','.htm','index') }
        )
        ExtensionFallback = [ordered]@{
            '.blend'='设计项目|三维模型'; '.blend1'='设计项目|三维模型'; '.glb'='设计项目|三维模型'
            '.psd'='设计项目|视觉设计'; '.png'='设计项目|图片素材'; '.jpg'='设计项目|图片素材'; '.jpeg'='设计项目|图片素材'
            '.mp4'='媒体资料|视频'; '.mov'='媒体资料|视频'
            '.doc'='文档资料|Word文档'; '.docx'='文档资料|Word文档'; '.pdf'='文档资料|PDF文档'
            '.xlsx'='文档资料|表格'; '.xls'='文档资料|表格'; '.zip'='压缩与导出|压缩包'; '.rar'='压缩与导出|压缩包'; '.7z'='压缩与导出|压缩包'
        }
        IgnoredNames = @('desktop.ini','桌面整理','DesktopOrganizer','DesktopOrganizer.lnk')
        IgnoredExtensions = @('.lnk','.url','.tmp','.crdownload','.part')
    }
}

function Save-Json($Object, [string]$Path) {
    $Object | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Set-WorkspaceFolder([string]$Folder) {
    if(-not (Test-Path -LiteralPath $Folder -PathType Container)){throw "选择的文件夹不存在：$Folder"}
    $script:Desktop=[IO.Path]::GetFullPath($Folder)
    $script:Root=Join-Path $script:Desktop '桌面整理'
    $script:RecentRoot=Join-Path $script:Root '最近一周'
    $script:ArchiveRoot=Join-Path $script:Root '归档'
    foreach($p in @($script:Root,$script:RecentRoot,$script:ArchiveRoot)){if(-not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
}

function Initialize-App {
    foreach ($path in @($script:DataRoot)) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { Save-Json (Get-DefaultConfig) $script:ConfigPath }
    $initialConfig=Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
    $configured=Get-Setting $initialConfig 'SourceFolder' $script:Desktop
    if(-not(Test-Path -LiteralPath $configured -PathType Container)){$configured=$script:Desktop}
    Set-WorkspaceFolder $configured
    if (-not (Test-Path -LiteralPath $script:StatePath)) {
        $known = @{}
        Get-ChildItem -LiteralPath $script:Desktop -Force | Where-Object { $_.Name -ne '桌面整理' } | ForEach-Object { $known[$_.FullName] = $_.LastWriteTimeUtc.Ticks }
        Save-Json ([ordered]@{ Initialized=(Get-Date).ToString('o'); KnownDesktopItems=$known }) $script:StatePath
        if (-not $SelfTest -and -not $SmokeTest) { [System.Windows.Forms.MessageBox]::Show("首次启动已完成。`n`n当前桌面内容已设为基线，不会自动搬动；从现在起新产生或重新更新的内容才会进入【最近一周】。",$script:AppName,'OK','Information') | Out-Null }
    }
    if (-not (Test-Path -LiteralPath $script:ProjectPath)) { Save-Json ([ordered]@{}) $script:ProjectPath }
    if (-not (Test-Path -LiteralPath $script:PendingPath)) { Save-Json @() $script:PendingPath }
    if (-not (Test-Path -LiteralPath $script:SchedulePath)) { Save-Json ([ordered]@{ LastPrompt='2000-01-01T00:00:00' }) $script:SchedulePath }
}

function Get-Config { Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Get-State { Get-Content -LiteralPath $script:StatePath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Get-ProjectStates { Get-Content -LiteralPath $script:ProjectPath -Raw -Encoding UTF8 | ConvertFrom-Json }

function Get-Setting($Config,[string]$Name,$Default) {
    $p=$Config.PSObject.Properties[$Name]; if ($null -eq $p) { return $Default }; return $p.Value
}

function Test-QuietHours($Config) {
    $h=(Get-Date).Hour; $start=[int](Get-Setting $Config 'QuietStartHour' 22); $end=[int](Get-Setting $Config 'QuietEndHour' 9)
    if ($start -gt $end) { return ($h -ge $start -or $h -lt $end) }; return ($h -ge $start -and $h -lt $end)
}

function Get-BusyProcess($Config) {
    if ($script:TestBusyProcess) { return $script:TestBusyProcess }
    $names=@(Get-Setting $Config 'BusyProcesses' @())
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) { foreach ($n in $names) { if ($p.ProcessName -like "*$n*" -or $p.MainWindowTitle -like "*$n*") { return $p.ProcessName } } }
    return $null
}

function Test-OnBattery {
    if ($null -ne $script:TestOnBattery) { return [bool]$script:TestOnBattery }
    try { return [Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq [Windows.Forms.PowerLineStatus]::Offline } catch { return $false }
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FullScreenCheck {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hWnd,out RECT r);
  public static bool IsFullScreen() { RECT r; var h=GetForegroundWindow(); if(h==IntPtr.Zero||!GetWindowRect(h,out r))return false; var b=System.Windows.Forms.Screen.FromHandle(h).Bounds; return r.Left<=b.Left&&r.Top<=b.Top&&r.Right>=b.Right&&r.Bottom>=b.Bottom; }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

Add-Type @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
public class RoundedPanel : Panel {
  public int Radius {get;set;} public Color BorderColor {get;set;}
  public RoundedPanel(){Radius=22;BorderColor=Color.FromArgb(226,229,235);DoubleBuffered=true;}
  protected override void OnResize(EventArgs e){base.OnResize(e);SetShape();}
  void SetShape(){if(Width<2||Height<2)return;using(var p=Path(ClientRectangle,Radius))Region=new Region(p);}
  protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;using(var p=Path(new Rectangle(0,0,Width-1,Height-1),Radius))using(var pen=new Pen(BorderColor))e.Graphics.DrawPath(pen,p);}
  static GraphicsPath Path(Rectangle r,int d){var p=new GraphicsPath();int a=Math.Min(d,Math.Min(r.Width,r.Height));p.AddArc(r.X,r.Y,a,a,180,90);p.AddArc(r.Right-a,r.Y,a,a,270,90);p.AddArc(r.Right-a,r.Bottom-a,a,a,0,90);p.AddArc(r.X,r.Bottom-a,a,a,90,90);p.CloseFigure();return p;}
}
public class RoundedButton : Button {
  public int Radius {get;set;}
  public RoundedButton(){Radius=14;FlatStyle=FlatStyle.Flat;FlatAppearance.BorderSize=0;Cursor=Cursors.Hand;}
  protected override void OnResize(EventArgs e){base.OnResize(e);if(Width<2||Height<2)return;var r=new Rectangle(0,0,Width,Height);var p=new GraphicsPath();int a=Math.Min(Radius,Math.Min(Width,Height));p.AddArc(r.X,r.Y,a,a,180,90);p.AddArc(r.Right-a,r.Y,a,a,270,90);p.AddArc(r.Right-a,r.Bottom-a,a,a,0,90);p.AddArc(r.X,r.Bottom-a,a,a,90,90);p.CloseFigure();Region=new Region(p);}
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

function Test-IsFullScreen { if ($null -ne $script:TestFullScreen) { return [bool]$script:TestFullScreen }; return [FullScreenCheck]::IsFullScreen() }
function Test-CanPrompt($Config) { return (-not (Test-QuietHours $Config)) -and (-not (Test-IsFullScreen)) }

function Test-CleanupDue($Config) {
    $now=Get-Date; $time=[TimeSpan]::Parse([string](Get-Setting $Config 'CleanupTime' '20:00'))
    $last=[datetime]'2000-01-01'; if(Test-Path $script:SchedulePath){try{$last=[datetime]((Get-Content $script:SchedulePath -Raw -Encoding UTF8|ConvertFrom-Json).LastPrompt)}catch{}}
    $scheduled=$now.Date.Add($time)
    if($now -lt $scheduled){$scheduled=$scheduled.AddDays(-1)}
    return $last -lt $scheduled
}

function Set-CleanupPrompted { Save-Json ([ordered]@{LastPrompt=(Get-Date).ToString('o')}) $script:SchedulePath }

function ConvertTo-SafeName([string]$Name) {
    $safe = $Name
    foreach ($char in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace([string]$char, '_') }
    if ([string]::IsNullOrWhiteSpace($safe)) { return '待确认' }
    return $safe.Trim()
}

function Get-Classification([IO.FileSystemInfo]$Item, $Config) {
    $search = $Item.Name.ToLowerInvariant()
    foreach ($rule in $Config.Categories) {
        foreach ($keyword in $rule.Keywords) {
            if ($search.Contains(([string]$keyword).ToLowerInvariant())) {
                return [pscustomobject]@{ Type=(ConvertTo-SafeName $rule.Type); Project=(ConvertTo-SafeName $rule.Project); Reason="关键词：$keyword" }
            }
        }
    }
    if (-not $Item.PSIsContainer) {
        $ext = $Item.Extension.ToLowerInvariant()
        $pair = $Config.ExtensionFallback.PSObject.Properties[$ext]
        if ($null -ne $pair) {
            $parts = ([string]$pair.Value).Split('|')
            return [pscustomobject]@{ Type=(ConvertTo-SafeName $parts[0]); Project=(ConvertTo-SafeName $parts[1]); Reason="扩展名：$ext" }
        }
    }
    return [pscustomobject]@{ Type='待确认'; Project='待确认'; Reason='名称与类型均未匹配' }
}

function Get-LatestWriteTime([IO.FileSystemInfo]$Item) {
    if (-not $Item.PSIsContainer) { return $Item.LastWriteTime }
    $latest = $Item.LastWriteTime
    Get-ChildItem -LiteralPath $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { if ($_.LastWriteTime -gt $latest) { $latest=$_.LastWriteTime } }
    return $latest
}

function Get-ProtectionTime([IO.FileSystemInfo]$Item) {
    $latest=$Item.LastWriteTime
    if($Item.LastAccessTime -gt $latest){$latest=$Item.LastAccessTime}
    return $latest
}

function Test-FileInUse([IO.FileSystemInfo]$Item) {
    if($Item.PSIsContainer){return $false}
    try{$s=[IO.File]::Open($Item.FullName,'Open','ReadWrite','None');$s.Close();return $false}catch{return $true}
}

function Get-UniqueDestination([string]$Directory,[string]$Name) {
    $candidate = Join-Path $Directory $Name
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $base = [IO.Path]::GetFileNameWithoutExtension($Name); $ext=[IO.Path]::GetExtension($Name); $n=2
    do { $candidate=Join-Path $Directory ("{0} ({1}){2}" -f $base,$n,$ext); $n++ } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

function Move-Safely([string]$Source,[string]$DestinationDirectory) {
    if (-not (Test-Path -LiteralPath $DestinationDirectory)) { New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null }
    $dest = Get-UniqueDestination $DestinationDirectory ([IO.Path]::GetFileName($Source))
    Move-Item -LiteralPath $Source -Destination $dest
    Write-Log "移动：$Source -> $dest"
}

function Get-ProjectStatus([string]$Project) {
    $states=Get-ProjectStates; $p=$states.PSObject.Properties[$Project]
    if ($null -eq $p) { return '进行中' }; return [string]$p.Value
}

function Set-ProjectStatus([string]$Project,[string]$Status) {
    $old=Get-ProjectStates; $map=[ordered]@{}; $old.PSObject.Properties | ForEach-Object { $map[$_.Name]=$_.Value }; $map[$Project]=$Status; Save-Json $map $script:ProjectPath
    Write-Log "项目状态：$Project -> $Status"
}

function Get-ArchivePlan([IO.FileSystemInfo]$Item,[string]$Project,$Config,[string]$Reason) {
    $latest=Get-LatestWriteTime $Item; $class=Get-Classification $Item $Config
    if ($Project) { $class=[pscustomobject]@{ Type=$class.Type; Project=$Project; Reason=$Reason } }
    $dest=Join-Path (Join-Path (Join-Path (Join-Path $script:ArchiveRoot $class.Type) $class.Project) $latest.ToString('yyyy')) $latest.ToString('MM月')
    return [pscustomobject]@{ Source=$Item.FullName; Name=$Item.Name; Destination=$dest; Reason=$Reason }
}

function Complete-Project([string]$Project,$Config) {
    $folder=Join-Path $script:RecentRoot $Project; if (-not (Test-Path -LiteralPath $folder)) { return 0 }
    $plans=@(); Get-ChildItem -LiteralPath $folder -Force | ForEach-Object { $plans += Get-ArchivePlan $_ $Project $Config '项目已交付' }
    foreach ($p in $plans) { if (Test-Path -LiteralPath $p.Source) { Move-Safely $p.Source $p.Destination } }
    Set-ProjectStatus $Project '已交付'; return @($plans).Count
}

function Show-Confirmation([string]$Title,[string]$Intro,$Plans) {
    if (@($Plans).Count -eq 0) { return $false }
    if ($AutoApprove) { Write-Log "测试自动确认：$Title，共 $(@($Plans).Count) 项"; return $true }
    $lines = @($Plans | Select-Object -First 20 | ForEach-Object { "• $($_.Name)`n  → $($_.Destination) [$($_.Reason)]" })
    if (@($Plans).Count -gt 20) { $lines += "……另有 $(@($Plans).Count-20) 项" }
    $message = "$Intro`n`n$($lines -join "`n")`n`n选择【是】执行，选择【否】保持原位。"
    return [System.Windows.Forms.MessageBox]::Show($message,$Title,'YesNo','Question') -eq 'Yes'
}

function Scan-DesktopNewItems($Config) {
    if (-not [bool](Get-Setting $Config 'AutomationEnabled' $true)) { return 0 }
    $busy=Get-BusyProcess $Config; if ($busy) { Write-Log "暂停整理：检测到创作软件 $busy 正在运行"; return 0 }
    $state = Get-State
    $known = @{}
    if ($null -ne $state.KnownDesktopItems) { $state.KnownDesktopItems.PSObject.Properties | ForEach-Object { $known[$_.Name]=$_.Value } }
    $now = Get-Date; $plans=@(); $items=Get-ChildItem -LiteralPath $script:Desktop -Force; $onBattery=Test-OnBattery; $largeBytes=[double](Get-Setting $Config 'LargeFileMB' 100)*1MB
    foreach ($item in $items) {
        if ($Config.IgnoredNames -contains $item.Name -or $Config.IgnoredExtensions -contains $item.Extension.ToLowerInvariant()) { continue }
        if ($item.FullName.StartsWith($script:Root,[StringComparison]::OrdinalIgnoreCase)) { continue }
        $isNew = -not $known.ContainsKey($item.FullName)
        $changed = $isNew -or ([long]$known[$item.FullName] -ne $item.LastWriteTimeUtc.Ticks)
        $protect=[Math]::Max([double]$Config.SettleMinutes,[double](Get-Setting $Config 'RecentProtectionMinutes' 30))
        if($onBattery -and [bool](Get-Setting $Config 'PauseLargeScanOnBattery' $true) -and -not $item.PSIsContainer -and $item.Length -ge $largeBytes){Write-Log "电池模式跳过大文件：$($item.FullName)";continue}
        if ($changed -and (($now - (Get-ProtectionTime $item)).TotalMinutes -ge $protect) -and -not (Test-FileInUse $item)) {
            $class=Get-Classification $item $Config
            $dest=Join-Path $script:RecentRoot $class.Project
            $plans += [pscustomobject]@{ Source=$item.FullName; Name=$item.Name; Destination=$dest; Reason=$class.Reason }
        }
    }
    if (@($plans).Count -gt 0) {
        $approved = $true
        if ($Config.AskBeforeRecentMove) { $approved=Show-Confirmation '确认放入最近一周' '发现新的或已更新的桌面内容：' $plans }
        if ($approved) { foreach ($p in $plans) { if (Test-Path -LiteralPath $p.Source) { Move-Safely $p.Source $p.Destination; $known.Remove($p.Source) } } }
    }
    Save-Json ([ordered]@{ Initialized=$state.Initialized; KnownDesktopItems=$known }) $script:StatePath
    return @($plans).Count
}

function Scan-RecentForArchive($Config) {
    if (-not (Test-CleanupDue $Config) -and -not $ScanOnce -and -not $SelfTest) { return 0 }
    $cutoff=(Get-Date).AddDays(-[double]$Config.ArchiveAfterDays); $plans=@()
    Get-ChildItem -LiteralPath $script:RecentRoot -Directory -Force | ForEach-Object {
        $projectFolder=$_
        if ((Get-ProjectStatus $projectFolder.Name) -ne '已交付') { return }
        Get-ChildItem -LiteralPath $projectFolder.FullName -Force | ForEach-Object {
            $latest=Get-LatestWriteTime $_
            if ($latest -lt $cutoff) {
                $class=Get-Classification $_ $Config
                if ($class.Project -eq '待确认' -or $class.Project -ne $projectFolder.Name) {
                    $class=[pscustomobject]@{ Type=$class.Type; Project=$projectFolder.Name; Reason="最近一周项目：$($projectFolder.Name)" }
                }
                $dest=Join-Path (Join-Path (Join-Path (Join-Path $script:ArchiveRoot $class.Type) $class.Project) $latest.ToString('yyyy')) $latest.ToString('MM月')
                $plans += [pscustomobject]@{ Source=$_.FullName; Name=$_.Name; Destination=$dest; Reason=$class.Reason }
            }
        }
    }
    if (@($plans).Count -gt 0 -and (Test-CanPrompt $Config)) {
        $approved=Show-Confirmation '确认归档' "以下已交付内容超过 $($Config.ArchiveAfterDays) 天没有更新，建议归档：" $plans
        Set-CleanupPrompted
        if($approved){foreach ($p in $plans) { if (Test-Path -LiteralPath $p.Source) { Move-Safely $p.Source $p.Destination } }}
    }
    return @($plans).Count
}

function Invoke-FullScan([bool]$ShowResult=$false) {
    try {
        $config=Get-Config; $newCount=Scan-DesktopNewItems $config; $archiveCount=Scan-RecentForArchive $config
        Write-Log "扫描完成：新内容候选 $newCount 项，归档候选 $archiveCount 项"
        if ($ShowResult) { [System.Windows.Forms.MessageBox]::Show("扫描完成。`n新内容候选：$newCount 项`n归档候选：$archiveCount 项",$script:AppName,'OK','Information') | Out-Null }
    } catch { Write-Log "错误：$($_.Exception.Message)"; if ($ShowResult) { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,$script:AppName,'OK','Error') | Out-Null } }
}

function Open-Path([string]$Path) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $Path) }

function Assert-Test([bool]$Condition,[string]$Name) {
    if(-not $Condition){throw "自测失败：$Name"}; Write-Log "自测通过：$Name"
}

function Invoke-IsolatedSelfTest {
    Initialize-App; $config=Get-Config
    Assert-Test (Test-Path $script:ConfigPath) '初始化配置'
    Assert-Test ((Get-Setting $config 'RecentProtectionMinutes' 0) -eq 30) '默认30分钟保护'

    $existing=Join-Path $script:Desktop '已有设计稿.png';Set-Content -LiteralPath $existing -Value 'existing' -Encoding UTF8;Refresh-Workbench
    Assert-Test ($script:FileList.Items.Count -eq 1) '现有文件立即显示'
    Assert-Test ($script:FileList.Items[0].SubItems[2].Text -eq '待整理') '现有文件标记待整理'

    $clock=Join-Path $script:Desktop '示例方案.blend'; Set-Content -LiteralPath $clock -Value 'model' -Encoding UTF8; [IO.File]::SetLastWriteTime($clock,(Get-Date).AddMinutes(-40));[IO.File]::SetLastAccessTime($clock,(Get-Date).AddMinutes(-40))
    $moved=Scan-DesktopNewItems $config
    Assert-Test ($moved -eq 1) '新文件扫描候选'
    Assert-Test (Test-Path (Join-Path $script:RecentRoot '示例设计\示例方案.blend')) '按项目进入最近一周'

    Set-ProjectStatus '示例设计' '暂停'; $archiveBefore=Scan-RecentForArchive $config
    Assert-Test ($archiveBefore -eq 0) '暂停项目不自动归档'
    $done=Complete-Project '示例设计' $config
    Assert-Test ($done -eq 1) '已交付项目执行归档'
    Assert-Test (@(Get-ChildItem $script:ArchiveRoot -Recurse -Filter '示例方案.blend').Count -eq 1) '归档文件落位'

    $young=Join-Path $script:Desktop '图像新稿.psd';Set-Content $young 'draft' -Encoding UTF8
    Assert-Test ((Scan-DesktopNewItems $config) -eq 0) '30分钟内文件保持原位'
    [IO.File]::SetLastWriteTime($young,(Get-Date).AddMinutes(-40));[IO.File]::SetLastAccessTime($young,(Get-Date).AddMinutes(-40))
    $script:TestBusyProcess='Photoshop';Assert-Test ((Scan-DesktopNewItems $config) -eq 0) '创作软件运行时暂停';$script:TestBusyProcess=$null
    Assert-Test ((Scan-DesktopNewItems $config) -eq 1) '创作软件退出后可整理'

    $large=Join-Path $script:Desktop '大视频.mp4';$fs=[IO.File]::Create($large);$fs.SetLength(101MB);$fs.Close();[IO.File]::SetLastWriteTime($large,(Get-Date).AddMinutes(-40));[IO.File]::SetLastAccessTime($large,(Get-Date).AddMinutes(-40));$script:TestOnBattery=$true
    Assert-Test ((Scan-DesktopNewItems $config) -eq 0) '电池模式跳过大文件';Assert-Test (Test-Path $large) '大文件保持原位';$script:TestOnBattery=$false
    $script:TestFullScreen=$true;Assert-Test (-not (Test-CanPrompt $config)) '全屏模式禁止弹窗';$script:TestFullScreen=$false

    $sameDir=Join-Path $script:DataRoot 'same';New-Item -ItemType Directory $sameDir -Force|Out-Null;Set-Content (Join-Path $sameDir '文件.txt') 'a';$unique=Get-UniqueDestination $sameDir '文件.txt';Assert-Test ($unique.EndsWith('文件 (2).txt')) '同名文件自动避让'
    $report=[ordered]@{Passed=$true;Time=(Get-Date).ToString('o');Desktop=$script:Desktop;Checks=16};Save-Json $report (Join-Path $script:DataRoot 'selftest-result.json');Write-Output 'SELFTEST_PASS checks=16'
}

function Show-Workbench {
    if ($script:Form.Visible) { $script:Form.Activate(); Refresh-Workbench; return }
    Refresh-Workbench; $script:Form.Show(); $script:Form.Activate()
}

function Refresh-Workbench {
    $config=Get-Config; $script:Refreshing=$true; $script:AutomationCheck.Checked=[bool](Get-Setting $config 'AutomationEnabled' $true); $script:Refreshing=$false
    $script:FolderPathLabel.Text=$script:Desktop
    $script:FileList.Items.Clear()
    $projectCounts=@{}
    Get-ChildItem -LiteralPath $script:Desktop -Force | Where-Object{$_.Name -ne '桌面整理' -and $config.IgnoredNames -notcontains $_.Name} | ForEach-Object { $class=Get-Classification $_ $config;$row=New-Object Windows.Forms.ListViewItem($_.Name);$row.SubItems.Add($class.Project)|Out-Null;$row.SubItems.Add('待整理')|Out-Null;$row.SubItems.Add($_.LastWriteTime.ToString('MM-dd HH:mm'))|Out-Null;$row.Tag=$_.FullName;$row.ForeColor=[Drawing.Color]::FromArgb(198,119,40);$script:FileList.Items.Add($row)|Out-Null;if(-not$projectCounts.ContainsKey($class.Project)){$projectCounts[$class.Project]=0};$projectCounts[$class.Project]++ }
    Get-ChildItem -LiteralPath $script:RecentRoot -Directory -Force | ForEach-Object { $project=$_; Get-ChildItem -LiteralPath $_.FullName -Force | ForEach-Object { $row=New-Object Windows.Forms.ListViewItem($_.Name); $row.SubItems.Add($project.Name)|Out-Null;$row.SubItems.Add('最近一周')|Out-Null; $row.SubItems.Add($_.LastWriteTime.ToString('MM-dd HH:mm'))|Out-Null; $row.Tag=$_.FullName;$row.ForeColor=[Drawing.Color]::FromArgb(69,107,255); $script:FileList.Items.Add($row)|Out-Null;if(-not$projectCounts.ContainsKey($project.Name)){$projectCounts[$project.Name]=0};$projectCounts[$project.Name]++ } }
    $script:ProjectList.Items.Clear();foreach($projectName in $projectCounts.Keys|Sort-Object){$status=Get-ProjectStatus $projectName;$row=New-Object Windows.Forms.ListViewItem($projectName);$row.SubItems.Add($status)|Out-Null;$row.SubItems.Add($projectCounts[$projectName].ToString())|Out-Null;$row.Tag=$projectName;if($status-eq'暂停'){$row.ForeColor=[Drawing.Color]::FromArgb(198,119,40)}elseif($status-eq'已交付'){$row.ForeColor=[Drawing.Color]::FromArgb(42,178,123)};$script:ProjectList.Items.Add($row)|Out-Null}
    $busy=Get-BusyProcess $config; $reason=if($busy){"创作软件运行中：$busy"}elseif(Test-IsFullScreen){'全屏勿扰中'}elseif(Test-OnBattery){'使用电池：暂停大文件扫描'}elseif(Test-QuietHours $config){'夜间静默扫描，次日上午询问'}else{'可以整理'}; $script:StatusLabel.Text="状态：$reason"
    $script:CountLabel.Text="$($script:FileList.Items.Count) 个内容"
}

function Select-WorkspaceFolder {
    $dialog=New-Object Windows.Forms.FolderBrowserDialog;$dialog.Description='选择需要整理的文件夹';$dialog.SelectedPath=$script:Desktop;$dialog.ShowNewFolderButton=$true
    if($dialog.ShowDialog($script:Form) -eq 'OK'){
        Set-ConfigValue 'SourceFolder' $dialog.SelectedPath;Set-WorkspaceFolder $dialog.SelectedPath
        $known=@{};Get-ChildItem -LiteralPath $script:Desktop -Force|Where-Object{$_.Name-ne'桌面整理'}|ForEach-Object{$known[$_.FullName]=$_.LastWriteTimeUtc.Ticks};Save-Json ([ordered]@{Initialized=(Get-Date).ToString('o');KnownDesktopItems=$known}) $script:StatePath
        Refresh-Workbench;Add-Chat '助手' "已切换到【$($script:Desktop)】。现有文件已显示，只有勾选后才会整理。"
    }
}

function Organize-Selected {
    $checked=@($script:FileList.CheckedItems);if($checked.Count-eq 0){[Windows.Forms.MessageBox]::Show('请先勾选想整理的文件。',$script:AppName)|Out-Null;return}
    $config=Get-Config;$plans=@();foreach($row in $checked){$path=[string]$row.Tag;if(-not $path.StartsWith($script:RecentRoot,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path)){$item=Get-Item -LiteralPath $path;$class=Get-Classification $item $config;$plans+=[pscustomobject]@{Source=$path;Name=$item.Name;Destination=(Join-Path $script:RecentRoot $class.Project);Reason=$class.Reason}}}
    if($plans.Count-eq 0){[Windows.Forms.MessageBox]::Show('选中的内容已经在“最近一周”中。',$script:AppName)|Out-Null;return}
    if(Show-Confirmation '整理选中内容' '以下内容将按项目放入“最近一周”档案区：' $plans){foreach($p in $plans){Move-Safely $p.Source $p.Destination};Refresh-Workbench}
}

function Save-AutomationToggle {
    if($script:Refreshing){return}
    $c=Get-Config; $map=[ordered]@{}; $c.PSObject.Properties|ForEach-Object{$map[$_.Name]=$_.Value}; $map.AutomationEnabled=$script:AutomationCheck.Checked; Save-Json $map $script:ConfigPath; Write-Log "自动整理开关：$($script:AutomationCheck.Checked)"
}

function Invoke-EndWorkday {
    $config=Get-Config; $checked=@($script:FileList.CheckedItems); if($checked.Count -eq 0){[Windows.Forms.MessageBox]::Show('请先勾选今天已经完成处理的文件。',$script:AppName)|Out-Null;return}
    $plans=@(); foreach($row in $checked){$item=Get-Item -LiteralPath $row.Tag; $plans+=Get-ArchivePlan $item $row.SubItems[1].Text $config '今天收工'}
    if(Show-Confirmation '今天收工' '以下勾选内容将归档：' $plans){foreach($p in $plans){Move-Safely $p.Source $p.Destination};Refresh-Workbench}
}

function Change-SelectedProjectStatus {
    if($script:ProjectList.SelectedItems.Count -eq 0){return}; $project=$script:ProjectList.SelectedItems[0].Tag; $status=[string]$script:StatusCombo.SelectedItem; if(-not $status){return}
    if($status -eq '已交付') { if([Windows.Forms.MessageBox]::Show("把项目【$project】标记为已交付并立即归档？",$script:AppName,'YesNo','Question') -ne 'Yes'){return}; Complete-Project $project (Get-Config)|Out-Null } else { Set-ProjectStatus $project $status }
    Refresh-Workbench
}

$script:Refreshing=$false;$script:AllowExit=$false;$bg=[Drawing.Color]::FromArgb(245,246,250);$ink=[Drawing.Color]::FromArgb(29,32,42);$muted=[Drawing.Color]::FromArgb(112,117,132);$blue=[Drawing.Color]::FromArgb(69,107,255);$purple=[Drawing.Color]::FromArgb(126,87,255);$green=[Drawing.Color]::FromArgb(42,178,123);$orange=[Drawing.Color]::FromArgb(245,158,66)
$script:Form=New-Object Windows.Forms.Form;$script:Form.Text='Luma · 文件工作台';$script:Form.Size=New-Object Drawing.Size(1060,840);$script:Form.MinimumSize=New-Object Drawing.Size(980,760);$script:Form.StartPosition='CenterScreen';$script:Form.BackColor=$bg;$script:Form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10);$script:Form.AutoScaleMode='Dpi'
$title=New-Object Windows.Forms.Label;$title.Text='文件工作台';$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',22,[Drawing.FontStyle]::Bold);$title.ForeColor=$ink;$title.Location=New-Object Drawing.Point(34,24);$title.AutoSize=$true
$subtitle=New-Object Windows.Forms.Label;$subtitle.Text='让灵感留在桌面，让整理在身后发生';$subtitle.ForeColor=$muted;$subtitle.Location=New-Object Drawing.Point(38,66);$subtitle.AutoSize=$true
$script:AutomationCheck=New-Object Windows.Forms.CheckBox;$script:AutomationCheck.Text='自动整理';$script:AutomationCheck.ForeColor=$ink;$script:AutomationCheck.Location=New-Object Drawing.Point(760,34);$script:AutomationCheck.AutoSize=$true
$settingsBtn=New-Object RoundedButton;$settingsBtn.Text='设置';$settingsBtn.BackColor=[Drawing.Color]::White;$settingsBtn.ForeColor=$ink;$settingsBtn.Location=New-Object Drawing.Point(910,25);$settingsBtn.Size=New-Object Drawing.Size(105,42)

$folderCard=New-Object RoundedPanel;$folderCard.BackColor=[Drawing.Color]::White;$folderCard.Location=New-Object Drawing.Point(34,96);$folderCard.Size=New-Object Drawing.Size(982,92);$folderTitle=New-Object Windows.Forms.Label;$folderTitle.Text='正在整理';$folderTitle.ForeColor=$muted;$folderTitle.Location=New-Object Drawing.Point(22,16);$folderTitle.AutoSize=$true
$script:FolderPathLabel=New-Object Windows.Forms.Label;$script:FolderPathLabel.Font=New-Object Drawing.Font('Microsoft YaHei UI',11,[Drawing.FontStyle]::Bold);$script:FolderPathLabel.ForeColor=$ink;$script:FolderPathLabel.Location=New-Object Drawing.Point(22,43);$script:FolderPathLabel.Size=New-Object Drawing.Size(690,28);$script:FolderPathLabel.AutoEllipsis=$true
$chooseBtn=New-Object RoundedButton;$chooseBtn.Text='选择文件夹';$chooseBtn.BackColor=$blue;$chooseBtn.ForeColor=[Drawing.Color]::White;$chooseBtn.Location=New-Object Drawing.Point(802,24);$chooseBtn.Size=New-Object Drawing.Size(150,46);$folderCard.Controls.AddRange(@($folderTitle,$script:FolderPathLabel,$chooseBtn))

$contentCard=New-Object RoundedPanel;$contentCard.BackColor=[Drawing.Color]::White;$contentCard.Location=New-Object Drawing.Point(34,206);$contentCard.Size=New-Object Drawing.Size(982,400)
$contentTitle=New-Object Windows.Forms.Label;$contentTitle.Text='内容';$contentTitle.Font=New-Object Drawing.Font('Microsoft YaHei UI',14,[Drawing.FontStyle]::Bold);$contentTitle.ForeColor=$ink;$contentTitle.Location=New-Object Drawing.Point(22,17);$contentTitle.AutoSize=$true
$script:CountLabel=New-Object Windows.Forms.Label;$script:CountLabel.ForeColor=$muted;$script:CountLabel.Location=New-Object Drawing.Point(86,23);$script:CountLabel.AutoSize=$true
$tabs=New-Object Windows.Forms.TabControl;$tabs.Location=New-Object Drawing.Point(18,54);$tabs.Size=New-Object Drawing.Size(946,272);$tabs.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$filesTab=New-Object Windows.Forms.TabPage;$filesTab.Text='文件清单';$filesTab.BackColor=[Drawing.Color]::White;$projectsTab=New-Object Windows.Forms.TabPage;$projectsTab.Text='项目状态';$projectsTab.BackColor=[Drawing.Color]::White
$script:FileList=New-Object Windows.Forms.ListView;$script:FileList.Dock='Fill';$script:FileList.View='Details';$script:FileList.CheckBoxes=$true;$script:FileList.FullRowSelect=$true;$script:FileList.BorderStyle='None';$script:FileList.BackColor=[Drawing.Color]::FromArgb(250,250,253);$script:FileList.Columns.Add('文件',430)|Out-Null;$script:FileList.Columns.Add('项目',180)|Out-Null;$script:FileList.Columns.Add('位置',130)|Out-Null;$script:FileList.Columns.Add('更新时间',145)|Out-Null;$filesTab.Controls.Add($script:FileList)
$script:ProjectList=New-Object Windows.Forms.ListView;$script:ProjectList.Dock='Fill';$script:ProjectList.View='Details';$script:ProjectList.FullRowSelect=$true;$script:ProjectList.BorderStyle='None';$script:ProjectList.BackColor=[Drawing.Color]::FromArgb(250,250,253);$script:ProjectList.Columns.Add('项目',500)|Out-Null;$script:ProjectList.Columns.Add('状态',220)|Out-Null;$script:ProjectList.Columns.Add('文件数',120)|Out-Null;$projectsTab.Controls.Add($script:ProjectList);$tabs.TabPages.AddRange(@($filesTab,$projectsTab))
$organizeBtn=New-Object RoundedButton;$organizeBtn.Text='整理选中';$organizeBtn.BackColor=$blue;$organizeBtn.ForeColor=[Drawing.Color]::White;$organizeBtn.Location=New-Object Drawing.Point(22,340);$organizeBtn.Size=New-Object Drawing.Size(150,42)
$endBtn=New-Object RoundedButton;$endBtn.Text='今天收工';$endBtn.BackColor=$purple;$endBtn.ForeColor=[Drawing.Color]::White;$endBtn.Location=New-Object Drawing.Point(184,340);$endBtn.Size=New-Object Drawing.Size(150,42)
$selectAllBtn=New-Object RoundedButton;$selectAllBtn.Text='全选 / 取消';$selectAllBtn.BackColor=[Drawing.Color]::FromArgb(236,239,246);$selectAllBtn.ForeColor=$ink;$selectAllBtn.Location=New-Object Drawing.Point(346,340);$selectAllBtn.Size=New-Object Drawing.Size(140,42)
$script:StatusCombo=New-Object Windows.Forms.ComboBox;$script:StatusCombo.DropDownStyle='DropDownList';[void]$script:StatusCombo.Items.AddRange(@('进行中','暂停','已交付'));$script:StatusCombo.SelectedIndex=0;$script:StatusCombo.Location=New-Object Drawing.Point(610,346);$script:StatusCombo.Size=New-Object Drawing.Size(150,32)
$applyStatus=New-Object RoundedButton;$applyStatus.Text='应用项目状态';$applyStatus.BackColor=$green;$applyStatus.ForeColor=[Drawing.Color]::White;$applyStatus.Location=New-Object Drawing.Point(772,340);$applyStatus.Size=New-Object Drawing.Size(172,42);$contentCard.Controls.AddRange(@($contentTitle,$script:CountLabel,$tabs,$organizeBtn,$endBtn,$selectAllBtn,$script:StatusCombo,$applyStatus))

$chatCard=New-Object RoundedPanel;$chatCard.BackColor=[Drawing.Color]::White;$chatCard.Location=New-Object Drawing.Point(34,624);$chatCard.Size=New-Object Drawing.Size(982,142)
$chatLabel=New-Object Windows.Forms.Label;$chatLabel.Text='对话助手';$chatLabel.Font=New-Object Drawing.Font('Microsoft YaHei UI',12,[Drawing.FontStyle]::Bold);$chatLabel.ForeColor=$ink;$chatLabel.Location=New-Object Drawing.Point(20,14);$chatLabel.AutoSize=$true
$script:StatusLabel=New-Object Windows.Forms.Label;$script:StatusLabel.ForeColor=$green;$script:StatusLabel.Location=New-Object Drawing.Point(710,17);$script:StatusLabel.Size=New-Object Drawing.Size(240,24);$script:StatusLabel.TextAlign='MiddleRight'
$script:ChatHistory=New-Object Windows.Forms.TextBox;$script:ChatHistory.Location=New-Object Drawing.Point(20,44);$script:ChatHistory.Size=New-Object Drawing.Size(930,40);$script:ChatHistory.Multiline=$true;$script:ChatHistory.ReadOnly=$true;$script:ChatHistory.BorderStyle='None';$script:ChatHistory.BackColor=[Drawing.Color]::White;$script:ChatHistory.ForeColor=$muted;$script:ChatHistory.Text='助手：选一个文件夹，我会立即显示其中内容。你也可以直接说“把示例设为已交付”。'
$script:ChatInput=New-Object Windows.Forms.TextBox;$script:ChatInput.Location=New-Object Drawing.Point(20,99);$script:ChatInput.Size=New-Object Drawing.Size(800,30);$script:ChatInput.BorderStyle='FixedSingle'
$sendBtn=New-Object RoundedButton;$sendBtn.Text='发送';$sendBtn.BackColor=$orange;$sendBtn.ForeColor=[Drawing.Color]::White;$sendBtn.Location=New-Object Drawing.Point(832,93);$sendBtn.Size=New-Object Drawing.Size(118,38);$chatCard.Controls.AddRange(@($chatLabel,$script:StatusLabel,$script:ChatHistory,$script:ChatInput,$sendBtn))
$script:Form.Controls.AddRange(@($title,$subtitle,$script:AutomationCheck,$settingsBtn,$folderCard,$contentCard,$chatCard));$script:Form.Add_FormClosing({if(-not $script:AllowExit){$_.Cancel=$true;$script:Form.Hide()}});$script:AutomationCheck.Add_CheckedChanged({Save-AutomationToggle});$chooseBtn.Add_Click({Select-WorkspaceFolder});$organizeBtn.Add_Click({Organize-Selected});$endBtn.Add_Click({Invoke-EndWorkday});$selectAllBtn.Add_Click({$target=$script:FileList.CheckedItems.Count-ne$script:FileList.Items.Count;foreach($item in $script:FileList.Items){$item.Checked=$target}});$applyStatus.Add_Click({Change-SelectedProjectStatus})

function Add-Chat([string]$Who,[string]$Text) { $script:ChatHistory.AppendText("$Who：$Text`r`n"); $script:ChatHistory.SelectionStart=$script:ChatHistory.TextLength; $script:ChatHistory.ScrollToCaret() }
function Set-ConfigValue([string]$Name,$Value) { $c=Get-Config; $m=[ordered]@{}; $c.PSObject.Properties|ForEach-Object{$m[$_.Name]=$_.Value}; $m[$Name]=$Value; Save-Json $m $script:ConfigPath }
function Show-SettingsDialog {
    $c=Get-Config; $f=New-Object Windows.Forms.Form; $f.Text='整理设置'; $f.Size=New-Object Drawing.Size(410,360); $f.StartPosition='CenterParent'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
    $labels=@('每日整理提醒时间','文件保护时间（分钟）','归档等待天数','夜间静默开始','次日恢复提醒'); $ys=@(28,78,128,178,228)
    for($i=0;$i -lt $labels.Count;$i++){$l=New-Object Windows.Forms.Label;$l.Text=$labels[$i];$l.Location=New-Object Drawing.Point(20,$ys[$i]);$l.Size=New-Object Drawing.Size(170,25);$f.Controls.Add($l)}
    $cleanup=New-Object Windows.Forms.DateTimePicker;$cleanup.Format='Custom';$cleanup.CustomFormat='HH:mm';$cleanup.ShowUpDown=$true;$cleanup.Value=(Get-Date).Date.Add([TimeSpan]::Parse([string](Get-Setting $c 'CleanupTime' '20:00')));$cleanup.Location=New-Object Drawing.Point(215,24)
    $protect=New-Object Windows.Forms.NumericUpDown;$protect.Minimum=5;$protect.Maximum=240;$protect.Value=[decimal](Get-Setting $c 'RecentProtectionMinutes' 30);$protect.Location=New-Object Drawing.Point(215,74)
    $days=New-Object Windows.Forms.NumericUpDown;$days.Minimum=1;$days.Maximum=365;$days.Value=[decimal](Get-Setting $c 'ArchiveAfterDays' 7);$days.Location=New-Object Drawing.Point(215,124)
    $quietStart=New-Object Windows.Forms.NumericUpDown;$quietStart.Minimum=0;$quietStart.Maximum=23;$quietStart.Value=[decimal](Get-Setting $c 'QuietStartHour' 22);$quietStart.Location=New-Object Drawing.Point(215,174)
    $quietEnd=New-Object Windows.Forms.NumericUpDown;$quietEnd.Minimum=0;$quietEnd.Maximum=23;$quietEnd.Value=[decimal](Get-Setting $c 'QuietEndHour' 9);$quietEnd.Location=New-Object Drawing.Point(215,224)
    $save=New-Object Windows.Forms.Button;$save.Text='保存';$save.Location=New-Object Drawing.Point(215,274);$save.Size=New-Object Drawing.Size(150,36)
    $f.Controls.AddRange(@($cleanup,$protect,$days,$quietStart,$quietEnd,$save));$save.Add_Click({Set-ConfigValue 'CleanupTime' $cleanup.Value.ToString('HH:mm');Set-ConfigValue 'RecentProtectionMinutes' ([int]$protect.Value);Set-ConfigValue 'ArchiveAfterDays' ([int]$days.Value);Set-ConfigValue 'QuietStartHour' ([int]$quietStart.Value);Set-ConfigValue 'QuietEndHour' ([int]$quietEnd.Value);$f.DialogResult='OK';$f.Close()});[void]$f.ShowDialog($script:Form)
}
function Invoke-ChatCommand {
    $text=$script:ChatInput.Text.Trim(); if(-not $text){return}; $script:ChatInput.Clear(); Add-Chat '你' $text
    if($text -match '立即.*(整理|扫描)|马上.*(整理|扫描)'){Invoke-FullScan $true; Refresh-Workbench; Add-Chat '助手' '已经完成一次扫描。'}
    elseif($text -match '(.+?)(项目)?(设为|设置为|标记为)(进行中|暂停|已交付)'){ $project=$matches[1].Trim(); $status=$matches[4]; $folder=Get-ChildItem -LiteralPath $script:RecentRoot -Directory|Where-Object{$_.Name -like "*$project*"}|Select-Object -First 1; if(-not $folder){Add-Chat '助手' "没有找到名称包含【$project】的项目。"}elseif($status -eq '已交付'){if([Windows.Forms.MessageBox]::Show("把项目【$($folder.Name)】标记为已交付并归档？",$script:AppName,'YesNo','Question') -eq 'Yes'){Complete-Project $folder.Name (Get-Config)|Out-Null;Add-Chat '助手' "【$($folder.Name)】已标记为已交付并归档。"}}else{Set-ProjectStatus $folder.Name $status;Add-Chat '助手' "【$($folder.Name)】已设为$status。"};Refresh-Workbench }
    elseif($text -match '今天收工|收工'){ Invoke-EndWorkday; Add-Chat '助手' '已处理你在“今天收工”页勾选的文件；未勾选内容保持不动。'}
    elseif($text -match '暂停(自动)?整理|关闭(自动)?整理|停止(自动)?整理'){ $script:AutomationCheck.Checked=$false; Add-Chat '助手' '自动整理已关闭。需要恢复时告诉我【开启整理】。'}
    elseif($text -match '开启(自动)?整理|打开(自动)?整理|恢复(自动)?整理'){ $script:AutomationCheck.Checked=$true; Add-Chat '助手' '自动整理已开启。创作软件运行时仍会自动暂停。'}
    elseif($text -match '(晚上|每天|夜间)?.*?([01]?\d|2[0-3])[:点时]([0-5]?\d)?.*(整理|归档)'){ $hour=[int]$matches[2];$minute=if($matches[3]){[int]$matches[3]}else{0};Set-ConfigValue 'CleanupTime' ('{0:00}:{1:00}' -f $hour,$minute);Add-Chat '助手' ("每日整理提醒已设为 {0:00}:{1:00}。" -f $hour,$minute) }
    elseif($text -match '打开.*最近'){Open-Path $script:RecentRoot;Add-Chat '助手' '已打开“最近一周”。'}
    elseif($text -match '打开.*归档'){Open-Path $script:ArchiveRoot;Add-Chat '助手' '已打开归档目录。'}
    elseif($text -match '状态|怎么样|情况'){Refresh-Workbench;Add-Chat '助手' $script:StatusLabel.Text}
    else {Add-Chat '助手' '我暂时没理解。你可以说：立即整理、暂停整理、开启整理、今天收工、把某项目设为已交付、打开最近一周。'}
}
$settingsBtn.Add_Click({Show-SettingsDialog}); $sendBtn.Add_Click({Invoke-ChatCommand}); $script:ChatInput.Add_KeyDown({if($_.KeyCode -eq 'Enter'){$_.SuppressKeyPress=$true;Invoke-ChatCommand}})

$createdNew=$false
$mutexName=if($SelfTest -or $SmokeTest){'Local\DesktopOrganizerCN_Test_'+[Math]::Abs($script:Desktop.GetHashCode())}else{'Local\DesktopOrganizerCN_SingleInstance'}
$script:Mutex=New-Object Threading.Mutex($true,$mutexName,[ref]$createdNew)
if (-not $createdNew) { [System.Windows.Forms.MessageBox]::Show('程序已经在运行。请查看任务栏通知区域。',$script:AppName,'OK','Information') | Out-Null; exit }
Initialize-App
if ($InitializeBaseline) { exit }
if ($SelfTest) { try { Invoke-IsolatedSelfTest; exit 0 } catch { Write-Log $_.Exception.ToString(); Write-Error $_.Exception.Message; exit 1 } }
if ($ScanOnce) { Invoke-FullScan $true; exit }

$menu=New-Object Windows.Forms.ContextMenuStrip
$workbenchItem=$menu.Items.Add('打开桌面工作台'); $scanItem=$menu.Items.Add('立即扫描'); $openRecent=$menu.Items.Add('打开“最近一周”'); $openArchive=$menu.Items.Add('打开归档'); $configItem=$menu.Items.Add('编辑时间与分类配置'); $logItem=$menu.Items.Add('查看日志'); $menu.Items.Add('-') | Out-Null; $exitItem=$menu.Items.Add('退出')
$tray=New-Object Windows.Forms.NotifyIcon
$tray.Icon=[Drawing.SystemIcons]::Application; $tray.Text=$script:AppName; $tray.ContextMenuStrip=$menu; $tray.Visible=$true
$timer=New-Object Windows.Forms.Timer; $timer.Interval=[Math]::Max(1,[int](Get-Config).ScanMinutes)*60000
$script:WasBusy=$null; $workbenchItem.Add_Click({Show-Workbench}); $scanItem.Add_Click({ Invoke-FullScan $true; Refresh-Workbench }); $openRecent.Add_Click({ Open-Path $script:RecentRoot }); $openArchive.Add_Click({ Open-Path $script:ArchiveRoot }); $configItem.Add_Click({ Start-Process notepad.exe -ArgumentList ('"{0}"' -f $script:ConfigPath) }); $logItem.Add_Click({ Start-Process notepad.exe -ArgumentList ('"{0}"' -f $script:LogPath) })
$tray.Add_DoubleClick({ Show-Workbench }); $timer.Add_Tick({ $c=Get-Config; $busy=Get-BusyProcess $c; if($script:WasBusy -and -not $busy -and [bool](Get-Setting $c 'WorkdayReminderEnabled' $true) -and (Test-CanPrompt $c)){ $tray.ShowBalloonTip(5000,'创作软件已退出','要不要打开工作台，勾选文件并执行【今天收工】？','Info') }; $script:WasBusy=$busy; Invoke-FullScan $false; if($script:Form.Visible){Refresh-Workbench} }); $exitItem.Add_Click({ $script:AllowExit=$true; $timer.Stop(); $tray.Visible=$false; $script:Form.Close(); [Windows.Forms.Application]::Exit() })
$tray.ShowBalloonTip(3000,$script:AppName,'已在后台运行。右键托盘图标可立即扫描或编辑规则。','Info')
$script:WasBusy=Get-BusyProcess (Get-Config); $timer.Start(); Invoke-FullScan $false; Show-Workbench; if($SmokeTest){$smoke=New-Object Windows.Forms.Timer;$smoke.Interval=1500;$smoke.Add_Tick({$smoke.Stop();$script:AllowExit=$true;$timer.Stop();$tray.Visible=$false;$script:Form.Close();[Windows.Forms.Application]::Exit()});$smoke.Start()}; [Windows.Forms.Application]::Run()
$tray.Dispose(); $timer.Dispose(); $script:Mutex.ReleaseMutex(); $script:Mutex.Dispose()
