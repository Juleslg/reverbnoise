-- reverb_noise v1.0.0
-- Live audio processing with
-- reverb and noise blend
--
-- E1 - main volume
-- E2 - noise level
-- E3 - reverb mix
-- K2 + E2 - reverb time
-- K2 + E3 - reverb size
-- K3 + E2 - reverb damp
-- K3 + E3 - mod depth

engine.name = 'ReverbNoise'

local UI = require 'ui'
local util = require 'util'

-- State variables
local amp = 1.0
local noise = 0.0
local verb_mix = 0.0
local verb_time = 2.0
local verb_size = 1.0
local verb_damp = 0.0
local verb_mod_depth = 0.1
local verb_mod_freq = 2.0

-- UI state
local alt = false
local screen_dirty = true
local wave_points = {}
local wave_phase = 0

function init()
  -- Audio setup
  audio.level_adc(1.0)
  audio.level_eng_cut(1.0)
  audio.level_dac(1.0)
  
  -- Parameters
  params:add_control("amp", "Volume", controlspec.new(0, 2.0, 'lin', 0, 1.0, ""))
  params:set_action("amp", function(x) 
    amp = x
    engine.amp(amp)
  end)
  
  params:add_control("noise", "Noise", controlspec.new(0, 1.0, 'lin', 0, 0.0, ""))
  params:set_action("noise", function(x)
    noise = x
    engine.noise(noise)
  end)
  
  params:add_control("verb_mix", "Verb Mix", controlspec.new(0, 1.0, 'lin', 0, 0.0, ""))
  params:set_action("verb_mix", function(x)
    verb_mix = x
    engine.verb_mix(verb_mix)
  end)
  
  params:add_control("verb_time", "Verb Time", controlspec.new(0.1, 60.0, 'exp', 0, 2.0, "s"))
  params:set_action("verb_time", function(x)
    verb_time = x
    engine.verb_time(verb_time)
  end)
  
  params:add_control("verb_size", "Verb Size", controlspec.new(0.5, 5.0, 'lin', 0, 1.0, ""))
  params:set_action("verb_size", function(x)
    verb_size = x
    engine.verb_size(verb_size)
  end)
  
  params:add_control("verb_damp", "Verb Damp", controlspec.new(0, 1.0, 'lin', 0, 0.0, ""))
  params:set_action("verb_damp", function(x)
    verb_damp = x
    engine.verb_damp(verb_damp)
  end)
  
  params:add_control("verb_mod_depth", "Mod Depth", controlspec.new(0, 1.0, 'lin', 0, 0.1, ""))
  params:set_action("verb_mod_depth", function(x)
    verb_mod_depth = x
    engine.verb_mod_depth(verb_mod_depth)
  end)
  
  -- Initialize wave points
  for i=1,128 do
    wave_points[i] = 0
  end
  
  -- Start UI refresh
  screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function()
    update_wave()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  screen_refresh_metro:start(1/30)
end

function update_wave()
  wave_phase = (wave_phase + 0.02) % (math.pi * 2)
  for i=1,128 do
    local phase = wave_phase + (i/128) * math.pi * 2
    wave_points[i] = math.sin(phase) * (5 + noise * 10) + math.sin(phase * 1.5) * (verb_mix * 8)
  end
  screen_dirty = true
end

function key(n,z)
  if n == 2 then
    if z == 1 then
      alt = true
    else
      alt = false
    end
    screen_dirty = true
  end
end

function enc(n,d)
  if n == 1 then
    params:delta("amp", d)
  elseif n == 2 then
    if alt then
      params:delta("verb_time", d)
    else
      params:delta("noise", d)
    end
  elseif n == 3 then
    if alt then
      params:delta("verb_size", d)
    else
      params:delta("verb_mix", d)
    end
  end
  screen_dirty = true
end

function redraw()
  screen.clear()
  
  -- Draw title
  screen.level(15)
  screen.move(64, 8)
  screen.text_center("reverb noise")
  
  -- Draw wave visualization
  screen.level(3)
  for i=1,127 do
    screen.move(i, 32 + wave_points[i])
    screen.line(i+1, 32 + wave_points[i+1])
  end
  screen.stroke()
  
  -- Draw parameter values
  screen.level(15)
  screen.move(5, 50)
  screen.text(string.format("VOL:%.0f%%", amp * 100))
  
  screen.move(64, 50)
  screen.text_center(string.format("NOISE:%.0f%%", noise * 100))
  
  screen.move(123, 50)
  screen.text_right(string.format("VERB:%.0f%%", verb_mix * 100))
  
  if alt then
    screen.level(5)
    screen.move(64, 58)
    screen.text_center(string.format("TIME:%.1fs SIZE:%.1f", verb_time, verb_size))
  end
  
  screen.update()
end

function cleanup()
  if screen_refresh_metro then
    screen_refresh_metro:stop()
  end
end 