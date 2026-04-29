# double-ssh — A → B → C SSH chain with Claude Code image paste

三机 SSH 链 + Claude Code 安装脚手架：
- **A** 是你的笔记本（Windows 11 或 Ubuntu 24.04），装 VSCode + WezTerm
- **B** 是跳板机，只做 ProxyJump
- **C** 是真正跑 Claude Code 的机器（Ubuntu/Debian）

VSCode Remote-SSH 和普通 SSH 终端都直通 C；在 WezTerm 里按 `Ctrl+Shift+V` 可以把 A 剪贴板里的图片上传到 C 并贴进 Claude Code 的 prompt。

```
        ┌─────────────┐     ┌──────────┐     ┌──────────────┐
        │   A (你)    │────▶│    B     │────▶│      C       │
        │ VSCode +    │     │ sshd     │     │ claude-code  │
        │ WezTerm     │     │ (jump)   │     │ ~/claude-    │
        │ clip2c      │     │          │     │   clips/     │
        └─────────────┘     └──────────┘     └──────────────┘
```

## 目录结构

```
A/install-ubuntu.sh       Ubuntu 24.04 安装脚本
A/install-windows.ps1     Windows 11 安装脚本
B/setup-sshd.sh           B 上 sshd + authorized_keys
C/install-c.sh            C 上 openssh-server / Node 20 / Claude Code
ssh/config.template       ~/.ssh/config 片段（含 ProxyJump + ControlMaster）
wezterm/wezterm.lua       WezTerm 配置：Ctrl+Shift+V 触发图片粘贴
clip2c/clip2c.sh          Linux 侧剪贴板→SCP 助手
clip2c/clip2c.ps1         Windows 侧同上
```

## 安装顺序（先 C，再 B，最后 A）

### 1. C 机器
```bash
scp C/install-c.sh userC@hostC:/tmp/
ssh userC@hostC
bash /tmp/install-c.sh
claude /login               # 或 export ANTHROPIC_API_KEY=...
```

### 2. B 机器
```bash
scp B/setup-sshd.sh userB@hostB:/tmp/
ssh userB@hostB
sudo bash /tmp/setup-sshd.sh
```

### 3. A 机器
**Ubuntu 24.04**：
```bash
cd A && bash install-ubuntu.sh
```

**Windows 11**（管理员 PowerShell）：
```powershell
cd A
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-windows.ps1
```

每个脚本末尾会打印出 A 的 SSH 公钥，把它粘贴到 B 和 C 的 `authorized_keys`（脚本会交互提示你）。

## 验证

| 检查项 | 操作 | 预期 |
|---|---|---|
| SSH 链路 | 在 A 执行 `ssh C` | 免密直连 |
| VSCode | 命令面板 → Remote-SSH: Connect to Host → `C` | 直接打开 C 的工作区 |
| Claude Code | 在 C 上 `claude` 启动 | 正常进入交互 |
| **图片粘贴** | A 截图 → WezTerm 里 `ssh C` → 跑 `claude` → `Ctrl+Shift+V` | prompt 出现 `~/claude-clips/wtc-....png`，Claude 能描述图片 |
