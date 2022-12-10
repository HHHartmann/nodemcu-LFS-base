--[[
usage:
`dofile("bootprotect.lua").start(signalpin, timeout, startupStep, ...)`

This calls the given startupStep functions one by one.
If one step failes or the system crashes before "timeout" seconds the next boot will execute up to the step
before failure and the wait "timeout" before executing the next steps.
During this period the boot can be aborted by enter ing the command "stop()"
If not stopped the remaining steps will be executed after the timeout.
So when messing up the application, basic stuff as FTP can still be loaded and allow maintenance.
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
    f:write(n)
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
local lSignalPin

local function RunNextStep()
  print("RunNextStep: steps left:", #steps)
  if #steps > 0 then
    RunSteps(unpack(steps))
  else
    finishStartup()
  end
end

local waitfunc = function(nextStep)
  tmr.create():alarm(lTimeout*1000 or 10000, tmr.ALARM_SINGLE ,function()
      print('continuing boot')
      nextStep()
    end)
  stepsLastBoot = 0 -- to allow RunSteps to skip over the wait condition
  if lSignalPin then
    pwm.setup(lSignalPin, 2, 0)
    pwm.setduty(lSignalPin, 900)
    pwm.start(lSignalPin)
  end
  return true -- actually anything but nil to let the system know that we are executing async
end

RunSteps = function(firstFunc, ...)
  steps = {...}
  if (stepsStarted +1 == stepsLastBoot) then
    print("Delaying boot due to invalid boot last time. Enter stop() to stop running further steps ")
    steps = {firstFunc, ...}
    waitfunc(RunNextStep)
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
  stop = nil

  tmr.create():alarm(lTimeout*1000 or 10000, tmr.ALARM_SINGLE ,function()
      print('removing PANIC_GUARD')
      RemoveGuard()
      if lSignalPin then
        pwm.stop(lSignalPin)
        pwm.close(lSignalPin)
        gpio.write(lSignalPin, gpio.HIGH);  -- turn light off permanently
      end
    end)
end


local protect = {}

function protect.start(signalPin, timeout, ...)

  local startupFunctions = {...}
  lTimeout = timeout
  lSignalPin = signalPin
  
  print('bootreason: ', node.bootreason())
  print("last boot step", stepsLastBoot)
  if not gpio or not pwm then
    lSignalPin = nil
  end
  if lSignalPin then
    gpio.mode(lSignalPin, gpio.OUTPUT)
    pwm.setup(lSignalPin, 1, 0)
    pwm.setduty(lSignalPin, 512)
    pwm.start(lSignalPin)
  end

  function stop()
    print('aborting autostart since stop() was called')
    print('Wait for PANIC_GUARD removal and then')
    print('just restart to resume normal operation')
    steps = {}
  end

  RunSteps(unpack(startupFunctions))

end

return protect
