print('start.lua')

dofile("Log.lua")

config = dofile("GetConfig.lua")

-- attention LUA 51 only
--node.egc.setmode(node.egc.ON_MEM_LIMIT, -4096)
--node.egc.setmode(node.egc.ON_ALLOC_FAILURE)

wifi.setphymode(wifi.PHYMODE_N)

local signalPin = config.signalPin

local function startup()

  local errorFileName = "www_errors.txt"
  node.setonerror(function(s)
     collectgarbage()
     local f = file.open(errorFileName, "a")
     f:writeline("==========================: ")
     f:writeline(s)
     f:writeline("")
     f:close()
     print(s)
     node.restart()
  end)


	gpio.mode(1,gpio.OUTPUT)
	gpio.write(1,gpio.LOW)
	gpio.mode(2,gpio.OUTPUT)
	gpio.write(2,gpio.LOW)
	gpio.mode(3,gpio.OUTPUT)
	gpio.write(3,gpio.LOW)
	gpio.mode(4,gpio.OUTPUT)
	gpio.write(4,gpio.LOW)

  local f = file.open(errorFileName, "a")
  f:writeline("------------- "..sjson.encode({node.bootreason()}))
  f:close()
  
  if file.stat(errorFileName).size > 10000 then
    if config.smallFs then
      file.remove(errorFileName .. ".1")
    else
      file.remove(errorFileName .. ".2")
      file.rename(errorFileName .. ".1", errorFileName .. ".2")
    end
    file.rename(errorFileName        , errorFileName .. ".1")
  end

  if config.smallFs then
    file.remove("luac.out.fail")
    file.remove("luac.out.old")
  end

	-- pcall(function() require("LED-strip") end) -- TODO integrate as optional early startup
end

local function logger()
  Logger = require("Logger")
  if config.runLogger then
    Log.LogTrace("activating Logger")
    Logger.start()
  else
    Log.LogTrace("deactivating Logger")
    Logger.stop()
  end
end

local function netUtilities()
	
	Log.LogDebug('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())

  if config.runFTPServer then
    Log.LogTrace('Starting ftp server')

    require("ftpserver").createServer("test","12345","dbg")
  end

  if config.runTelnetServer then
    Log.LogTrace('Starting telnet server')
    require("telnet"):open()
    Log.LogDebug('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
  end
end

local function gossipStartup()
  if config.runGossip then
    Log.LogTrace('Starting gossip')
    local gossipConfig = {
        seedList = {},
        roundInterval = 30000,
        comPort = 5000,
        debug = true,
        debugOutput = function(message) Log.LogDebug('Gossip says: ', message); end
    }

    gossip = dofile("gossip.lua")
    gossip.setConfig(gossipConfig)
    gossipConfig = nil
    gossip.start()
    gossip.pushGossip(nil, '255.255.255.255')  -- broadcast to announce new instance
  end

  Log.LogTrace('Starting discovery gossip')
  local gossipConfig = {
      seedList = {},
      roundInterval = 60000,
      comPort = 5001,
      debug = true,
      debugOutput = function(message) Log.LogDebug('Gossip says: ', message); end
  }

  discoveryGossip = dofile("gossip.lua")
  discoveryGossip.setConfig(gossipConfig)
  gossipConfig = nil
  discoveryGossip.start()
  discoveryGossip.pushGossip(node.chipid(), '255.255.255.255')  -- broadcast to announce new instance


end

local function httpServer()
	Log.LogTrace('Starting http server')
	--dofile("IDESupport.lua")
	dofile("StartWebServer.lua")
	Log.LogDebug('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function fileDistribution()
	Log.LogTrace('Starting File Distribution')
	dofile("FileDist.lua")
	Log.LogDebug('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function applicationStartup()
	Log.LogTrace('Starting ApplicationStart.lua')
  dofile("ApplicationStart.lua")
	Log.LogDebug('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())

  if not config.debug then
    Log.SetLogLevel(Log.Silent)
  end
end

local function startNetwork(cb)
	dofile("WifiStarter.lua").start(cb)
  return true  -- actually return anything
end


Log.LogTrace('calling bootprotect')
dofile("bootprotect.lua").start(signalPin, 10,   logger, startup, startNetwork, netUtilities, gossipStartup, httpServer, fileDistribution, applicationStartup)
