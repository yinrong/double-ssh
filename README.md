# contool — A → B → C SSH chain with Claude Code image paste

三机 SSH 链 + Claude Code 安装脚手架：
- **A** 是你的笔记本（Windows 11 或 Ubuntu 24.04），装 VSCode + WezTerm
- **B** 是跳板机（Ubuntu/Debian），只做 ProxyJump
- **C** 是真正跑 Claude Code 的机器（Ubuntu/Debian）

VSCode Remote-SSH 和普通 SSH 终端都直通 C；在 WezTerm 里按 `Ctrl+Shift+V`
可以把 A 系统剪贴板里的图片**自动上传到 C:~/claude-clips/ 并把路径贴进
Claude Code 的 prompt** — 曲线救国，但当前（2026-04）这是唯一能工作的方案。

```
        ┌─────────────┐     ┌──────────┐     ┌──────────────┐
        │   A (你)    │────▶│    B     │────▶│      C       │
        │ VSCode +    │     │ sshd     │     │ claude-code  │
        │ WezTerm     │     │ (jump)   │     │ ~/claude-    │
        │ clip2c      │     │          │     │   clips/     │
        └─────────────┘     └──────────┘     └──────────────┘
           ssh C          ProxyJump B         SSH + scp via
                                              ControlMaster
```

## 目录结构

```
A/install-ubuntu.sh       Ubuntu 24.04 安装脚本（bash）
A/install-windows.ps1     Windows 11 安装脚本（PowerShell）
B/setup-sshd.sh           B 上 sshd + authorized_keys（需 sudo）
C/install-c.sh            C 上 openssh-server/Node 20/Claude Code
ssh/config.template       ~/.ssh/config 片段模板（含 ProxyJump + ControlMaster）
wezterm/wezterm.lua       WezTerm 配置：Ctrl+Shift+V 触发 clip2c
clip2c/clip2c.sh          Linux 侧剪贴板→SCP 助手
clip2c/clip2c.ps1         Windows 侧同上
```

## 安装顺序（**先 C，再 B，最后 A**）

A 的验证需要 B 和 C 先就绪，否则 `ssh C` 失败。

### 1. C 机器
```bash
scp C/install-c.sh userC@hostC:/tmp/
ssh userC@hostC
bash /tmp/install-c.sh      # 末尾会要求你贴 A 的 pubkey（可先跳过）
claude --version            # 验证 Claude Code 已安装
claude /login               # 或 export ANTHROPIC_API_KEY=...
```

### 2. B 机器
```bash
scp B/setup-sshd.sh userB@hostB:/tmp/
ssh userB@hostB
sudo bash /tmp/setup-sshd.sh    # 按提示贴 A 的 pubkey，会自动 reload sshd
```

### 3. A 机器
**Ubuntu 24.04**：
```bash
cd A
bash install-ubuntu.sh
# 输出的 pubkey 贴到 B 和 C 的 authorized_keys（或重跑 B/C 的脚本交互贴）
```

**Windows 11**（管理员 PowerShell）：
```powershell
cd A
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-windows.ps1
# 同上，把打印的 pubkey 贴到 B 和 C
```

## 验证

| 检查项 | 操作 | 预期 |
|---|---|---|
| SSH 链路 | 在 A 执行 `ssh C` | 免密直连，无需手动 ProxyCommand |
| ControlMaster | 开着一个 `ssh C` 窗口，另开一个 `scp /tmp/x C:~/` | <200ms 完成，无二次认证 |
| VSCode | VSCode 命令面板 → "Remote-SSH: Connect to Host" → `C` | 直接打开 C 的工作区 |
| Claude Code | 在 C 上 `claude` 启动 | 正常进入交互 |
| **图片粘贴** | A 截图 → WezTerm 里 `ssh C` → 跑 `claude` → `Ctrl+Shift+V` | prompt 出现 `~/claude-clips/wtc-YYYYMMDD-HHMMSS.png`，Claude 能描述图片 |

## 为什么图片粘贴要绕一圈

Claude Code 的 `Ctrl+V` 读图只在本地或 "终端能把剪贴板图片编码成 PTY
流"的情况下生效。截至 2026-04：
- OSC 52 只传文本；
- WezTerm PR #7624（native smart paste + SFTP）仍未合并；
- Windows Terminal / GNOME Terminal / Konsole / Alacritty 等都只处理文本粘贴。

所以我们自己做了最小化的工作流：WezTerm Lua 拦截 `Ctrl+Shift+V` → 调
`clip2c` → 从 OS 剪贴板抓图 → 通过已建立的 ControlMaster 通道 scp 到
`C:~/claude-clips/` → 把远端路径字符串注入 PTY。Claude Code 按路径读图即可。

## 坑清单

- **`~/.ssh` 权限**必须 0700，否则 ControlMaster socket 静默失效。
- **Wayland vs X11**：Ubuntu 24.04 GNOME 默认 Wayland；`install-ubuntu.sh`
  会同时装 `wl-clipboard` 和 `xclip`。
- **WezTerm 源**：发行版自带的 wezterm 版本太旧，不支持 `wezterm.action_callback`；
  脚本从 [apt.fury.io/wez](https://apt.fury.io/wez/) 装。
- **Node.js 版本**：C 机器必须 Node 20+；Ubuntu 24.04 默认的 18.x
  跑不起新版 Claude Code，脚本用 NodeSource setup_20.x。
- **带 passphrase 的 key**：安装脚本会启 ssh-agent 并 `ssh-add`，避免
  `clip2c` 里的 scp 卡住 Lua 回调。
- **`run_child_process` 同步阻塞**：ControlMaster 下 ~100ms，用户体感近乎
  瞬发；图非常大时会有轻微卡顿，属于 WezTerm 限制。
- **Windows 多窗口闪烁**：`clip2c.ps1` 用 `-WindowStyle Hidden` 隐藏控制台。
- **目标主机别名**：clip2c 默认上传到 ssh 别名 `C`。用别的名字请设置
  `CONTOOL_TARGET` 环境变量后再启 WezTerm。

## 改 / 卸

- 想换 `Ctrl+V`（抢占 WezTerm 默认粘贴）：改 `wezterm/wezterm.lua`
  `mods = 'CTRL|SHIFT'` → `mods = 'CTRL'`。
- 卸载：`~/.ssh/config` 里的 `# BEGIN contool` 到 `# END contool` 段手工删；
  `~/.config/wezterm/wezterm.lua`、`~/.local/bin/clip2c` (或 `~/bin/clip2c.ps1`)
  删除；B 的 sshd 改动无破坏性，保留也无妨。
