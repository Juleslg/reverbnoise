-- white blend
-- v1.0.0 @olivier
-- llllllll.co/t/white-blend
--
-- E1 - main volume
-- E2 - noise level
-- E3 - dry/wet mix
--
-- live audio processing 
-- with white noise blend

engine.name = 'WhiteBlend'

local level = 1.0
local noise = 0.0
local mix = 0.0

function init()
  -- Initialize engine parameters
  params:add_control("noise_freq", "Noise Freq", controlspec.new(20, 20000, 'exp', 0, 440, "Hz"))
  params:add_control("noise_gain", "Noise Gain", controlspec.new(0, 1, 'lin', 0, 0.5))
  
  -- Set up audio processing
  audio.level_adc(1.0)
  audio.level_eng_cut(1.0)
  audio.level_dac(1.0)
  
  -- Create audio processing softcut voice
  softcut.buffer_clear()
  softcut.enable(1, 1)
  softcut.buffer(1, 1)
  softcut.level(1, 1.0)
  softcut.position(1, 1)
  softcut.play(1, 1)
  softcut.rate(1, 1.0)
  softcut.loop_start(1, 1)
  softcut.loop_end(1, 1.1)
  softcut.loop(1, 1)
  softcut.rec(1, 1)
  softcut.rec_level(1, 1.0)
  softcut.pre_level(1, 0.0)
  
  -- Set up input monitoring
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(2, 1, 1.0)
  
  -- Start white noise processing
  noise_process()
  
  -- Start screen redraw clock
  redraw_clock_id = clock.run(function()
    while true do
      clock.sleep(1/15)
      redraw()
    end
  end)
end

function noise_process()
  -- Create a clock for continuous noise processing
  clock.run(function()
    while true do
      -- Use engine commands instead of direct math.random
      engine.hz(params:get("noise_freq"))
      engine.amp(params:get("noise_gain") * noise)
      
      clock.sleep(1/1000)
    end
  end)
end

function enc(n, d)
  if n == 1 then
    -- Main volume
    level = util.clamp(level + d/100, 0, 1)
    engine.amp(level)
  elseif n == 2 then
    -- Noise level
    noise = util.clamp(noise + d/100, 0, 1)
    engine.noise(noise)
  elseif n == 3 then
    -- Dry/wet mix
    mix = util.clamp(mix + d/100, 0, 1)
    engine.mix(mix)
  end
end

function redraw()
  screen.clear()
  
  -- Draw title
  screen.level(15)
  screen.move(64, 10)
  screen.text_center("white blend")
  
  -- Draw level indicators
  screen.level(5)
  screen.move(5, 30)
  screen.text("VOL")
  screen.move(5, 40)
  screen.text("NOISE")
  screen.move(5, 50)
  screen.text("MIX")
  
  -- Draw parameter values with increased range display
  screen.level(15)
  screen.move(123, 30)
  screen.text_right(string.format("%.0f%%", level * 150)) -- Show up to 150%
  screen.move(123, 40)
  screen.text_right(string.format("%.0f%%", noise * 200)) -- Show up to 200%
  screen.move(123, 50)
  screen.text_right(string.format("%.0f%%", mix * 200))   -- Show up to 200%
  
  -- Draw parameter bars with increased visual range
  for i = 1, 3 do
    local y = 20 + (i * 10)
    local val = i == 1 and level or i == 2 and noise or mix
    
    screen.level(3)
    screen.move(40, y)
    screen.line(110, y)
    screen.stroke()
    
    screen.level(15)
    screen.move(40, y)
    screen.line(40 + val * 70, y)
    screen.stroke()
  end
  
  -- Draw more dramatic visual feedback
  local radius = 8 + (noise * 20) -- Increased radius range
  screen.level(math.floor(5 + noise * 10))
  screen.circle(64, 35, radius)
  screen.stroke()
  
  screen.update()
end

function cleanup()
  clock.cancel(redraw_clock_id)
end
