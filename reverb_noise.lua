-- reverb_noise v1.0.0
-- Live audio processing with
-- reverb and noise blend
--
-- E1 - volume
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
local jitter_points = {}
local last_input_level = 0

-- Rain state for each parameter
local volume_drops = {}
local noise_drops = {}
local reverb_drops = {}
local MAX_DROPS = 30
local TRAIL_LENGTH = 6

-- Raindrop class with different styles
local Raindrop = {}
function Raindrop.new(style)
  local drop = {
    x = math.random(1, 128),
    y = math.random(-10, 0),
    trail = {},
    style = style
  }
  
  -- Different characteristics based on style
  if style == "volume" then
    drop.speed = math.random(4, 7) / 10
    drop.length = math.random(3, 5)
    drop.brightness = math.random(12, 15)
  elseif style == "noise" then
    drop.speed = math.random(2, 4) / 10
    drop.length = math.random(1, 2)
    drop.brightness = math.random(8, 12)
    drop.jitter = math.random() * 0.5
  else -- reverb
    drop.speed = math.random(3, 5) / 10
    drop.length = math.random(4, 6)
    drop.brightness = math.random(10, 13)
    drop.width = math.random(2, 3)
  end
  
  return drop
end

-- Add new state variables at the top with other state variables
local rotation = 0
local planet_radius = 10  -- Reduced from 15
local ring_radiuses = {16, 22, 28}  -- Reduced from {24, 32, 40}
local perspective_angle = 0.6

-- Text display positions
local text_x = 15
local text_y_start = 25
local text_spacing = 12
local bar_width = 20
local bar_height = 2

function calculate_ellipse_points(radius, rotation, num_points)
  local points = {}
  for i = 1, num_points do
    local angle = (i / num_points) * math.pi * 2
    local x = radius * math.cos(angle)
    local y = radius * math.sin(angle) * perspective_angle
    
    -- Rotate points
    local rotated_x = x * math.cos(rotation) - y * math.sin(rotation)
    local rotated_y = x * math.sin(rotation) + y * math.cos(rotation)
    
    points[i] = {x = rotated_x + 64, y = rotated_y + 32}  -- Center on screen
  end
  return points
end

function init()
  -- Audio setup
  audio.level_adc(1.0)
  audio.level_eng_cut(1.0)
  audio.level_dac(1.0)
  
  -- Initialize raindrops
  for i=1,MAX_DROPS do
    volume_drops[i] = Raindrop.new("volume")
    noise_drops[i] = Raindrop.new("noise")
    reverb_drops[i] = Raindrop.new("reverb")
  end
  
  -- Initialize jitter points
  for i=1,128 do
    jitter_points[i] = 0
  end
  
  -- Add input polling
  poll = poll.set("amp_in_l", function(val) 
    last_input_level = val
  end)
  poll.time = 1/30
  poll:start()
  
  -- Initialize screen refresh metro
  if screen_refresh_metro then
    screen_refresh_metro:stop()
  end
  screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function()
    update_display()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  screen_refresh_metro:start(1/30)
  
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
  
  params:add_control("verb_mix", "Verb Mix", controlspec.new(0, 3.0, 'lin', 0, 0.0, ""))  -- Limited to 300%
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
end

