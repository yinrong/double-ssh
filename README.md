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

### 1. 在 C 上执行（用密码或已有 key 登录进去）

```bash
curl -fsSL https://raw.githubusercontent.com/yinrong/double-ssh/main/C/install-c.sh | bash
```

脚本结束后会提示你粘贴 A 的公钥——**先跳过**，等 A 装完再回来填。

然后配置 Claude Code 的 API 密钥（二选一）：

**方式一：浏览器登录（推荐）**
```bash
claude /login
```
按提示在浏览器里登录 Anthropic 账号即可，token 自动保存。

**方式二：手动填入 API Key**

到 https://console.anthropic.com/settings/keys 创建一个 key，然后：
```bash
# 写入 ~/.bashrc 让每次登录自动生效
echo 'export ANTHROPIC_API_KEY=sk-ant-你的密钥' >> ~/.bashrc
source ~/.bashrc
```

### 2. 在 B 上执行（用密码或已有 key 登录进去）

```bash
curl -fsSL https://raw.githubusercontent.com/yinrong/double-ssh/main/B/setup-sshd.sh | sudo bash
```

同样跳过粘贴公钥的步骤，等 A 装完再填。

### 3. 在 A 上执行

先克隆这个仓库：
```bash
git clone https://github.com/yinrong/double-ssh.git
cd double-ssh
```

**Ubuntu 24.04**：
```bash
bash A/install-ubuntu.sh
```

**Windows 11**（管理员 PowerShell）：
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\A\install-windows.ps1
```

脚本结束时会打印 A 的 SSH 公钥。**把这行公钥分别粘贴到 B 和 C 上**：

```bash
# 在 B 上执行：
echo "粘贴公钥到这里" >> ~/.ssh/authorized_keys

# 在 C 上执行：
echo "粘贴公钥到这里" >> ~/.ssh/authorized_keys
```

## 验证

| 检查项 | 操作 | 预期 |
|---|---|---|
| SSH 链路 | 在 A 执行 `ssh C` | 免密直连 |
| VSCode | 命令面板 → Remote-SSH: Connect to Host → `C` | 直接打开 C 的工作区 |
| Claude Code | 在 C 上 `claude` 启动 | 正常进入交互 |
| **图片粘贴** | A 截图 → WezTerm 里 `ssh C` → 跑 `claude` → `Ctrl+Shift+V` | prompt 出现 `~/claude-clips/wtc-....png`，Claude 能描述图片 |
