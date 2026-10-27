# 桌面文件工作台

PowerShell + Windows Forms 文件整理工具，提供基线保护、最近文件、项目归档、安静时段及繁忙应用检测。默认分类里的个人项目名称已替换为示例。

需要 Windows、Windows PowerShell 5.1 和桌面会话。工具会移动文件；先在测试文件夹验证分类，再用于真实桌面。

```powershell
powershell -NoProfile -File .\DesktopOrganizer.ps1 -DesktopOverride C:\SandboxDesktop -DataOverride C:\SandboxState
```

首次建立基线；后续运行可能整理新文件。`-SelfTest` 为内部测试入口，发布检查只做语法解析，未启动桌面整理流程。
