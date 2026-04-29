-- contool WezTerm config.
-- Ctrl+Shift+V: if clipboard holds an image, clip2c saves it to C:~/claude-clips/
-- and we inject the remote path into the PTY so Claude Code can read it.
-- If no image on clipboard, falls back to normal text paste.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local home = wezterm.home_dir
local is_win = wezterm.target_triple:find('windows') ~= nil

-- The ssh alias (defined in ~/.ssh/config) that clip2c uploads to.
-- Override by setting env CONTOOL_TARGET before launching WezTerm.
local target = os.getenv('CONTOOL_TARGET') or 'C'

local function paste_image(window, pane)
  local cmd
  if is_win then
    cmd = {
      'powershell', '-NoProfile', '-WindowStyle', 'Hidden',
      '-File', home .. '\\bin\\clip2c.ps1', target,
    }
  else
    cmd = { home .. '/.local/bin/clip2c', target }
  end
  local ok, stdout, _stderr = wezterm.run_child_process(cmd)
  if ok and stdout and #stdout > 1 then
    local path = stdout:gsub('%s+$', '')
    window:perform_action(act.SendString(path .. ' '), pane)
  else
    window:perform_action(act.PasteFrom 'Clipboard', pane)
  end
end

config.keys = {
  {
    key = 'V',
    mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(paste_image),
  },
}

return config
