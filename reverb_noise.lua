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

-- Rain state
local raindrops = {}
local MAX_DROPS = 40
local rain_trails = {}
local TRAIL_LENGTH = 6

-- Raindrop class
local Raindrop = {}
function Raindrop.new(x)
  return {
    x = x or math.random(1, 128),
    y = math.random(-10, 0),
    speed = math.random(3, 8) / 10,  -- Slower speed
    length = math.random(2, 4),
    trail = {},  -- Store previous positions
    brightness = math.random(10, 15)  -- Random brightness for variation
  }
end

-- Add new state variables at the top with other state variables
local rotation = 0
local planet_radius = 15
local ring_radiuses = {24, 32, 40}  -- Volume, Noise, Reverb
local perspective_angle = 0.6  -- Controls the "tilt" of the rings

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
    raindrops[i] = Raindrop.new()
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
  
  params:add_control("verb_mix", "Verb Mix", controlspec.new(0, 6.0, 'lin', 0, 0.0, ""))  -- Extended to 600%
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
  
  -- Update wave phase for planet vibration
  wave_phase = (wave_phase + 0.02) % (math.pi * 2)
  
  -- Update jitter based on input level
  local jitter_amount = last_input_level * 5
  
  -- Generate new jitter points for planet surface
  for i=1,128 do
    jitter_points[i] = (math.random() - 0.5) * jitter_amount
  end
  
  -- Update rain (when verb_mix > 2.0)
  if verb_mix > 2.0 then
    local rain_intensity = (verb_mix - 2.0) * MAX_DROPS / 4
    for i=1,MAX_DROPS do
      if raindrops[i] then
        -- Store trail with rotation
        local rotated_x = raindrops[i].x * math.cos(rotation) - raindrops[i].y * math.sin(rotation)
        table.insert(raindrops[i].trail, 1, {x = rotated_x, y = raindrops[i].y})
        if #raindrops[i].trail > TRAIL_LENGTH then
          table.remove(raindrops[i].trail)
        end
        
        raindrops[i].y = raindrops[i].y + raindrops[i].speed
        if raindrops[i].y > 64 then
          if i <= rain_intensity then
            raindrops[i] = Raindrop.new()
          else
            raindrops[i] = nil
          end
        end
      elseif i <= rain_intensity then
        raindrops[i] = Raindrop.new()
      end
    end
  else
    raindrops = {}
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
  
  -- Draw the planet
  local planet_points = 32
  local vibration_scale = 3 + (last_input_level * 5)
  for i = 1, planet_points do
    local angle = (i / planet_points) * math.pi * 2
    local next_angle = ((i + 1) / planet_points) * math.pi * 2
    
    -- Add vibration to radius
    local radius_mod = math.sin(wave_phase + angle * 3) * vibration_scale
    local next_radius_mod = math.sin(wave_phase + next_angle * 3) * vibration_scale
    
    local x1 = math.cos(angle) * (planet_radius + radius_mod)
    local y1 = math.sin(angle) * (planet_radius + radius_mod) * perspective_angle
    local x2 = math.cos(next_angle) * (planet_radius + next_radius_mod)
    local y2 = math.sin(next_angle) * (planet_radius + next_radius_mod) * perspective_angle
    
    -- Rotate points
    local rx1 = x1 * math.cos(rotation) - y1 * math.sin(rotation)
    local ry1 = x1 * math.sin(rotation) + y1 * math.cos(rotation)
    local rx2 = x2 * math.cos(rotation) - y2 * math.sin(rotation)
    local ry2 = x2 * math.sin(rotation) + y2 * math.cos(rotation)
    
    screen.level(15)
    screen.move(rx1 + 64, ry1 + 32)
    screen.line(rx2 + 64, ry2 + 32)
    screen.stroke()
  end
  
  -- Draw the rings with varying brightness based on their values
  -- Volume ring
  local volume_points = calculate_ellipse_points(ring_radiuses[1], rotation, 64)
  screen.level(math.floor(amp * 15))
  for i = 1, #volume_points - 1 do
    screen.move(volume_points[i].x, volume_points[i].y)
    screen.line(volume_points[i + 1].x, volume_points[i + 1].y)
  end
  screen.stroke()
  
  -- Noise ring
  local noise_points = calculate_ellipse_points(ring_radiuses[2], rotation, 64)
  screen.level(math.floor(noise * 15))
  for i = 1, #noise_points - 1 do
    screen.move(noise_points[i].x, noise_points[i].y)
    screen.line(noise_points[i + 1].x, noise_points[i + 1].y)
  end
  screen.stroke()
  
  -- Reverb ring (with potential crystalline effect)
  local reverb_points = calculate_ellipse_points(ring_radiuses[3], rotation, 64)
  local reverb_brightness = math.floor(verb_mix * 15 / 6)  -- Scale for 600% range
  if verb_mix > 2.0 then
    screen.level(reverb_brightness + math.floor(math.sin(wave_phase * 8) * 3))
  else
    screen.level(reverb_brightness)
  end
  for i = 1, #reverb_points - 1 do
    screen.move(reverb_points[i].x, reverb_points[i].y)
    screen.line(reverb_points[i + 1].x, reverb_points[i + 1].y)
  end
  screen.stroke()
  
  -- Draw rain when verb_mix > 2.0
  if verb_mix > 2.0 then
    for _, drop in pairs(raindrops) do
      if drop then
        for i, pos in ipairs(drop.trail) do
          local trail_brightness = math.floor(drop.brightness * (1 - i/TRAIL_LENGTH))
          screen.level(trail_brightness)
          screen.move(pos.x, pos.y)
          screen.line(pos.x, pos.y + drop.length)
          screen.stroke()
        end
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