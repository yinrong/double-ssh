# double-ssh — 内部设计笔记

## 为什么图片粘贴要绕一圈

Claude Code 的 `Ctrl+V` 读图只在本地或"终端能把剪贴板图片编码成 PTY 流"时有效。截至 2026-04：
- OSC 52 只传文本
- WezTerm PR #7624（native smart paste + SFTP）仍未合并
- Windows Terminal / GNOME Terminal / Konsole / Alacritty 都只处理文本粘贴

所以这里用最小化工作流：WezTerm Lua 拦截 `Ctrl+Shift+V` → 调 `clip2c` → 从 OS 剪贴板抓图 → 通过已建立的 SSH ControlMaster 通道 scp 到 `C:~/claude-clips/` → 把远端路径字符串注入 PTY。Claude Code 按路径读图。

## ControlMaster 为什么重要

`clip2c` 里有一次 scp。如果每次都重新握手（密钥交换 + B→C 跳板），延迟约 800ms–2s，用户能明显感知卡顿。ControlMaster 把连接多路复用到 `~/.ssh/cm-%r@%h:%p` socket，scp 复用它后延迟降到 ~100ms。

## 脚本自动处理的事项

以下问题均在脚本里静默解决，不需要用户知道：
- `~/.ssh` 权限 0700（ControlMaster socket 依赖此）
- Wayland vs X11 检测（`clip2c.sh` 先查 `$WAYLAND_DISPLAY`，回落到 xclip）
- WezTerm 来源（`apt.fury.io/wez/`，绕过发行版过旧的包）
- Node.js 版本（NodeSource 20.x，24.04 自带 18.x 不够）
- ssh-agent 自动启动 + `ssh-add`（带 passphrase 的 key 不会卡 scp）
- Windows PowerShell 弹窗（`-WindowStyle Hidden`）
- `~/claude-clips/` 目录初始化（`install-c.sh` 建，`clip2c.sh` 有防御性 mkdir）