function update_display()
  -- Update rotation
  rotation = (rotation + 0.01) % (math.pi * 2)
  
  -- Update wave phase for effects
  wave_phase = (wave_phase + 0.02) % (math.pi * 2)
  
  -- Update volume rain
  if amp > 0.01 then
    local vol_intensity = math.floor(amp * MAX_DROPS / 2)
    for i=1,MAX_DROPS do
      if volume_drops[i] then
        local rotated_x = volume_drops[i].x * math.cos(rotation) - volume_drops[i].y * math.sin(rotation)
        table.insert(volume_drops[i].trail, 1, {x = rotated_x, y = volume_drops[i].y})
        if #volume_drops[i].trail > TRAIL_LENGTH then
          table.remove(volume_drops[i].trail)
        end
        
        volume_drops[i].y = volume_drops[i].y + volume_drops[i].speed
        if volume_drops[i].y > 64 then
          if i <= vol_intensity then
            volume_drops[i] = Raindrop.new("volume")
          else
            volume_drops[i] = nil
          end
        end
      elseif i <= vol_intensity then
        volume_drops[i] = Raindrop.new("volume")
      end
    end
  end
  
  -- Update noise rain
  if noise > 0.01 then
    local noise_intensity = math.floor(noise * MAX_DROPS)
    for i=1,MAX_DROPS do
      if noise_drops[i] then
        local jitter_x = noise_drops[i].x + math.sin(wave_phase * 5 + i) * noise_drops[i].jitter
        local rotated_x = jitter_x * math.cos(rotation) - noise_drops[i].y * math.sin(rotation)
        table.insert(noise_drops[i].trail, 1, {x = rotated_x, y = noise_drops[i].y})
        if #noise_drops[i].trail > TRAIL_LENGTH then
          table.remove(noise_drops[i].trail)
        end
        
        noise_drops[i].y = noise_drops[i].y + noise_drops[i].speed
        if noise_drops[i].y > 64 then
          if i <= noise_intensity then
            noise_drops[i] = Raindrop.new("noise")
          else
            noise_drops[i] = nil
          end
        end
      elseif i <= noise_intensity then
        noise_drops[i] = Raindrop.new("noise")
      end
    end
  end
  
  -- Update reverb rain
  if verb_mix > 0.01 then
    local reverb_intensity = math.floor(verb_mix * MAX_DROPS / 3)
    for i=1,MAX_DROPS do
      if reverb_drops[i] then
        local rotated_x = reverb_drops[i].x * math.cos(rotation) - reverb_drops[i].y * math.sin(rotation)
        table.insert(reverb_drops[i].trail, 1, {x = rotated_x, y = reverb_drops[i].y})
        if #reverb_drops[i].trail > TRAIL_LENGTH then
          table.remove(reverb_drops[i].trail)
        end
        
        reverb_drops[i].y = reverb_drops[i].y + reverb_drops[i].speed
        if reverb_drops[i].y > 64 then
          if i <= reverb_intensity then
            reverb_drops[i] = Raindrop.new("reverb")
          else
            reverb_drops[i] = nil
          end
        end
      elseif i <= reverb_intensity then
        reverb_drops[i] = Raindrop.new("reverb")
      end
    end
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
  
  -- Draw text and value bars on the left
  screen.level(8)
  -- REV
  screen.move(text_x, text_y_start)
  screen.text("REV")
  screen.level(15)
  screen.rect(text_x, text_y_start - 8, bar_width * (verb_mix / 3), bar_height)
  screen.fill()
  
  -- VOL
  screen.level(8)
  screen.move(text_x, text_y_start + text_spacing)
  screen.text("VOL")
  screen.level(15)
  screen.rect(text_x, text_y_start + text_spacing - 8, bar_width * (amp / 2), bar_height)
  screen.fill()
  
  -- NOI
  screen.level(8)
  screen.move(text_x, text_y_start + text_spacing * 2)
  screen.text("NOI")
  screen.level(15)
  screen.rect(text_x, text_y_start + text_spacing * 2 - 8, bar_width * noise, bar_height)
  screen.fill()
  
  -- Draw volume rain (straight lines)
  for _, drop in pairs(volume_drops) do
    for i, pos in ipairs(drop.trail) do
      local trail_brightness = math.floor(drop.brightness * (1 - i/TRAIL_LENGTH))
      screen.level(trail_brightness)
      screen.move(pos.x, pos.y)
      screen.line(pos.x, pos.y + drop.length)
      screen.stroke()
    end
  end
  
  -- Draw noise rain (jittery, shorter)
  for _, drop in pairs(noise_drops) do
    for i, pos in ipairs(drop.trail) do
      local trail_brightness = math.floor(drop.brightness * (1 - i/TRAIL_LENGTH))
      screen.level(trail_brightness)
      screen.move(pos.x, pos.y)
      screen.line(pos.x + math.sin(wave_phase * 10) * drop.jitter, pos.y + drop.length)
      screen.stroke()
    end
  end
  
  -- Draw reverb rain (wider, fading)
  for _, drop in pairs(reverb_drops) do
    for i, pos in ipairs(drop.trail) do
      local trail_brightness = math.floor(drop.brightness * (1 - i/TRAIL_LENGTH))
      screen.level(trail_brightness)
      -- Draw multiple lines for width
      for w = 0, drop.width do
        screen.move(pos.x + w - drop.width/2, pos.y)
        screen.line(pos.x + w - drop.width/2, pos.y + drop.length)
        screen.stroke()
      end
    end
  end
  
  screen.update()
end

function cleanup()
  if poll then
    poll:stop()
  end
  if screen_refresh_metro then
    screen_refresh_metro:stop()
    screen_refresh_metro = nil
  end
end 