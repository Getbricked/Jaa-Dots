-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

local dsp = hl.dsp or hl

local function exec_cmd(cmd)
  if dsp and dsp.exec_cmd then
    return dsp.exec_cmd(cmd)
  end
  return function() hl.exec_cmd(cmd) end
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function chord(mods, key)
  mods = trim(mods):gsub("%s+", " + ")
  key = trim(key)
  if mods == "" then
    return key
  end
  return mods .. " + " .. key
end

local function key_variants(key)
  key = trim(key)
  return { key }
end

local function workspace_value(value)
  value = trim(value)
  return tonumber(value) or value
end

local function dispatch(name, args)
  local window_api = (dsp and dsp.window) or hl.window or {}
  name = trim(name)
  args = trim(args)
  if name == "exec" then
    return exec_cmd(args)
  end
  if name == "workspace" and dsp and dsp.focus then
    return function() hl.dispatch(dsp.focus({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspace" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspacesilent" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false })) end
  end
  if name == "togglefloating" and window_api.float then
    return function() hl.dispatch(window_api.float({ action = "toggle" })) end
  end
  if args ~= "" then
    return exec_cmd("hyprctl dispatch " .. name .. " " .. args)
  end
  return exec_cmd("hyprctl dispatch " .. name)
end

local function bind(mods, key, fn, opts)
  local seen = {}
  for _, key_variant in ipairs(key_variants(key)) do
    local key_chord = chord(mods, key_variant)
    if not seen[key_chord] then
      seen[key_chord] = true
      if opts then
        hl.bind(key_chord, fn, opts)
      else
        hl.bind(key_chord, fn)
      end
    end
  end
end

local function unbind(mods, key)
  if hl.unbind then
    local seen = {}
    for _, key_variant in ipairs(key_variants(key)) do
      local key_chord = chord(mods, key_variant)
      if not seen[key_chord] then
        seen[key_chord] = true
        local ok = pcall(hl.unbind, mods, key_variant)
        if not ok then
          pcall(hl.unbind, key_chord)
        end
      end
    end
  end
end

return {
  exec_cmd = exec_cmd,
  trim = trim,
  chord = chord,
  key_variants = key_variants,
  workspace_value = workspace_value,
  dispatch = dispatch,
  bind = bind,
  unbind = unbind,
}
