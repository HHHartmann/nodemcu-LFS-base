--[[
usage:
`dofile("bootprotect.lua").start(signalpin, timeout, startupStep, ...)`

This calls the given startupStep functions one by one.
If one failes the next reboot will only execute the steps up to the one failing.
If the system crashes before timeout seconds the next boot will execute one step less.
So when messing up the application still basic stuff as FTP can be loaded and allow maintenance.
signalPin   Pin to show boot status (maybe an LED)
timeout     Wait for any resets for some time before calling it a successful boot (only wait at the end, not after each step)
...         Functions which are called one by one
            A Callback is passed to the functions to be called after async stuff is done
            To tell the framework whether the callback will be used the function uses the return value
              nil             callback will not be used. Proceed immediately with next step
              anything else   callback will be used to start next step
            This is usefull if a startupStep has to perform async stuff, like wait for WIFI connecting to an accesspoint.

Successful bootSteps will be persisted in rtcmem if available or in filesystem else.
]]

-- configuration
local RTCSlot = 17    -- will be used for tracking which steps have been executed between failed boots

--[[
 routines to retain boot progress in RTC mem or file
]]
local function StartingStep(n)
  if (rtcmem) then
    rtcmem.write32(RTCSlot, n)
  else
    local f = file:open('PANIC_GUARD','w')
    f:close()
  end
end
  
local function LastStepLastBoot()
  if (rtcmem) then
    return rtcmem.read32(RTCSlot)
  else
    if file.exists('PANIC_GUARD') then
      local f = file:open('PANIC_GUARD','r')
      local line = f:read()
      return tonumber(line)
    else
      return 0
    end
  end
end

local function RemoveGuard()
  if (rtcmem) then
    rtcmem.write32(RTCSlot, 0)
  else
    file.remove('PANIC_GUARD')
  end
end


if (rtcmem) then
  print("using RTC Mem")
end


local steps, stepsStarted = nil, 0
local stepsLastBoot = LastStepLastBoot()
local RunSteps, finishStartup, lTimeout

local function RunNextStep()
  -- check if not empty (the first enrtry ~= nil)
  if #steps > 0 then
    RunSteps(unpack(steps))
  else
    finishStartup()
  end
end

RunSteps = function(firstFunc, ...)
  steps = arg
  if (stepsStarted +1 == stepsLastBoot) then
    print("Aborting boot due to invalid boot last time.")
    steps = {}
    RunNextStep()
    return
  end
  stepsStarted = stepsStarted + 1

  StartingStep(stepsStarted)
  print("starting step", stepsStarted)
  if not firstFunc(RunNextStep) then
    RunNextStep()
  end
end

finishStartup = function()
  if stepsLastBoot > 0 then
      if signalPin then
        pwm.setup(signalPin, 2, 0)
        pwm.setduty(signalPin, 900)
		  pwm.start(signalPin)
      end
      print('aborting autostart since last run crashed too early')
      print('Wait for PANIC_GUARD removal and then')
      print('just restart to resume normal operation')
  end
  
  tmr.create():alarm(lTimeout*1000 or 10000, tmr.ALARM_SINGLE ,function()
      print('removing PANIC_GUARD')
      RemoveGuard()
      if signalPin then
        pwm.close(signalPin)
        gpio.write(signalPin, gpio.LOW);  -- turn light off permanently
      end
    end)
end


local protect = {}

function protect.start(signalPin, timeout, ...)

  local startupFunctions = arg
  local dummy,reason = node.bootreason()
  lTimeout = timeout
  
  print('bootreason: '..reason)
  print("last boot step", stepsLastBoot)
  if not gpio or not pwm then
    signalPin = nil
  end
  if signalPin then
      gpio.mode(signalPin, gpio.OUTPUT)
  end

  if signalPin then
    pwm.setup(signalPin, 1, 0)
    pwm.setduty(signalPin, 512)
    pwm.start(signalPin)
  end

  RunSteps(unpack(startupFunctions))

end

return protect
